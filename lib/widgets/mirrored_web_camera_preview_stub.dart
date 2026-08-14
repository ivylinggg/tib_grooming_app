import 'package:flutter/material.dart';

import '../models/captured_image.dart';
/// Non-web stub. Every real platform (Android/iOS/desktop) still uses
/// `ImageService.pickFromCamera()` for its actual camera capture, and
/// this widget is only ever mounted when `kIsWeb` is true -- so this
/// body is never reached there. It exists purely so
/// `mirrored_web_camera_preview.dart` compiles on every target: the real
/// implementation (`mirrored_web_camera_preview_web.dart`) uses
/// `dart:html`/`dart:ui_web`, which don't exist outside a web build.
class MirroredWebCameraPreview extends StatefulWidget {
  final ValueChanged<CapturedImage> onCapture;
  final ValueChanged<String> onError;

  const MirroredWebCameraPreview({
    super.key,
    required this.onCapture,
    required this.onError,
  });

  @override
  State<MirroredWebCameraPreview> createState() =>
      MirroredWebCameraPreviewState();
}

class MirroredWebCameraPreviewState extends State<MirroredWebCameraPreview> {
  Future<void> capture() async {}

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
