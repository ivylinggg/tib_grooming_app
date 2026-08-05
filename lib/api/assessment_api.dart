import 'dart:io';

import '../models/assessment_result.dart';
import 'package:flutter/foundation.dart';

class AssessmentApi {
  /// Claude AI Grooming Assessment
  ///
  /// Workflow
  ///
  /// Firebase Storage
  ///     │
  ///     ├── Reference Photo
  ///     └── Today's Photo
  ///             │
  ///             ▼
  /// Claude Vision API
  ///             │
  ///             ▼
  /// AssessmentResult
  ///             │
  ///             ▼
  /// Firestore
  ///
  /// Current version uses mock data.
  /// Claude API integration will be added later.

  Future<AssessmentResult?> analyze({
    required String referencePhotoUrl,
    required File todayPhoto,
  }) async {
    try {
      // Future Flow:
      //
      // 1. Upload today's photo to Firebase Storage.
      // 2. Get today's photo URL.
      // 3. Send reference photo URL + today's photo URL to Claude AI.
      // 4. Claude returns JSON assessment.
      // 5. Save assessment result into Firestore.
      // 6. Admin Dashboard updates automatically.

      await Future.delayed(const Duration(seconds: 2));

      return AssessmentResult.fromJson({
        "success": true,
        "overallScore": 90,
        "overallResult": "PASS",
        "hair": "Pass",
        "face": "Pass",
        "uniform": "Pass",
        "shoes": "Pass",
        "comment":
            "Mock result. Claude AI integration has not been enabled yet.",
      });
    } catch (e) {
      debugPrint("Assessment Error: $e");
      return null;
    }
  }
}
