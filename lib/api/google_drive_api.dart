import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/google_drive_config.dart';

/// What actually happened on a [GoogleDriveApi.uploadImage] call --
/// replaces the old bare `String?` return, which collapsed every
/// distinct failure (bad HTTP status, Apps Script reporting
/// `success: false`, a malformed response, a thrown exception) into the
/// same "return null" signal, with no way for the caller to know which
/// one actually happened or say anything more specific than a generic
/// "check your connection" message.
class DriveUploadResult {
  final bool success;
  final String? imageUrl;

  /// Short, safe-to-show-the-user description of what went wrong.
  final String? errorMessage;

  /// Full detail (HTTP status/body, Apps Script `error` field, raw
  /// exception) for debugPrint/logs only -- never shown in the UI.
  final String? rawError;

  const DriveUploadResult._({
    required this.success,
    this.imageUrl,
    this.errorMessage,
    this.rawError,
  });

  factory DriveUploadResult.success(String imageUrl) =>
      DriveUploadResult._(success: true, imageUrl: imageUrl);

  factory DriveUploadResult.failure({
    required String errorMessage,
    String? rawError,
  }) => DriveUploadResult._(
    success: false,
    errorMessage: errorMessage,
    rawError: rawError,
  );
}

/// Thrown (wrapped as the `exception` on `RegisterResult.uploadFailed`)
/// so the UI layer can show [message] specifically instead of a
/// one-size-fits-all "upload failed" string. See
/// FirebaseService.registerParticipant and RegisterScreen's
/// `_messageFor`.
class DriveUploadException implements Exception {
  final String message;
  const DriveUploadException(this.message);

  @override
  String toString() => message;
}

/// Minimal internal capture of an HTTP response -- just what
/// [GoogleDriveApi.uploadImage]'s redirect handling needs (status,
/// body text, the `Location` header for following a redirect, and any
/// `Set-Cookie` for carrying a session forward across redirect hops).
/// Not exposed outside this file.
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

class GoogleDriveApi {
  GoogleDriveApi._();

  static Future<DriveUploadResult> uploadImage({
    required File image,
    required String fileName,
  }) async {
    final client = HttpClient();

    try {
      final bytes = await image.readAsBytes();

      final requestBody = jsonEncode({
        "image": base64Encode(bytes),
        "fileName": fileName,
        "mimeType": _getMimeType(image.path),
      });

      // Apps Script Web App URLs (script.google.com/macros/s/.../exec)
      // always answer with an HTTP 302 to a script.googleusercontent.com
      // URL that carries the actual computed response -- for BOTH GET and
      // POST. This is Google's own infrastructure behavior for every Web
      // App deployment, not something doPost()/doGet() controls or a bug
      // in this project's Apps Script code (see apps_script/Code.gs --
      // its doPost never sets a redirect; ContentService.createTextOutput
      // always yields a plain 200 from the script's own point of view).
      // followRedirects is turned off deliberately in _send() below so
      // this method sees each 302 directly and can follow it itself.
      //
      // Observed in practice: this can be MORE than one hop (a second
      // redirect off the first Location, apparently needing the cookie
      // the first hop set to actually reach the final googleusercontent
      // response instead of looping back through another redirect) --
      // so this follows a full chain, carrying cookies forward between
      // hops, instead of assuming a single hop like the first version
      // of this fix did.
      _RawHttpResult current =
          await _send(
            client,
            method: "POST",
            url: Uri.parse(GoogleDriveConfig.uploadUrl),
            body: requestBody,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Google Drive upload request timed out'),
          );

      debugPrint("========== GOOGLE DRIVE UPLOAD RESPONSE (hop 0) ==========");
      debugPrint("Status: ${current.statusCode}");

      const maxRedirectHops = 5;
      String? cookie = current.setCookie;
      var hop = 0;

      while (_isRedirect(current.statusCode) && hop < maxRedirectHops) {
        hop++;

        final location = current.location;

        debugPrint(
          "GOOGLE DRIVE UPLOAD: HTTP ${current.statusCode} redirect at hop "
          "${hop - 1}, following to: $location",
        );

        if (location == null || location.isEmpty) {
          debugPrint(
            "GOOGLE DRIVE UPLOAD ERROR (redirect with no Location header): "
            "HTTP ${current.statusCode} at hop ${hop - 1}",
          );
          return DriveUploadResult.failure(
            errorMessage:
                "The upload service redirected the request but did not "
                "say where to.",
            rawError:
                "HTTP ${current.statusCode} with missing Location header "
                "at hop ${hop - 1}",
          );
        }

        // The redirect target already carries Apps Script's computed
        // response -- doPost() already ran on the very first request.
        // Every hop from here on is a plain GET with no body; nothing
        // needs to be (and nothing should be) POSTed again. Any cookie
        // the previous hop set is carried forward -- Google's own
        // redirect chain for Apps Script Web Apps can depend on it to
        // actually progress instead of bouncing back.
        current =
            await _send(
              client,
              method: "GET",
              url: Uri.parse(location),
              cookie: cookie,
            ).timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException(
                'Google Drive upload redirect follow-up timed out',
              ),
            );

        cookie = current.setCookie ?? cookie;

        debugPrint(
          "========== GOOGLE DRIVE UPLOAD RESPONSE (hop $hop) ==========",
        );
        debugPrint("Status: ${current.statusCode}");
        debugPrint("Body: ${current.body}");
      }

      if (_isRedirect(current.statusCode)) {
        debugPrint(
          "GOOGLE DRIVE UPLOAD ERROR (redirect loop): still redirecting "
          "after $maxRedirectHops hops, last status "
          "${current.statusCode}, last Location: ${current.location}",
        );
        return DriveUploadResult.failure(
          errorMessage:
              "The upload service kept redirecting the request and never "
              "reached a final response.",
          rawError:
              "Redirect loop: $maxRedirectHops+ hops, last status "
              "${current.statusCode}, last Location: ${current.location}",
        );
      }

      final finalResult = current;

      if (finalResult.statusCode != 200) {
        final detail = "HTTP ${finalResult.statusCode}: ${finalResult.body}";
        debugPrint("GOOGLE DRIVE UPLOAD ERROR (bad status): $detail");
        return DriveUploadResult.failure(
          errorMessage: _messageForStatus(finalResult.statusCode),
          rawError: detail,
        );
      }

      // A 200 whose body is HTML (starts with "<") rather than JSON
      // means the redirect landed on a Google sign-in / consent page
      // instead of the actual Apps Script output -- this happens when
      // the deployment's "Who has access" is not set to "Anyone", so
      // the anonymous request gets bounced to a login wall that itself
      // answers 200. That's a deployment setting, not something this
      // app's code can fix.
      final trimmedBody = finalResult.body.trimLeft();
      if (trimmedBody.startsWith("<")) {
        debugPrint(
          "GOOGLE DRIVE UPLOAD ERROR (got an HTML page instead of JSON -- "
          "likely a Google sign-in/consent page): "
          "${finalResult.body.substring(0, finalResult.body.length.clamp(0, 300))}",
        );
        return DriveUploadResult.failure(
          errorMessage:
              "The upload service requires sign-in. In the Apps Script "
              "deployment settings, set \"Who has access\" to \"Anyone\" "
              "and \"Execute as\" to the script owner, then redeploy.",
          rawError: "Received HTML instead of JSON: ${finalResult.body}",
        );
      }

      final Map<String, dynamic> json;
      try {
        json = jsonDecode(finalResult.body) as Map<String, dynamic>;
      } catch (e, stackTrace) {
        debugPrint(
          "GOOGLE DRIVE UPLOAD ERROR (malformed JSON): ${finalResult.body}",
        );
        debugPrintStack(stackTrace: stackTrace);
        return DriveUploadResult.failure(
          errorMessage: "The upload service returned an unexpected response.",
          rawError: "Malformed JSON: ${finalResult.body} ($e)",
        );
      }

      if (json["success"] != true) {
        // Apps Script's own doPost catch block returns
        // `{success: false, error: err.toString()}` with HTTP 200 for
        // any server-side failure (bad folder ID, Drive quota,
        // permission denied on the deployment, etc.) -- that `error`
        // field is the actual root cause.
        final scriptError =
            json["error"]?.toString() ?? "Unknown Apps Script error";
        debugPrint("GOOGLE DRIVE UPLOAD ERROR (Apps Script): $scriptError");
        return DriveUploadResult.failure(
          errorMessage: scriptError,
          rawError: scriptError,
        );
      }

      final imageUrl = json["imageUrl"] as String?;

      if (imageUrl == null) {
        debugPrint(
          "GOOGLE DRIVE UPLOAD ERROR (success but no imageUrl): "
          "${finalResult.body}",
        );
        return DriveUploadResult.failure(
          errorMessage: "The upload service did not return an image URL.",
          rawError: "Missing imageUrl: ${finalResult.body}",
        );
      }

      debugPrint("GOOGLE DRIVE UPLOAD: success -- $imageUrl");
      return DriveUploadResult.success(imageUrl);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint("GOOGLE DRIVE UPLOAD ERROR (timeout): $e");
      debugPrintStack(stackTrace: stackTrace);
      return DriveUploadResult.failure(
        errorMessage:
            "The upload timed out. Please check your connection and try again.",
        rawError: e.toString(),
      );
    } on SocketException catch (e, stackTrace) {
      debugPrint("GOOGLE DRIVE UPLOAD ERROR (network/socket): $e");
      debugPrintStack(stackTrace: stackTrace);
      return DriveUploadResult.failure(
        errorMessage:
            "Could not reach the upload service. Please check your connection.",
        rawError: e.toString(),
      );
    } catch (e, stackTrace) {
      debugPrint("GOOGLE DRIVE UPLOAD ERROR (unexpected): $e");
      debugPrintStack(stackTrace: stackTrace);
      return DriveUploadResult.failure(
        errorMessage: "Reference photo upload failed.",
        rawError: e.toString(),
      );
    } finally {
      client.close();
    }
  }

  /// Issues one HTTP request with automatic redirect-following turned
  /// off, so 3xx responses come back to the caller to handle explicitly
  /// instead of the client silently (and, per the bug this fixes,
  /// apparently unreliably) chasing them on its own. Sends [cookie] as
  /// the `Cookie` header when following a later hop of a redirect
  /// chain, and always reports any `Set-Cookie` the response sent back
  /// so the caller can carry it to the next hop.
  static Future<_RawHttpResult> _send(
    HttpClient client, {
    required String method,
    required Uri url,
    String? body,
    String? cookie,
  }) async {
    final request = await client.openUrl(method, url);
    request.followRedirects = false;

    // A plain Dart HttpClient sends no User-Agent by default. Google's
    // frontend has been observed treating User-Agent-less requests to
    // script.google.com differently (an extra interstitial/redirect
    // hop) -- sending one that looks like a normal HTTP client keeps
    // this on the same path a browser or curl would take.
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

  static bool _isRedirect(int statusCode) {
    return statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 303 ||
        statusCode == 307 ||
        statusCode == 308;
  }

  static String _messageForStatus(int statusCode) {
    switch (statusCode) {
      case 401:
        return "The upload service rejected the request (unauthorized).";
      case 403:
        return "The upload service denied access (forbidden). Check the "
            "Apps Script deployment's access settings.";
      case 404:
        return "The upload service endpoint was not found. Check the "
            "deployment URL in GoogleDriveConfig.";
      case 500:
      case 502:
      case 503:
        return "The upload service is temporarily unavailable. Please try "
            "again.";
      default:
        return "The upload service returned an unexpected error "
            "(HTTP $statusCode).";
    }
  }

  static String _getMimeType(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith(".png")) return "image/png";
    if (lower.endsWith(".jpg")) return "image/jpeg";
    if (lower.endsWith(".jpeg")) return "image/jpeg";
    if (lower.endsWith(".heic")) return "image/heic";
    if (lower.endsWith(".webp")) return "image/webp";

    return "image/jpeg";
  }
}
