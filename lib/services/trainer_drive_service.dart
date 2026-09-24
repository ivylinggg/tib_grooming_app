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
    required String trainingDate,
    required String participantName,
  }) async {
    final payload = <String, dynamic>{
      'action': 'uploadTrainingHistoryPhoto',
      'image': base64Encode(bytes),
      'fileName': fileName,
      'trainingDate': trainingDate.trim(),
      'participantName': participantName.trim(),
    };

    final response = await _postWithRedirects(
      Uri.parse(uploadEndpoint),
      payload,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrainerDriveException(
        'Drive upload failed (HTTP ${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body);

    if (body is! Map<String, dynamic>) {
      throw const TrainerDriveException('Invalid upload response.');
    }

    final success = body['success'] == true;
    final url = body['url']?.toString().trim() ?? '';

    if (!success || url.isEmpty) {
      final message = body['message']?.toString().trim();
      throw TrainerDriveException(
        message == null || message.isEmpty
            ? 'The upload service did not return a photo URL.'
            : message,
      );
    }

    return url;
  }

  Future<http.Response> _postWithRedirects(
    Uri uri,
    Map<String, dynamic> payload,
  ) async {
    var currentUri = uri;
    var body = jsonEncode(payload);

    for (var attempt = 0; attempt < 5; attempt++) {
      final response = await _client.post(
        currentUri,
        headers: const {
          'Content-Type': 'application/json',
        },
        body: body,
      );

      final location = response.headers['location'];
      final isRedirect = response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 307 ||
          response.statusCode == 308;

      if (!isRedirect || location == null || location.isEmpty) {
        return response;
      }

      currentUri = currentUri.resolve(location);
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
