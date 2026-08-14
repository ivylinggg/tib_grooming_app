import 'package:flutter/material.dart';

import '../models/captured_image.dart';

/// Displays a [CapturedImage] regardless of whether it's backed by a
/// native `File` ([Image.file]) or web bytes ([Image.memory]) -- the one
/// place that branches on this, so AppearanceCard/AIAssessmentScreen
/// don't each need their own copy of the same two-way check.
class CapturedImageView extends StatelessWidget {
  final CapturedImage image;
  final double? width;
  final double? height;
  final BoxFit fit;

  const CapturedImageView({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final file = image.file;
    if (file != null) {
      return Image.file(file, width: width, height: height, fit: fit);
    }

    return Image.memory(
      image.webBytes!,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
