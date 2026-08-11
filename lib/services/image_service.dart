import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Every way a camera capture attempt can conclude. Kept as a typed
/// result (same pattern as RegisterResult) rather than a nullable File,
/// because the caller needs to react very differently to "user denied
/// permission" (show a message, offer retry) vs. "permanently denied"
/// (offer to open Android's App Settings) vs. "user just cancelled the
/// camera" (do nothing).
enum CameraPickStatus { success, cancelled, denied, permanentlyDenied }

class CameraPickResult {
  final CameraPickStatus status;
  final File? file;

  const CameraPickResult._(this.status, [this.file]);

  factory CameraPickResult.success(File file) =>
      CameraPickResult._(CameraPickStatus.success, file);

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

      return CameraPickResult.success(File(image.path));
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
  Future<File?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
      );

      if (image == null) return null;

      return File(image.path);
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
  Future<File?> pickFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      final path = result?.files.single.path;
      if (path == null) return null;

      return File(path);
    } catch (e) {
      debugPrint("Files Error: $e");
      return null;
    }
  }
}
