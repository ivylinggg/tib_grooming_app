import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../api/google_drive_api.dart';
import '../models/assessment_result.dart';
import 'auth_service.dart';
import 'firebase_service.dart';

/// Domain service for assessment business logic.
///
/// AssessmentScreen (trainer-reviewed flow) and CheckInCard (self-service
/// check-in flow) both go through this instead of calling
/// FirebaseService.saveAssessment() directly. FirebaseService stays
/// responsible only for Firestore operations; this layer owns the rules
/// around an AssessmentResult -- uploading today's photo, preparing a
/// result for use, and saving it are each a separate, focused method;
/// [prepareAssessment] orchestrates the first two for the common case.
/// Presentation stays separate -- this layer never builds UI.
class AssessmentService {
  AssessmentService({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService();

  final FirebaseService _firebaseService;

  /// Set by [prepareAssessment] whenever it returns null because the
  /// upload failed, so callers can show the real reason (same
  /// DriveUploadResult.errorMessage that registration already surfaces)
  /// instead of a single generic string for every failure. Null after a
  /// successful call.
  String? lastUploadError;

  /// Uploads today's assessment photo to Google Drive.
  ///
  /// Reuses the same GoogleDriveApi.uploadImage() pipeline and Apps
  /// Script upload endpoint that reference-photo registration already
  /// uses -- same filename convention FirebaseService.uploadAssessmentPhoto
  /// already established. Returns the full [DriveUploadResult] (not just
  /// a URL) so [prepareAssessment] can tell the caller *why* an upload
  /// failed instead of just that it did -- same reasoning as
  /// FirebaseService.uploadPhoto.
  Future<DriveUploadResult> uploadAssessmentPhoto({
    required String participantId,
    required File image,
  }) {
    return GoogleDriveApi.uploadImage(
      image: image,
      fileName: "${participantId}_${DateTime.now().millisecondsSinceEpoch}.jpg",
    );
  }

  /// Pure transformation: attaches participant/photo context onto a raw
  /// [AssessmentResult]. No network calls -- both URLs must already be
  /// known by the caller.
  ///
  /// AssessmentApi.analyze()'s response never includes any of this --
  /// Apps Script only returns Claude's gender/overall/summary/criteria
  /// judgement -- so every caller needs to fill it in before the result
  /// is saved or displayed. Centralized here instead of each screen
  /// building its own copyWith call.
  AssessmentResult prepareResult({
    required AssessmentResult result,
    required String referencePhotoUrl,
    required String todayPhotoUrl,
    String? staffId,
    String? participantName,
    String? trainerName,
    String? assessmentDate,
  }) {
    return result.copyWith(
      referencePhotoUrl: referencePhotoUrl,
      todayPhotoUrl: todayPhotoUrl,
      staffId: staffId,
      participantName: participantName,
      trainerName: trainerName,
      assessmentDate: assessmentDate,
    );
  }

  /// Orchestrates the full pipeline: upload today's photo, then prepare
  /// the result. Returns null if the upload fails, so callers can notify
  /// the user instead of silently persisting an empty todayPhotoUrl --
  /// see [lastUploadError] for the specific reason to show them.
  Future<AssessmentResult?> prepareAssessment({
    required AssessmentResult result,
    required String referencePhotoUrl,
    required File todayPhoto,
    required String participantId,
    String? staffId,
    String? participantName,
    String? trainerName,
    String? assessmentDate,
  }) async {
    lastUploadError = null;

    final uploadResult = await uploadAssessmentPhoto(
      participantId: participantId,
      image: todayPhoto,
    );

    if (!uploadResult.success) {
      debugPrint(
        "prepareAssessment: today's photo upload failed - "
        "${uploadResult.rawError}",
      );
      lastUploadError = uploadResult.errorMessage;
      return null;
    }

    return prepareResult(
      result: result,
      referencePhotoUrl: referencePhotoUrl,
      todayPhotoUrl: uploadResult.imageUrl!,
      staffId: staffId,
      participantName: participantName,
      trainerName: trainerName,
      assessmentDate: assessmentDate,
    );
  }

  /// Saves the assessment, then -- if a Staff account is signed in --
  /// keeps that account's `users/{uid}.staffId` in sync with the real
  /// Staff ID ([participantId]) it just used. This is the single choke
  /// point every save path in the app goes through (CheckInCard's
  /// self-service flow and AssessmentScreen, reached either directly or
  /// via AIAssessmentScreen), so it's the one place this link needs to
  /// be written.
  ///
  /// The linking step is deliberately non-fatal: it runs only after the
  /// assessment itself is confirmed saved, and any failure there is
  /// swallowed rather than turning an already-successful save into a
  /// reported failure.
  Future<bool> saveAssessment({
    required String participantId,
    required String participantName,
    required AssessmentResult result,
  }) async {
    final createdByUid = FirebaseAuth.instance.currentUser?.uid;

    final saved = await _firebaseService.saveAssessment(
      participantId: participantId,
      participantName: participantName,

      totalScore: result.totalScore,
      overall: result.overall,

      summary: result.summary,
      suggestion: result.suggestion,

      referencePhotoUrl: result.referencePhotoUrl ?? "",
      todayPhotoUrl: result.todayPhotoUrl ?? "",

      criteria: result.criteria
          .map((e) => {"label": e.label, "score": e.score, "tip": e.tip})
          .toList(),
      createdByUid: createdByUid,
    );

    if (saved && createdByUid != null) {
      try {
        await AuthService().linkCurrentStaffToParticipant(participantId);
      } catch (e) {
        debugPrint("saveAssessment: linkCurrentStaffToParticipant failed - $e");
      }
    }

    return saved;
  }
}
