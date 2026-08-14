import 'dart:io';
import 'dart:typed_data';

/// Cross-platform handle for a picked/captured image.
///
/// `dart:io`'s `File` compiles on Flutter Web (the SDK ships a stub so
/// packages that unconditionally `import 'dart:io'` don't break web
/// builds), but every real I/O method on it -- including
/// `readAsBytes()`/`readAsBytesSync()` -- throws `UnsupportedError` at
/// runtime on web, regardless of what `path` it wraps (even a `blob:`
/// URL from `image_picker`'s web `XFile`). This wrapper is the one place
/// that works around that: it carries a real `dart:io File` on native
/// platforms (Android/iOS/desktop) exactly as before, and raw bytes read
/// once at pick/capture time on web -- every downstream consumer
/// ([AssessmentApi], [GoogleDriveApi]) reads through [readAsBytes]
/// instead of ever touching `dart:io File` directly, so there is exactly
/// one place that knows about this platform split.
///
/// [file] is still exposed (non-null only on native) for the couple of
/// existing native-only widgets/APIs that require a real `File` and have
/// no web equivalent at all (`Image.file`, ML Kit's
/// `InputImage.fromFile` in [PhotoValidationService]) -- callers on a
/// web-reachable path must never assume [file] is set.
class CapturedImage {
  final File? file;
  final Uint8List? webBytes;

  /// Original file name (or a synthetic one for a live webcam capture) --
  /// used for MIME-type sniffing the same way a `File`'s path used to be.
  final String name;

  const CapturedImage._({this.file, this.webBytes, required this.name});

  factory CapturedImage.fromFile(File file, {required String name}) =>
      CapturedImage._(file: file, name: name);

  factory CapturedImage.fromBytes(Uint8List bytes, {required String name}) =>
      CapturedImage._(webBytes: bytes, name: name);

  /// The only way any caller should ever read this image's bytes --
  /// works identically on native (reads [file]) and web (returns the
  /// bytes already captured at pick/capture time).
  Future<Uint8List> readAsBytes() async {
    final bytes = webBytes;
    if (bytes != null) return bytes;
    return file!.readAsBytes();
  }
}
