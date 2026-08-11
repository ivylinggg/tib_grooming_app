import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../api/google_drive_api.dart';
import '../models/register_result.dart';

/// Whether -- and via what token -- one assessment currently has public
/// sharing turned on. Mirrors the same typed-result-object pattern
/// already used for [RegisterResult]/[UpdateStaffResult] rather than a
/// bare nullable String, since "no token" and "token exists but sharing
/// is off" are both real, distinct states a caller needs to branch on.
class SharingStatus {
  final String? token;
  final bool enabled;

  const SharingStatus({this.token, this.enabled = false});

  /// True only when there's an active token a public URL can actually
  /// resolve right now.
  bool get isActive => enabled && token != null && token!.isNotEmpty;
}

class FirebaseService {
  FirebaseService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload Reference Photo
  Future<DriveUploadResult> uploadPhoto({
    required String staff,
    required File image,
  }) async {
    return await GoogleDriveApi.uploadImage(
      image: image,
      fileName: "${staff}_reference.jpg",
    );
  }

  /// Register Participant.
  ///
  /// Three independent stages -- Firestore read, Google Drive upload,
  /// Firestore write -- each report their own failure instead of
  /// collapsing into a single boolean. See lib/models/register_result.dart.
  Future<RegisterResult> registerParticipant({
    required String staff,
    required String name,
    required String trainer,
    required String date,
    required File referencePhoto,
  }) async {
    final participantRef = _firestore.collection("participants").doc(staff);

    // Stage 1: Firestore Read
    final DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await participantRef.get();
    } catch (e, stackTrace) {
      debugPrint("registerParticipant: firestoreReadFailed - $e");
      return RegisterResult.firestoreReadFailed(e, stackTrace);
    }

    if (doc.exists) {
      return RegisterResult.duplicate();
    }

    // Stage 2: Google Drive Upload
    debugPrint("========== GOOGLE DRIVE ==========");

    final uploadResult = await uploadPhoto(staff: staff, image: referencePhoto);

    if (!uploadResult.success) {
      debugPrint(
        "registerParticipant: uploadFailed - ${uploadResult.rawError}",
      );
      return RegisterResult.uploadFailed(
        DriveUploadException(uploadResult.errorMessage!),
      );
    }

    final photoUrl = uploadResult.imageUrl!;

    debugPrint(photoUrl);

    // Which signed-in Staff account is performing this registration, if
    // any -- additive metadata only (Admin's Staff Activity view; see
    // Participant.createdByUid's doc comment). Looked up in its own
    // try/catch so a lookup failure here can never block the actual
    // registration -- worst case the record is written with these three
    // fields left null, same as any historical record from before this
    // existed.
    String? createdByUid;
    String? createdByStaffId;
    String? createdByName;

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      try {
        createdByUid = currentUser.uid;

        final staffDoc = await _firestore
            .collection("users")
            .doc(currentUser.uid)
            .get();

        final staffData = staffDoc.data();

        if (staffData != null) {
          createdByStaffId = staffData["staffId"]?.toString();

          final firstName = staffData["firstName"]?.toString() ?? "";
          final lastName = staffData["lastName"]?.toString() ?? "";
          final fullName = "$firstName $lastName".trim();

          createdByName = fullName.isEmpty ? null : fullName;
        }
      } catch (e) {
        debugPrint(
          "registerParticipant: could not look up creator Staff info - $e",
        );
      }
    }

    // Stage 3: Firestore Write
    try {
      await participantRef.set({
        "staff": staff,
        "name": name,
        "trainer": trainer,
        "registrationDate": date,
        "photoUrl": photoUrl,
        "createdAt": FieldValue.serverTimestamp(),
        "createdByUid": createdByUid,
        "createdByStaffId": createdByStaffId,
        "createdByName": createdByName,
      });
    } catch (e, stackTrace) {
      debugPrint("registerParticipant: firestoreWriteFailed - $e");
      return RegisterResult.firestoreWriteFailed(e, stackTrace);
    }

    debugPrint("Participant Registered");

    return RegisterResult.success();
  }

  /// Get participant
  Future<Map<String, dynamic>?> getParticipant(String staff) async {
    try {
      final doc = await _firestore.collection("participants").doc(staff).get();

      if (!doc.exists) return null;

      final data = doc.data();

      if (data == null) return null;

      return {...data, "id": doc.id};
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  /// Get all participants
  Future<List<Map<String, dynamic>>> getAllParticipants() async {
    try {
      final snapshot = await _firestore
          .collection("participants")
          .orderBy("createdAt", descending: true)
          .get();

      return snapshot.docs.map((doc) => {...doc.data(), "id": doc.id}).toList();
    } catch (e) {
      debugPrint(e.toString());
      return [];
    }
  }

  /// Stream participants
  Stream<QuerySnapshot<Map<String, dynamic>>> streamParticipants() {
    return _firestore
        .collection("participants")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  /// Admin's Staff Activity (StaffProfileScreen): every Participant
  /// record whose `createdByUid` matches this Staff account's uid.
  /// Historical records from before this field existed simply don't
  /// match (they never had the field written at all), which is exactly
  /// the "don't pretend old records belong to the current Staff"
  /// behavior wanted -- there's no separate "is this historical" check
  /// needed because a null field can never equal a non-null uid.
  Future<List<Map<String, dynamic>>> getParticipantsCreatedByStaff(
    String uid,
  ) async {
    try {
      final snapshot = await _firestore
          .collection("participants")
          .where("createdByUid", isEqualTo: uid)
          .orderBy("createdAt", descending: true)
          .get();

      return snapshot.docs.map((doc) => {...doc.data(), "id": doc.id}).toList();
    } catch (e) {
      debugPrint("getParticipantsCreatedByStaff: $e");
      return [];
    }
  }

  /// Most recently registered participants, for Admin Dashboard's
  /// recent-activity panel. Reuses the same createdAt ordering
  /// [streamParticipants] already relies on, just capped to [limit].
  Future<List<Map<String, dynamic>>> getRecentParticipants({
    int limit = 5,
  }) async {
    try {
      final snapshot = await _firestore
          .collection("participants")
          .orderBy("createdAt", descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {...doc.data(), "id": doc.id}).toList();
    } catch (e) {
      debugPrint("getRecentParticipants: $e");
      return [];
    }
  }

  /// Update participant
  Future<bool> updateParticipant({
    required String staff,
    required String name,
    required String trainer,
    required String registrationDate,
    String? photoUrl,
  }) async {
    try {
      final data = {
        "name": name,
        "trainer": trainer,
        "registrationDate": registrationDate,
      };

      if (photoUrl != null) {
        data["photoUrl"] = photoUrl;
      }

      await _firestore.collection("participants").doc(staff).update(data);

      return true;
    } catch (e) {
      debugPrint(e.toString());
      return false;
    }
  }

  /// Delete participant
  Future<bool> deleteParticipant(String staff) async {
    try {
      await _firestore.collection("participants").doc(staff).delete();

      // TODO:
      // Delete Google Drive image in future.

      return true;
    } catch (e) {
      debugPrint("Delete Error");
      debugPrint(e.toString());
      return false;
    }
  }

  /// Save Assessment
  ///
  /// [createdByUid], if provided, is the Firebase Auth uid of the
  /// signed-in Staff account that performed this assessment -- the
  /// minimum link needed for StaffDashboardScreen to later find "my
  /// assessments" without assuming Staff UID == Participant ID. Left
  /// null for the anonymous, no-auth Cabin Crew Check-In path, same as
  /// [registerParticipant]'s createdByUid handles the equivalent case
  /// for Participant records.
  Future<bool> saveAssessment({
    required String participantId,
    required String participantName,

    required int totalScore,
    required String overall,

    required String summary,
    required String suggestion,

    required String referencePhotoUrl,
    required String todayPhotoUrl,

    required List<Map<String, dynamic>> criteria,
    String? createdByUid,
  }) async {
    try {
      await _firestore.collection("assessments").add({
        "participantId": participantId,
        "participantName": participantName,

        "totalScore": totalScore,
        "overall": overall,

        "summary": summary,
        "suggestion": suggestion,

        "referencePhotoUrl": referencePhotoUrl,
        "todayPhotoUrl": todayPhotoUrl,

        "criteria": criteria,

        "createdAt": Timestamp.now(),
        "createdByUid": createdByUid,
      });

      final participantRef = _firestore
          .collection("participants")
          .doc(participantId);

      final participantDoc = await participantRef.get();

      if (participantDoc.exists) {
        final data = participantDoc.data()!;

        final currentCount = (data["assessmentCount"] ?? 0) as int;

        await participantRef.update({
          "latestScore": totalScore,
          "latestResult": overall,
          "assessmentCount": currentCount + 1,
          "lastAssessmentDate": Timestamp.now(),
        });
      }

      return true;
    } catch (e) {
      debugPrint(e.toString());
      return false;
    }
  }

  /// Assessment History.
  ///
  /// Deliberately a single-field `where` with no `orderBy` -- combining
  /// them would require a Firestore composite index (participantId +
  /// createdAt) that this project doesn't have configured, which
  /// surfaces to the user as a raw `failed-precondition` error. A
  /// single-field equality query never needs a manual index, so callers
  /// must sort the returned docs by `createdAt` client-side themselves
  /// (both current callers -- StaffDashboardScreen and
  /// AssessmentHistoryScreen -- do this).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamParticipantAssessments(
    String participantId,
  ) {
    return _firestore
        .collection("assessments")
        .where("participantId", isEqualTo: participantId)
        .snapshots();
  }

  /// Admin Assessment Management: every assessment record across every
  /// participant, not scoped to one -- distinct from
  /// [streamParticipantAssessments], which is what Participant Profile
  /// uses.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllAssessments() {
    return _firestore
        .collection("assessments")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  /// One assessment record by its Firestore document ID, for Assessment
  /// Detail. Returns null if it was deleted between the list loading
  /// and this being opened (e.g. another Admin session deleted it).
  Future<Map<String, dynamic>?> getAssessmentById(String documentId) async {
    try {
      final doc = await _firestore
          .collection("assessments")
          .doc(documentId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      return {...data, "id": doc.id};
    } catch (e) {
      debugPrint("getAssessmentById: $e");
      return null;
    }
  }

  /// Most recent assessment records, for Admin Dashboard's
  /// recent-activity panel.
  Future<List<Map<String, dynamic>>> getRecentAssessments({
    int limit = 5,
  }) async {
    try {
      final snapshot = await _firestore
          .collection("assessments")
          .orderBy("createdAt", descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {...doc.data(), "id": doc.id}).toList();
    } catch (e) {
      debugPrint("getRecentAssessments: $e");
      return [];
    }
  }

  /// Delete Assessment
  Future<void> deleteAssessment(String documentId) async {
    await _firestore.collection("assessments").doc(documentId).delete();
  }

  /// Current public-sharing state for one assessment -- read from
  /// `assessments/{assessmentId}.shareToken`/`.sharingEnabled`, the
  /// only place that state lives on the private side. Returns an
  /// inactive [SharingStatus] (never throws) if the assessment has
  /// never been shared or no longer exists.
  Future<SharingStatus> getSharingStatus(String assessmentId) async {
    try {
      final doc = await _firestore
          .collection("assessments")
          .doc(assessmentId)
          .get();

      return SharingStatus(
        token: doc.data()?["shareToken"]?.toString(),
        enabled: doc.data()?["sharingEnabled"] == true,
      );
    } catch (e) {
      debugPrint("getSharingStatus: $e");
      return const SharingStatus();
    }
  }

  /// Turns on public sharing for one assessment and returns the token
  /// its public URL uses (`$kPublicResultBaseUrl/<token>`).
  ///
  /// Two separate writes, deliberately never combined into one:
  /// 1. `assessments/{assessmentId}` -- the private source of truth --
  ///    gets `shareToken`/`sharingEnabled` fields added. This document
  ///    is never made publicly readable; nothing here changes who can
  ///    read it.
  /// 2. `shared_results/{token}` -- a brand-new, separate document
  ///    containing ONLY the fields that are safe to show a stranger
  ///    with no login: participant name/Staff ID/trainer name/date,
  ///    score, result, criteria, AI summary/recommendation, photo
  ///    URLs, and `sharingEnabled`. No Firebase uid, no auth token, no
  ///    internal Firestore path, no field from any other collection.
  ///    This is the only document the public result page
  ///    (public_hosting/result.html) ever reads, gated by a Firestore
  ///    rule that requires `sharingEnabled == true` -- the `assessments`
  ///    collection itself is never touched by that rule at all.
  ///
  /// Re-sharing an already-shared, still-enabled assessment reuses the
  /// same token (idempotent) instead of minting a new one every tap, so
  /// a link someone already has keeps working. A token from a
  /// previously *disabled* share is never reactivated silently -- a
  /// fresh one is generated instead, so an old, once-revoked link can
  /// never start working again just by sharing again.
  Future<String> enableSharing({
    required String assessmentId,
    required Map<String, dynamic> assessmentData,
    String? trainerName,
  }) async {
    final assessmentRef = _firestore
        .collection("assessments")
        .doc(assessmentId);

    final existing = await assessmentRef.get();
    final existingToken = existing.data()?["shareToken"]?.toString();
    final existingEnabled = existing.data()?["sharingEnabled"] == true;

    final token =
        (existingToken != null && existingToken.isNotEmpty && existingEnabled)
        ? existingToken
        : _generateShareToken();

    await assessmentRef.update({"shareToken": token, "sharingEnabled": true});

    await _firestore.collection("shared_results").doc(token).set({
      "assessmentId": assessmentId,
      "participantId": assessmentData["participantId"],
      "participantName": assessmentData["participantName"],
      "trainerName": (trainerName == null || trainerName.isEmpty)
          ? null
          : trainerName,
      "totalScore": assessmentData["totalScore"],
      "overall": assessmentData["overall"],
      "summary": assessmentData["summary"],
      "suggestion": assessmentData["suggestion"],
      "criteria": assessmentData["criteria"],
      "referencePhotoUrl": assessmentData["referencePhotoUrl"],
      "todayPhotoUrl": assessmentData["todayPhotoUrl"],
      "assessmentDate": assessmentData["createdAt"],
      "sharingEnabled": true,
      "sharedAt": FieldValue.serverTimestamp(),
    });

    return token;
  }

  /// Turns public sharing off. Both the private flag (so re-sharing
  /// generates a fresh token instead of reactivating this one -- see
  /// [enableSharing]) and the public copy's own flag (so the public
  /// page stops resolving this token immediately, without waiting for
  /// anything else) are flipped together.
  Future<void> disableSharing(String assessmentId) async {
    final assessmentRef = _firestore
        .collection("assessments")
        .doc(assessmentId);

    final doc = await assessmentRef.get();
    final token = doc.data()?["shareToken"]?.toString();

    await assessmentRef.update({"sharingEnabled": false});

    if (token != null && token.isNotEmpty) {
      await _firestore.collection("shared_results").doc(token).update({
        "sharingEnabled": false,
      });
    }
  }

  /// A cryptographically random, 64-hex-character (256-bit) token --
  /// generated with `Random.secure()`, a real CSPRNG, never
  /// `Random()`. Deliberately not derived from the Staff ID or any
  /// other predictable value: a share link must not be guessable just
  /// by knowing (or enumerating) real Staff IDs.
  String _generateShareToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
