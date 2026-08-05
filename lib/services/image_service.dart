import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class ImageService {
  ImageService();

  final ImagePicker _picker = ImagePicker();

  /// Take photo using camera
  Future<File?> pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1080,
      );

      if (image == null) return null;

      return File(image.path);
    } catch (e) {
      debugPrint("Camera Error: $e");
      return null;
    }
  }

  /// Pick photo from gallery
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
}
