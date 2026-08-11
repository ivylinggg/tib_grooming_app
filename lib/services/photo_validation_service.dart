import 'dart:io';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Shared ML Kit face-detection gate for any already-picked photo file
/// (camera or gallery), used to reject images with no detectable face
/// before they're uploaded/persisted anywhere.
///
/// This is deliberately separate from the live in-camera detection loop
/// in AIAssessmentScreen (which drives its own capture UI frame by
/// frame) -- this service answers one narrower question, "does this
/// already-picked file contain a detectable face?", for any screen that
/// hands it a File: Registration's reference photo today, Check-In's
/// today photo next.
class PhotoValidationService {
  PhotoValidationService();

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  /// Returns true if at least one face is detected in [image].
  /// Returns false both when detection completes with zero faces and
  /// when detection itself throws -- either way, the image can't be
  /// confirmed to contain a face, so callers should treat it as
  /// rejected rather than silently letting it through.
  Future<bool> hasDetectableFace(File image) async {
    try {
      final input = InputImage.fromFile(image);
      final faces = await _faceDetector.processImage(input);
      return faces.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}
