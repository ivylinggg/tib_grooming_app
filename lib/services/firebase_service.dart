import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  FirebaseService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload image to Firebase Storage
  Future<String?> uploadPhoto({
    required String staff,
    required File image,
  }) async {
    try {
      final ref = _storage.ref().child("participants/$staff/reference.jpg");

      final uploadTask = await ref.putFile(image);

      if (uploadTask.state == TaskState.success) {
        final url = await ref.getDownloadURL();

        debugPrint("========== STORAGE ==========");
        debugPrint("Upload Success");
        debugPrint(url);
        debugPrint("=============================");

        return url;
      }

      return null;
    } catch (e) {
      debugPrint("Firebase Storage Error:");
      debugPrint(e.toString());

      return null;
    }
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

      debugPrint("========== FIREBASE ==========");
      debugPrint("Uploading Photo...");

      final photoUrl = await uploadPhoto(staff: staff, image: referencePhoto);

      debugPrint("Photo URL:");
      debugPrint(photoUrl);

      await participantRef.set({
        "staff": staff,
        "name": name,
        "trainer": trainer,
        "registrationDate": date,
        "photoUrl": photoUrl ?? "",
        "createdAt": FieldValue.serverTimestamp(),
      });

      debugPrint("Firestore Saved");

      return true;
    } catch (e) {
      debugPrint("Register Error:");
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
      debugPrint("Participant Exists Error:");
      debugPrint(e.toString());

      return false;
    }
  }

  /// Get one participant
  Future<Map<String, dynamic>?> getParticipant(String staff) async {
    try {
      final doc = await _firestore.collection("participants").doc(staff).get();

      if (!doc.exists) return null;

      final data = doc.data();

      if (data == null) return null;

      return {...data, "id": doc.id};
    } catch (e) {
      debugPrint("Get Participant Error:");
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
      debugPrint("Get Participants Error:");
      debugPrint(e.toString());

      return [];
    }
  }

  /// Realtime participants
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

      // Delete Storage image
      try {
        await _storage.ref("participants/$staff/reference.jpg").delete();
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint("Delete Error:");
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
          .map((doc) {
            return {...doc.data(), "id": doc.id};
          })
          .toList();
    } catch (e) {
      debugPrint("Search Error:");
      debugPrint(e.toString());

      return [];
    }
  }

  /// Upload Assessment Photo
  Future<String?> uploadAssessmentPhoto({
    required String participantId,
    required File image,
  }) async {
    try {
      final ref = _storage.ref().child(
        "assessments/$participantId/${DateTime.now().millisecondsSinceEpoch}.jpg",
      );

      await ref.putFile(image);

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Assessment Upload Error:");
      debugPrint(e.toString());

      return null;
    }
  }

  /// Save Assessment
  Future<void> saveAssessment({
    required String participantId,
    required String participantName,
    required int score,
    required String result,
    required bool hair,
    required bool uniform,
    required bool tie,
    required bool shoes,
    required bool nameTag,
  }) async {
    await _firestore.collection("assessments").add({
      "participantId": participantId,
      "participantName": participantName,
      "score": score,
      "result": result,
      "hair": hair,
      "uniform": uniform,
      "tie": tie,
      "shoes": shoes,
      "nameTag": nameTag,
      "createdAt": Timestamp.now(),
    });
  }
}
