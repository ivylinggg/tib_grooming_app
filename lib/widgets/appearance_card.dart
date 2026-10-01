import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/captured_image.dart';
import 'captured_image_view.dart';
import 'mirrored_web_camera_preview.dart';

class AppearanceCard extends StatelessWidget {
  final CapturedImage? todayPhoto;
  final bool isValidating;
  final VoidCallback onTakePhoto;
  final bool showLivePreview;
  final GlobalKey<MirroredWebCameraPreviewState>? previewKey;
  final ValueChanged<CapturedImage>? onWebCapture;
  final ValueChanged<String>? onWebPreviewError;

  const AppearanceCard({
    super.key,
    required this.todayPhoto,
    required this.onTakePhoto,
    this.isValidating = false,
    this.showLivePreview = false,
    this.previewKey,
    this.onWebCapture,
    this.onWebPreviewError,
  });

  String get _primaryButtonLabel {
    if (kIsWeb && showLivePreview) return 'Capture';
    return todayPhoto == null ? 'Take Photo' : 'Retake Photo';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.face_retouching_natural_outlined, color: AppTheme.primary)),
            const SizedBox(width: 11),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Today's Appearance", style: TextStyle(color: AppTheme.text, fontSize: 17, fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text('Full-body photo required for assessment', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ])),
          ]),
          const SizedBox(height: 16),
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(color: AppTheme.mutedSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
            clipBehavior: Clip.antiAlias,
            child: isValidating ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 13), Text('Validating photo...', style: TextStyle(color: AppTheme.textMuted))])
                : (kIsWeb && showLivePreview) ? MirroredWebCameraPreview(key: previewKey, onCapture: onWebCapture ?? (_) {}, onError: onWebPreviewError ?? (_) {})
                : todayPhoto == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.camera_alt_outlined, size: 30, color: AppTheme.primary)),
                    const SizedBox(height: 14),
                    const Text('Tap to take today’s photo', style: TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('Stand straight • head to feet visible', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ])
                : CapturedImageView(image: todayPhoto!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: isValidating ? null : onTakePhoto, icon: const Icon(Icons.camera_alt_outlined, size: 19), label: Text(_primaryButtonLabel))),
        ]),
      ),
    );
  }
}