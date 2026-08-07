import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/assessment_result.dart';

class AssessmentApi {
  AssessmentApi();

  /// File → Base64
  String _imageToBase64(File image) {
    final bytes = image.readAsBytesSync();
    return base64Encode(bytes);
  }

  /// Download Firebase image → Base64
  Future<String> _urlToBase64(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));

    if (response.statusCode != 200) {
      throw Exception("Unable to download reference photo.");
    }

    return base64Encode(response.bodyBytes);
  }

  /// Claude Headers
  Map<String, String> _headers() {
    return {
      "Content-Type": "application/json",
      "x-api-key": ApiConfig.apiKey,
      "anthropic-version": ApiConfig.anthropicVersion,
    };
  }

  /// Send Claude Request
  Future<http.Response> _sendRequest(Map<String, dynamic> body) async {
    return await http.post(
      Uri.parse(ApiConfig.baseUrl),
      headers: _headers(),
      body: jsonEncode(body),
    );
  }

  Map<String, dynamic> _buildRequestBody({
    required String referenceImageBase64,
    required String todayImageBase64,
    required String prompt,
  }) {
    return {
      "model": ApiConfig.model,
      "max_tokens": ApiConfig.maxTokens,
      "messages": [
        {
          "role": "user",
          "content": [
            {
              "type": "image",
              "source": {
                "type": "base64",
                "media_type": "image/jpeg",
                "data": referenceImageBase64,
              },
            },
            {
              "type": "image",
              "source": {
                "type": "base64",
                "media_type": "image/jpeg",
                "data": todayImageBase64,
              },
            },
            {"type": "text", "text": prompt},
          ],
        },
      ],
    };
  }

  Future<bool> detectPerson({required File image}) async {
    try {
      final imageBase64 = _imageToBase64(image);

      const prompt = r'''
Is this a FULL-BODY standing photo of ONE person?

The photo MUST satisfy ALL conditions:

1. Exactly ONE person.
2. Face clearly visible.
3. Hair clearly visible.
4. Entire uniform visible.
5. Shoes clearly visible.
6. Standing upright.
7. Front facing.
8. Arms visible.
9. Legs visible.
10. No body part cropped.
11. Not sitting.
12. Not selfie.
13. Not side view.
14. Entire body fits inside the image.
15. Suitable for airline grooming assessment.

Reply ONLY:

YES

or

NO
''';

      final body = {
        "model": ApiConfig.model,
        "max_tokens": 20,
        "messages": [
          {
            "role": "user",
            "content": [
              {
                "type": "image",
                "source": {
                  "type": "base64",
                  "media_type": "image/jpeg",
                  "data": imageBase64,
                },
              },
              {"type": "text", "text": prompt},
            ],
          },
        ],
      };

      final response = await _sendRequest(body);

      if (response.statusCode != 200) {
        return false;
      }

      final json = jsonDecode(response.body);

      final text = json["content"][0]["text"].toString().trim().toUpperCase();

      return text.contains("YES");
    } catch (e) {
      debugPrint("DetectPerson Error: $e");
      return false;
    }
  }

  Future<AssessmentResult?> analyze({
    required String referencePhotoUrl,
    required File todayPhoto,
  }) async {
    try {
      final todayImageBase64 = _imageToBase64(todayPhoto);

      final referenceImageBase64 = await _urlToBase64(referencePhotoUrl);

      const prompt = r'''
You are a senior professional grooming assessor for Batik Air cabin crew. Apply STRICT airline-grade standards.

You are given TWO photos:
- Image 1: REFERENCE photo - approved best-appearance standard
- Image 2: TODAY's check-in photo - score strictly against the reference

STEP 1 - DETECT GENDER: Look at reference photo. Return "gender":"male" or "female".

STEP 2 - FOR EACH CATEGORY: Check rules. Apply LOWEST matching cap. If no cap, use general rubric.

GENERAL RUBRIC (only when no cap applies):
9-10: Perfect - zero visible flaws
6-8: Meets standard - very minor imperfection
3-5: Borderline - visible issue
2: Clear obvious problem
0-1: Severe violation

SCORING PRINCIPLE: When uncertain, pick LOWER score.

HAIR (FEMALE):
Major flyaways + unkempt/loose -> MAX 2
Untidy + flyaways -> MAX 5
Untidy only OR minimal flyaways -> MAX 7
No issues -> up to 10

HAIR (MALE) TIER 1 - If ANY true -> MAX 3, stop:
Hair exceeds shirt collar, crown exceeds 4cm, covers ears, prohibited style (punk/spike/mullet), sideburns exceed earlobe or 1.5cm width
TIER 2 (only if Tier 1 passed): same caps as female hair above

FACIAL GROOMING (MALE):
Unshaven (visible beard/patchy) -> MAX 3
Stubble (short prickly growth) -> MAX 5
Minor shadow (very slight, visible follicles) -> MAX 6
Clean shaven -> up to 10

GROOMING/MAKEUP (FEMALE):
No makeup at all -> MAX 2
Multiple issues (wrong colours + messy) -> MAX 2
Two issues (e.g. bold eyes + bold lips) -> MAX 4
One issue (eye too bold/light, lips too bold/light, wrong colour, single element faded) -> MAX 7
No issues -> up to 10

SKIN CONDITION:
Visible blemishes no coverage -> MAX 5
Minor redness or uneven tone -> MAX 7
No issues -> up to 10

UNIFORM:
Any crease or stain -> MAX 4
Slightly creased no stains -> MAX 6
No issues -> up to 10

SHOES:
Any unpolished, scuffed or dirty -> MAX 3
Slight dulling no scuffs -> MAX 6
No issues -> up to 10

BODY WEIGHT - Zero tolerance:
10=Exceptionally slim/fit
8=Slim healthy
5=Borderline slim
3=Any visible excess FAILS
1=Clearly overweight
0=Severely overweight

Any weight concern -> 3 or below. Score DOWN.

CATEGORIES:
1. Hair
2. IF FEMALE label "Grooming"
   IF MALE label "Facial Grooming"
3. Skin Condition
4. Uniform
5. Shoes
6. Body Weight

Return ONLY valid JSON:

{
  "gender":"female",
  "overall":"Good",
  "criteria":[
    {
      "label":"Hair",
      "score":7,
      "tip":"Tip."
    },
    {
      "label":"Grooming",
      "score":7,
      "tip":"Tip."
    },
    {
      "label":"Skin Condition",
      "score":8,
      "tip":"Tip."
    },
    {
      "label":"Uniform",
      "score":8,
      "tip":"Tip."
    },
    {
      "label":"Shoes",
      "score":7,
      "tip":"Tip."
    },
    {
      "label":"Body Weight",
      "score":7,
      "tip":"Tip."
    }
  ],
  "summary":"2-3 sentences. Specific differences from reference."
}
''';
      final requestBody = _buildRequestBody(
        referenceImageBase64: referenceImageBase64,
        todayImageBase64: todayImageBase64,
        prompt: prompt,
      );

      final response = await _sendRequest(requestBody);

      debugPrint(response.body);

      if (response.statusCode != 200) {
        throw Exception(response.body);
      }

      final responseJson = jsonDecode(response.body);

      if (responseJson["content"] == null ||
          (responseJson["content"] as List).isEmpty) {
        throw Exception("Claude returned empty content.");
      }

      final rawText = responseJson["content"][0]["text"];

      final cleanText = rawText
          .replaceAll("```json", "")
          .replaceAll("```", "")
          .trim();

      final resultJson = jsonDecode(cleanText);

      return AssessmentResult.fromJson(resultJson);
    } catch (e) {
      debugPrint("Assessment Error: $e");
      return null;
    }
  }
}
