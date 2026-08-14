import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/captured_image.dart';
import 'captured_image_view.dart';
import 'mirrored_web_camera_preview.dart';

/// Today's appearance photo, for CheckInCard.
///
/// CAMERA ONLY, deliberately -- this is a strict company requirement:
/// the appearance photo used for today's grooming assessment must be
/// taken on the current device at the time of check-in, not selected
/// from an existing photo (Gallery/Files), which could be an old photo,
/// a photo of someone else, or an edited/filtered image. There is no
/// Gallery/Files entry point anywhere on this card -- [onTakePhoto] is
/// the only way [todayPhoto] can ever be set. (Contrast with
/// RegisterScreen's Reference Photo, a separate screen/purpose that
/// intentionally still offers both Take Photo and Gallery/Files.)
///
/// [todayPhoto] is only ever non-null here once [onTakePhoto]'s result
/// has already passed full-body validation in the caller ([CheckInCard]
/// -- see its `_setAndValidatePhoto`). [isValidating] covers the brief
/// window between "a photo was captured" and "the full-body check
/// finished".
///
/// On Flutter Web, tapping Take Photo doesn't open a native camera app
/// the way it does on Android/iOS -- there isn't one for a browser to
/// hand off to in the same way, and `image_picker`'s web camera source
/// only opens the browser/OS's own capture UI, which Flutter can't
/// render inside itself or mirror (see ImageService.pickFromCamera's
/// doc comment). Instead, [showLivePreview] switches this card's photo
/// slot to a live, horizontally-mirrored in-app preview
/// ([MirroredWebCameraPreview]) so the participant can position
/// themselves like they would in a real mirror; the same button then
/// captures a frame from it. [previewKey] is how CheckInCard reaches
/// into that preview to trigger the capture.
class AppearanceCard extends StatelessWidget {
  final CapturedImage? todayPhoto;
  final bool isValidating;
  final VoidCallback onTakePhoto;

  /// Web-only: true once Take Photo has been tapped and the mirrored
  /// live preview should be showing in place of the empty-state
  /// placeholder. Always false/unused on native platforms.
  final bool showLivePreview;

  /// Web-only: lets CheckInCard call `.capture()` on the live preview
  /// when the same Take Photo/Capture button is tapped a second time.
  final GlobalKey<MirroredWebCameraPreviewState>? previewKey;

  /// Web-only: called with the frame [MirroredWebCameraPreview] captured.
  final ValueChanged<CapturedImage>? onWebCapture;

  /// Web-only: called if the live preview fails to start (camera denied,
  /// no camera found, etc.).
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
    if (kIsWeb && showLivePreview) return "Capture";
    return todayPhoto == null ? "Take Photo" : "Retake Photo";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Appearance Photo",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF162B56),
              ),
            ),

            const SizedBox(height: 8),

            // A full-body grooming photo is required -- see
            // CheckInCard._setAndValidatePhoto, which rejects anything
            // else server-side before it can ever reach here as
            // [todayPhoto].
            const Text(
              "Please stand straight and make sure your full body from "
              "head to feet is visible.",
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),

            const SizedBox(height: 20),

            GestureDetector(
              onTap: isValidating ? null : onTakePhoto,
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: isValidating
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 15),
                          Text("Validating photo..."),
                        ],
                      )
                    : (kIsWeb && showLivePreview)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: MirroredWebCameraPreview(
                          key: previewKey,
                          onCapture: onWebCapture ?? (_) {},
                          onError: onWebPreviewError ?? (_) {},
                        ),
                      )
                    : todayPhoto == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 50,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 15),
                          Text("Tap to Take Photo"),
                          SizedBox(height: 8),
                          Text(
                            "Please take a clear,\nfull-body photo",
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CapturedImageView(
                          image: todayPhoto!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 15),

            // Stacked, full-width buttons -- not a Row -- matching the
            // rest of the app's established fix for two-button rows
            // overflowing at larger accessibility text sizes (see
            // AssessmentDetailScreen's Export/Download/Share buttons).
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isValidating ? null : onTakePhoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(_primaryButtonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
