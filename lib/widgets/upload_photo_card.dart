import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/captured_image.dart';
import 'captured_image_view.dart';

class UploadPhotoCard extends StatelessWidget {
  final CapturedImage? image;
  final bool isValidating;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;
  final VoidCallback? onRemovePhoto;

  const UploadPhotoCard({
    super.key,
    required this.image,
    required this.onTakePhoto,
    required this.onPickGallery,
    this.onRemovePhoto,
    this.isValidating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.photo_camera_outlined, color: AppTheme.primary),
              ),
              const SizedBox(width: 11),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Reference Photo', style: TextStyle(color: AppTheme.text, fontSize: 17, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Best appearance • full body', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ])),
              if (image != null) IconButton(tooltip: 'Remove photo', onPressed: onRemovePhoto, icon: const Icon(Icons.delete_outline, color: AppTheme.error)),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 220),
            decoration: BoxDecoration(color: AppTheme.mutedSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
            clipBehavior: Clip.antiAlias,
            child: isValidating ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 46),
              child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 14), Text('Validating photo...', style: TextStyle(color: AppTheme.textMuted))]),
            ) : image == null ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.image_outlined, size: 30, color: AppTheme.primary)),
                const SizedBox(height: 14),
                const Text('Upload reference photo', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.text, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                const Text('Use a clear full-body photo from head to feet.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.45)),
                const SizedBox(height: 14),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)), child: const Text('Professional Batik Air appearance standard', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.primaryDark, fontSize: 10, fontWeight: FontWeight.w600))),
              ]),
            ) : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CapturedImageView(image: image!, width: double.infinity, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: isValidating ? null : onTakePhoto, icon: const Icon(Icons.photo_camera_outlined, size: 18), label: const Text('Take Photo'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: isValidating ? null : onPickGallery, icon: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('Gallery / Files'))),
          ]),
        ],
      ),
    );
  }
}