import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/assessment_result.dart';

class ApiService {
  ApiService();

  static const String baseUrl =
      "https://script.google.com/macros/s/AKfycbzlAKRrgZxcZMXVbzBohhDIcsrJg3blExF0Lfm6cJ4VQbQIW4RoFCI4gUBYqBkh4wiU/exec";

  Future<AssessmentResult> analyzeImage({
    required String referenceB64,
    required String referenceMime,
    required String todayB64,
    required String todayMime,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: const {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({
              "type": "analyze",

              // Reference Photo
              "referenceB64": referenceB64,
              "referenceMime": referenceMime,

              // Today's Photo
              "todayB64": todayB64,
              "todayMime": todayMime,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception(
          "Server Error (${response.statusCode}): ${response.body}",
        );
      }

      final json = jsonDecode(response.body);

      if (json["success"] != true) {
        throw Exception(json["error"] ?? "Unknown server error.");
      }

      return AssessmentResult.fromJson(json);
    } catch (e) {
      throw Exception("Failed to analyze image.\n$e");
    }
  }
}
