import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/captured_image.dart';

/// Every way a camera capture attempt can conclude. Kept as a typed
/// result (same pattern as RegisterResult) rather than a nullable File,
/// because the caller needs to react very differently to "user denied
/// permission" (show a message, offer retry) vs. "permanently denied"
/// (offer to open Android's App Settings) vs. "user just cancelled the
/// camera" (do nothing).
enum CameraPickStatus { success, cancelled, denied, permanentlyDenied }

class CameraPickResult {
  final CameraPickStatus status;
  final CapturedImage? image;

  const CameraPickResult._(this.status, [this.image]);

  factory CameraPickResult.success(CapturedImage image) =>
      CameraPickResult._(CameraPickStatus.success, image);

  factory CameraPickResult.cancelled() =>
      const CameraPickResult._(CameraPickStatus.cancelled);

  factory CameraPickResult.denied() =>
      const CameraPickResult._(CameraPickStatus.denied);

  factory CameraPickResult.permanentlyDenied() =>
      const CameraPickResult._(CameraPickStatus.permanentlyDenied);
}

class ImageService {
  ImageService();

  final ImagePicker _picker = ImagePicker();

  /// Requests the real Android CAMERA runtime permission (via
  /// permission_handler, which drives the actual system permission
  /// dialog -- nothing here is a custom/fake dialog), then opens the
  /// real camera through image_picker only once that permission is
  /// granted. Distinguishes a plain denial (caller can ask again) from
  /// "permanently denied" (Android will no longer show the prompt at
  /// all; the caller has to send the user to App Settings).
  ///
  /// On Flutter Web, `image_picker`'s camera source only ever opens the
  /// browser/OS's own native camera UI (Flutter has no control over it,
  /// and can't render an in-app preview through it) -- the actual
  /// mirrored, in-app live preview for web (CheckInCard/
  /// AIAssessmentScreen) is a separate, dedicated widget
  /// (MirroredWebCameraPreview) that bypasses this method entirely. This
  /// method stays the real camera entry point for every native platform
  /// exactly as before, and remains available as the web "Choose from
  /// Gallery"-adjacent fallback path is not affected by that widget.
  Future<CameraPickResult> pickFromCamera() async {
    final status = await Permission.camera.request();

    if (status.isPermanentlyDenied) {
      return CameraPickResult.permanentlyDenied();
    }

    if (!status.isGranted) {
      return CameraPickResult.denied();
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1080,
      );

      if (image == null) return CameraPickResult.cancelled();

      return CameraPickResult.success(await _toCapturedImage(image));
    } catch (e) {
      debugPrint("Camera Error: $e");
      return CameraPickResult.cancelled();
    }
  }

  /// Opens the real Android Gallery/Photos picker -- the same picker
  /// any other app's "choose a photo" button opens. Distinct from
  /// [pickFromFiles]: the caller is expected to let the user pick which
  /// of the two they want first (see RegisterScreen's photo-source
  /// bottom sheet), not funnel both into one combined picker.
  Future<CapturedImage?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
      );

      if (image == null) return null;

      return await _toCapturedImage(image);
    } catch (e) {
      debugPrint("Gallery Error: $e");
      return null;
    }
  }

  /// Opens Android's real system document picker (Storage Access
  /// Framework, i.e. `ACTION_OPEN_DOCUMENT` under the hood), restricted
  /// to image files -- a genuine file/document browser over the
  /// device's filesystem, not another route into the Photos app. This
  /// is what actually answers "Files": `image_picker`'s gallery source
  /// only ever opens Photos, never a document browser, no matter what a
  /// button calling it is labeled. SAF-based picking doesn't require a
  /// runtime storage permission on modern Android -- the system grants
  /// access to only the specific file the user picks.
  ///
  /// `withData: kIsWeb` -- on web there is no filesystem `path` to read
  /// later (`result.files.single.path` is always null there), so the
  /// picked file's bytes have to be requested up front instead.
  Future<CapturedImage?> pickFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: kIsWeb,
      );

      final picked = result?.files.single;
      if (picked == null) return null;

      if (kIsWeb) {
        final bytes = picked.bytes;
        if (bytes == null) return null;
        return CapturedImage.fromBytes(bytes, name: picked.name);
      }

      final path = picked.path;
      if (path == null) return null;

      return CapturedImage.fromFile(File(path), name: picked.name);
    } catch (e) {
      debugPrint("Files Error: $e");
      return null;
    }
  }

  /// The one place an `image_picker` `XFile` is ever turned into a
  /// [CapturedImage] -- native platforms keep the exact `dart:io File`
  /// path this app has always used; web reads the bytes once here
  /// (`XFile.readAsBytes()` works cross-platform, unlike wrapping the
  /// same path in a `dart:io File`, which throws on web -- see
  /// [CapturedImage]'s doc comment).
  Future<CapturedImage> _toCapturedImage(XFile image) async {
    if (kIsWeb) {
      final bytes = await image.readAsBytes();
      return CapturedImage.fromBytes(bytes, name: image.name);
    }

    return CapturedImage.fromFile(File(image.path), name: image.name);
  }
}
