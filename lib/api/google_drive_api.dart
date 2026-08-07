import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/google_drive_config.dart';

class GoogleDriveApi {
  GoogleDriveApi._();

  static Future<String?> uploadImage({
    required File image,
    required String fileName,
  }) async {
    try {
      final bytes = await image.readAsBytes();

      final request = http.Request(
        "POST",
        Uri.parse(GoogleDriveConfig.uploadUrl),
      );

      request.headers["Content-Type"] = "application/json";

      request.body = jsonEncode({
        "image": base64Encode(bytes),
        "fileName": fileName,
        "mimeType": _getMimeType(image.path),
      });

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("========== STATUS ==========");
      debugPrint(response.statusCode.toString());

      debugPrint("========== BODY ==========");
      debugPrint(response.body);

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body);

      debugPrint("========== JSON ==========");
      debugPrint(json.toString());

      if (json["success"] != true) {
        return null;
      }

      final imageUrl = json["imageUrl"] as String;

      return imageUrl;
    } catch (e) {
      debugPrint("Google Drive Upload Error");
      debugPrint(e.toString());
      return null;
    }
  }

  static String _getMimeType(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith(".png")) return "image/png";
    if (lower.endsWith(".jpg")) return "image/jpeg";
    if (lower.endsWith(".jpeg")) return "image/jpeg";
    if (lower.endsWith(".heic")) return "image/heic";

    return "image/jpeg";
  }
}
