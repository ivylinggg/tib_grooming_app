import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../api/google_drive_api.dart';

class FirebaseService {
  FirebaseService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload Reference Photo
  Future<String?> uploadPhoto({
    required String staff,
    required File image,
  }) async {
    return await GoogleDriveApi.uploadImage(
      image: image,
      fileName: "${staff}_reference.jpg",
    );
  }

  /// Register Participant
  Future<bool> registerParticipant({
    required String staff,
    required String name,
    required String trainer,
    required String date,
    required File referencePhoto,
  }) async {
    try {
      final participantRef = _firestore.collection("participants").doc(staff);

      final doc = await participantRef.get();

      if (doc.exists) {
        return false;
      }

      debugPrint("========== GOOGLE DRIVE ==========");

      final photoUrl = await uploadPhoto(staff: staff, image: referencePhoto);

      debugPrint(photoUrl);

      await participantRef.set({
        "staff": staff,
        "name": name,
        "trainer": trainer,
        "registrationDate": date,
        "photoUrl": photoUrl ?? "",
        "createdAt": FieldValue.serverTimestamp(),
      });

      debugPrint("Participant Registered");

      return true;
    } catch (e) {
      debugPrint("Register Error");
      debugPrint(e.toString());
      return false;
    }
  }

  /// Check participant exists
  Future<bool> participantExists(String staff) async {
    try {
      final doc = await _firestore.collection("participants").doc(staff).get();

      return doc.exists;
    } catch (e) {
      debugPrint(e.toString());
      return false;
    }
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

  /// Search participant
  Future<List<Map<String, dynamic>>> searchParticipant(String keyword) async {
    try {
      final snapshot = await _firestore.collection("participants").get();

      final key = keyword.toLowerCase();

      return snapshot.docs
          .where((doc) {
            final data = doc.data();

            final staff = (data["staff"] ?? "").toString().toLowerCase();

            final name = (data["name"] ?? "").toString().toLowerCase();

            return staff.contains(key) || name.contains(key);
          })
          .map((doc) => {...doc.data(), "id": doc.id})
          .toList();
    } catch (e) {
      debugPrint(e.toString());
      return [];
    }
  }

  /// Upload Assessment Photo
  Future<String?> uploadAssessmentPhoto({
    required String participantId,
    required File image,
  }) async {
    return await GoogleDriveApi.uploadImage(
      image: image,
      fileName: "${participantId}_${DateTime.now().millisecondsSinceEpoch}.jpg",
    );
  }

  /// Save Assessment
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

  /// Assessment History
  Stream<QuerySnapshot<Map<String, dynamic>>> streamParticipantAssessments(
    String participantId,
  ) {
    return _firestore
        .collection("assessments")
        .where("participantId", isEqualTo: participantId)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  /// Delete Assessment
  Future<void> deleteAssessment(String documentId) async {
    await _firestore.collection("assessments").doc(documentId).delete();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getParticipantAssessments(String participantId) async {
    final snapshot = await _firestore
        .collection("assessments")
        .where("participantId", isEqualTo: participantId)
        .orderBy("createdAt", descending: true)
        .get();

    return snapshot.docs;
  }

  Map<String, dynamic> calculateStatistics(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return {
        "average": 0,
        "highest": 0,
        "lowest": 0,
        "passRate": 0,
        "total": 0,
      };
    }

    int totalScore = 0;
    int highest = 0;
    int lowest = 100;
    int pass = 0;

    for (final doc in docs) {
      final data = doc.data();

      final score = (data["score"] ?? 0) as int;

      totalScore += score;

      if (score > highest) highest = score;

      if (score < lowest) lowest = score;

      if ((data["result"] ?? "") == "PASS") {
        pass++;
      }
    }

    return {
      "average": (totalScore / docs.length).toStringAsFixed(1),
      "highest": highest,
      "lowest": lowest,
      "passRate": ((pass / docs.length) * 100).toStringAsFixed(1),
      "total": docs.length,
    };
  }
}
