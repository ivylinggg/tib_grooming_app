import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/apps_script_config.dart';
import '../models/assessment_result.dart';

/// Minimal internal capture of an HTTP response -- status, body, the
/// `Location` header for following a redirect, and any `Set-Cookie` for
/// carrying a session forward across redirect hops. Not exposed outside
/// this file. Mirrors GoogleDriveApi's identical private type -- kept
/// separate rather than shared so this fix stays self-contained to this
/// file.
class _RawHttpResult {
  final int statusCode;
  final String body;
  final String? location;
  final String? setCookie;

  const _RawHttpResult({
    required this.statusCode,
    required this.body,
    this.location,
    this.setCookie,
  });
}

/// Calls the Apps Script backend (apps_script/Code.gs + Claude.gs) for
/// full-body detection and AI grooming analysis. Claude itself is only
/// ever called from Apps Script now -- this class no longer talks to
/// api.anthropic.com directly, so no API key lives in the client.
///
/// Technical debt: `detectPerson`/`analyze` still report failure as
/// `false`/`null`, collapsing "Apps Script unreachable", "Claude error",
/// and "bad response shape" into one outcome. This should eventually
/// adopt the same typed Result Object pattern introduced for
/// registration in lib/models/register_result.dart, so callers can tell
/// those cases apart. Not done in this phase -- the return types were
/// required to stay unchanged.
class AssessmentApi {
  AssessmentApi();

  /// detectPerson's prompt is short (max_tokens: 20), so a stalled
  /// connection or a stuck Claude call is bounded tightly. analyze sends
  /// two images and a long rubric prompt (max_tokens: 2500), so it gets
  /// more headroom. Both are well under Apps Script's own execution
  /// ceiling for a Web App request.
  static const _detectPersonTimeout = Duration(seconds: 20);
  static const _analyzeTimeout = Duration(seconds: 45);

  /// File → Base64
  String _imageToBase64(File image) {
    final bytes = image.readAsBytesSync();
    return base64Encode(bytes);
  }

  /// Download Firebase/Drive image → Base64. Apps Script's analyze action
  /// takes the reference image as base64, not a URL, so it is still
  /// downloaded and encoded here before the request is sent.
  Future<String> _urlToBase64(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));

    if (response.statusCode != 200) {
      throw Exception("Unable to download reference photo.");
    }

    return base64Encode(response.bodyBytes);
  }

  /// POST a JSON body to the Apps Script deployment and decode the JSON
  /// response. Matches Code.gs's doPost, which dispatches on `action`.
  ///
  /// Apps Script Web App URLs (script.google.com/macros/s/.../exec)
  /// always answer with an HTTP 302 to a script.googleusercontent.com
  /// URL that carries the actual computed response -- Google's own
  /// infrastructure behavior for every Web App deployment, the same one
  /// GoogleDriveApi.uploadImage() had to handle for the upload action on
  /// this exact endpoint. `analyze`/`detectPerson` hit that same /exec
  /// URL, so they need the same redirect-following, which a plain
  /// http.post() (the previous implementation here) never did -- it
  /// just threw on the raw 302 status.
  ///
  /// [timeout] bounds the whole request (including Apps Script's
  /// synchronous Claude call) so a stalled connection fails fast instead
  /// of waiting indefinitely; a timeout surfaces as a TimeoutException,
  /// caught by the callers' existing try/catch alongside every other
  /// failure.
  Future<Map<String, dynamic>> _post(
    Map<String, dynamic> body, {
    required Duration timeout,
  }) async {
    final client = HttpClient();

    try {
      final requestBody = jsonEncode(body);

      _RawHttpResult current = await _send(
        client,
        method: "POST",
        url: Uri.parse(AppsScriptConfig.execUrl),
        body: requestBody,
      ).timeout(timeout);

      debugPrint("========== APPS SCRIPT REQUEST RESPONSE (hop 0) ==========");
      debugPrint("Status: ${current.statusCode}");

      const maxRedirectHops = 5;
      String? cookie = current.setCookie;
      var hop = 0;

      while (_isRedirect(current.statusCode) && hop < maxRedirectHops) {
        hop++;

        final location = current.location;

        debugPrint(
          "APPS SCRIPT REQUEST: HTTP ${current.statusCode} redirect at hop "
          "${hop - 1}, following to: $location",
        );

        if (location == null || location.isEmpty) {
          throw Exception(
            "Apps Script request redirected but did not say where to "
            "(HTTP ${current.statusCode}, missing Location header).",
          );
        }

        // The redirect target already carries Apps Script's computed
        // response -- doPost() already ran on the very first request.
        // Every hop from here on is a plain GET with no body.
        current = await _send(
          client,
          method: "GET",
          url: Uri.parse(location),
          cookie: cookie,
        ).timeout(timeout);

        cookie = current.setCookie ?? cookie;

        debugPrint(
          "========== APPS SCRIPT REQUEST RESPONSE (hop $hop) ==========",
        );
        debugPrint("Status: ${current.statusCode}");
        debugPrint("Body: ${current.body}");
      }

      if (_isRedirect(current.statusCode)) {
        throw Exception(
          "Apps Script request kept redirecting and never reached a "
          "final response (last status ${current.statusCode}).",
        );
      }

      if (current.statusCode != 200) {
        throw Exception("Apps Script request failed: ${current.statusCode}");
      }

      return jsonDecode(current.body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// Issues one HTTP request with automatic redirect-following turned
  /// off, so 3xx responses come back to the caller to handle explicitly.
  /// Sends [cookie] as the `Cookie` header when following a later hop of
  /// a redirect chain, and always reports any `Set-Cookie` the response
  /// sent back so the caller can carry it to the next hop.
  Future<_RawHttpResult> _send(
    HttpClient client, {
    required String method,
    required Uri url,
    String? body,
    String? cookie,
  }) async {
    final request = await client.openUrl(method, url);
    request.followRedirects = false;

    request.headers.set(HttpHeaders.userAgentHeader, "tib-grooming-app/1.0");

    if (cookie != null && cookie.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookie);
    }

    if (body != null) {
      request.headers.set(HttpHeaders.contentTypeHeader, "application/json");
      request.write(body);
    }

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    final setCookie = response.cookies.isEmpty
        ? null
        : response.cookies.map((c) => "${c.name}=${c.value}").join("; ");

    return _RawHttpResult(
      statusCode: response.statusCode,
      body: responseBody,
      location: response.headers.value(HttpHeaders.locationHeader),
      setCookie: setCookie,
    );
  }

  bool _isRedirect(int statusCode) {
    return statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 303 ||
        statusCode == 307 ||
        statusCode == 308;
  }

  Future<bool> detectPerson({required File image}) async {
    try {
      final imageBase64 = _imageToBase64(image);

      final json = await _post({
        "action": "detectPerson",
        "imageBase64": imageBase64,
        "mimeType": "image/jpeg",
      }, timeout: _detectPersonTimeout);

      if (json["success"] != true) {
        return false;
      }

      return json["isFullBody"] == true;
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

      final json = await _post({
        "action": "analyze",
        "referenceB64": referenceImageBase64,
        "referenceMime": "image/jpeg",
        "todayB64": todayImageBase64,
        "todayMime": "image/jpeg",
      }, timeout: _analyzeTimeout);

      debugPrint(json.toString());

      if (json["success"] == false) {
        throw Exception(json["error"] ?? "Apps Script analyze failed.");
      }

      return AssessmentResult.fromJson(json);
    } catch (e) {
      debugPrint("Assessment Error: $e");
      return null;
    }
  }
}
