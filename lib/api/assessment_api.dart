import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/apps_script_config.dart';
import '../models/assessment_result.dart';
import '../models/captured_image.dart';

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

/// User-facing copy for a photo [AssessmentApi.detectPerson] rejected --
/// shared by every capture/upload entry point (CheckInCard,
/// AIAssessmentScreen) that calls it, so a rejection always says exactly
/// the same thing regardless of which screen or which of Camera/Gallery
/// produced the photo.
const String kFullBodyPhotoErrorMessage =
    "Please take a full-body photo. Make sure your entire body, "
    "including your feet, is visible.";

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
  static const _notifyTimeout = Duration(seconds: 20);

  /// CapturedImage → Base64. Reads through [CapturedImage.readAsBytes],
  /// which works identically on native (reads the wrapped `File`) and
  /// web (returns bytes already captured at pick/capture time) -- see
  /// that class's doc comment for why a plain `dart:io File` can't do
  /// this on web.
  Future<String> _imageToBase64(CapturedImage image) async {
    final bytes = await image.readAsBytes();
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
    final client = http.Client();

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
  ///
  /// Uses `package:http` (cross-platform) instead of a raw `dart:io
  /// HttpClient` -- `dart:io`'s `HttpClient` is backed by real TCP
  /// sockets, which browsers never expose to Dart, so constructing one
  /// throws `UnsupportedError` immediately on Flutter Web.
  ///
  /// `followRedirects = false` is only ever set on native platforms. On
  /// every native platform, `package:http`'s default client is itself
  /// backed by `dart:io.HttpClient`, and `http.Request.followRedirects`/
  /// `maxRedirects` map directly onto that client's own redirect
  /// handling -- so this hop-by-hop loop still behaves identically to
  /// before there. On web, `package:http`'s browser client is backed by
  /// the browser's own fetch/XHR layer, which always follows a redirect
  /// before Dart code ever sees the response -- it has no supported way
  /// to disable that from here, and never exposes an intermediate
  /// Location/Set-Cookie header to script either, by browser design --
  /// so `followRedirects` is left at its default there, `current.
  /// statusCode` comes back already the final response, this loop's
  /// `_isRedirect` check simply never fires, and the request still
  /// reaches the same Apps Script JSON response.
  Future<_RawHttpResult> _send(
    http.Client client, {
    required String method,
    required Uri url,
    String? body,
    String? cookie,
  }) async {
    final request = http.Request(method, url);

    if (!kIsWeb) {
      request.followRedirects = false;
      request.maxRedirects = 0;
    }

    request.headers["User-Agent"] = "tib-grooming-app/1.0";

    if (cookie != null && cookie.isNotEmpty) {
      request.headers["Cookie"] = cookie;
    }

    if (body != null) {
      request.headers["Content-Type"] = "application/json";
      request.body = body;
    }

    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    return _RawHttpResult(
      statusCode: response.statusCode,
      body: response.body,
      location: response.headers["location"],
      setCookie: response.headers["set-cookie"],
    );
  }

  bool _isRedirect(int statusCode) {
    return statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 303 ||
        statusCode == 307 ||
        statusCode == 308;
  }

  Future<bool> detectPerson({required CapturedImage image}) async {
    try {
      final imageBase64 = await _imageToBase64(image);

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
    required CapturedImage todayPhoto,
  }) async {
    try {
      final todayImageBase64 = await _imageToBase64(todayPhoto);

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

  /// Tells the Apps Script backend to send the "[URGENT] Grooming
  /// Assessment Failed" email -- routed through the same deployment as
  /// [analyze]/[detectPerson] (Code.gs's doPost, action: "notifyFailure"
  /// -> apps_script/Notify.gs), reusing this class's existing [_post]
  /// redirect-following/timeout machinery rather than standing up a
  /// second HTTP client for one more action. No email credentials live
  /// here or anywhere in Flutter -- MailApp runs inside Apps Script, as
  /// whichever account deployed it.
  ///
  /// Deliberately does NOT take or send any recipient address. Apps
  /// Script resolves who the Admin recipients are entirely on its own
  /// (from its own Script Properties -- see Notify.gs's doc comment),
  /// so this request only ever carries the assessment's own data. This
  /// is what makes it safe to call from the fully anonymous, no-auth
  /// Staff Check-In flow as well as the signed-in Admin Assessment flow
  /// -- there is no `users` query and no admin address anywhere in
  /// Flutter for either caller to see.
  ///
  /// Returns false (never throws) on any failure -- Apps Script
  /// unreachable, a non-2xx/redirect-loop response, or Apps Script
  /// itself reporting `success: false` (including "no admin recipient
  /// configured"). The caller (FirebaseService._maybeNotifyAdminOfFailure)
  /// treats this exactly like every other failure mode: logged, and the
  /// already-saved assessment is never affected either way.
  Future<bool> notifyAdminOfFailedAssessment({
    required String assessmentId,
    required String participantId,
    required String participantName,
    String? trainerName,
    required int totalScore,
    required String overall,
    required String summary,
    required String suggestion,
    required List<Map<String, dynamic>> criteria,
    String? assessmentDateText,
  }) async {
    try {
      final json = await _post({
        "action": "notifyFailure",
        "assessmentId": assessmentId,
        "participantId": participantId,
        "participantName": participantName,
        "trainerName": trainerName ?? "",
        "totalScore": totalScore,
        "overall": overall,
        "summary": summary,
        "suggestion": suggestion,
        "criteria": criteria,
        "assessmentDate": assessmentDateText ?? "",
      }, timeout: _notifyTimeout);

      if (json["success"] != true) {
        debugPrint(
          "notifyAdminOfFailedAssessment: Apps Script reported failure - "
          "${json["error"]}",
        );
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("notifyAdminOfFailedAssessment: $e");
      return false;
    }
  }
}
