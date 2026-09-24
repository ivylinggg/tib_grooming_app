import 'dart:convert';

import 'package:http/http.dart' as http;

class TrainerDriveService {
  TrainerDriveService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String uploadEndpoint =
      'https://script.google.com/macros/s/AKfycbxD6aLF1Lmihlv_vd2-noo3E-qeBpR4PmNZV7xrvHVSRSU_jkj8Dnps6URhXdzhS3bG/exec';

  Future<String> uploadTrainingPhoto({
    required List<int> bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
    required String trainingDate,
    required String participantName,
  }) async {
    final payload = jsonEncode(<String, dynamic>{
      'image': base64Encode(bytes),
      'fileName': fileName,
      'mimeType': mimeType,
      'trainingDate': trainingDate.trim(),
      'participantName': participantName.trim(),
    });

    var uri = Uri.parse(uploadEndpoint);

    for (var attempt = 0; attempt < 5; attempt++) {
      final response = await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: payload,
      );

      final location = response.headers['location'];
      final isRedirect = response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 307 ||
          response.statusCode == 308;

      if (isRedirect && location != null && location.isNotEmpty) {
        uri = uri.resolve(location);
        continue;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TrainerDriveException(
          'Drive upload failed (HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const TrainerDriveException('Invalid upload response.');
      }

      if (decoded['success'] != true) {
        final error = decoded['error']?.toString().trim();
        final message = decoded['message']?.toString().trim();
        throw TrainerDriveException(
          error != null && error.isNotEmpty
              ? error
              : message != null && message.isNotEmpty
                  ? message
                  : 'The upload service reported a failure.',
        );
      }

      final imageUrl = decoded['imageUrl']?.toString().trim();
      final url = decoded['url']?.toString().trim();
      final result = imageUrl != null && imageUrl.isNotEmpty ? imageUrl : url;

      if (result == null || result.isEmpty) {
        throw const TrainerDriveException(
          'The upload service did not return an image URL.',
        );
      }

      return result;
    }

    throw const TrainerDriveException(
      'The upload service redirected too many times.',
    );
  }
}

class TrainerDriveException implements Exception {
  const TrainerDriveException(this.message);

  final String message;

  @override
  String toString() => message;
}
