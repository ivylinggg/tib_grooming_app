import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/captured_image.dart';

/// Every way [pushNativeMirroredCamera] can conclude -- same typed-result
/// shape as [CameraPickResult]/[DriveUploadResult] elsewhere in this app,
/// so the caller never has to guess what a bare null meant.
enum NativeCameraStatus {
  /// A photo was captured.
  success,

  /// The user backed out of the in-app camera screen on purpose (the
  /// close button) without capturing anything.
  cancelled,

  /// The in-app camera could not be started at all (no camera hardware,
  /// `availableCameras()`/`CameraController.initialize()` failed or
  /// timed out, or threw). The caller falls back to
  /// [ImageService.pickFromCamera] -- the existing, already-proven
  /// native camera path -- rather than leaving the user stuck; this is
  /// the direct fix for the exact failure mode ("Capture does nothing",
  /// see AIAssessmentScreen's class doc comment) the previous
  /// CameraController-based screen had no fallback for.
  unavailable,
}

class NativeCameraResult {
  final NativeCameraStatus status;
  final CapturedImage? image;

  const NativeCameraResult._(this.status, [this.image]);

  factory NativeCameraResult.success(CapturedImage image) =>
      NativeCameraResult._(NativeCameraStatus.success, image);

  factory NativeCameraResult.cancelled() =>
      const NativeCameraResult._(NativeCameraStatus.cancelled);

  factory NativeCameraResult.unavailable() =>
      const NativeCameraResult._(NativeCameraStatus.unavailable);
}

/// Pushes the in-app, horizontally-mirrored camera screen and returns
/// what happened. Caller is expected to have already confirmed the OS
/// CAMERA runtime permission is granted (same `permission_handler` check
/// [ImageService.pickFromCamera] already does) before calling this --
/// this function does not request permission itself, so both native
/// capture paths share exactly one permission prompt/denied-handling
/// flow instead of two that could drift apart.
Future<NativeCameraResult> pushNativeMirroredCamera(
  BuildContext context,
) async {
  final result = await Navigator.of(context).push<NativeCameraResult>(
    MaterialPageRoute(
      builder: (_) => const _NativeMirroredCameraScreen(),
      fullscreenDialog: true,
    ),
  );

  return result ?? NativeCameraResult.cancelled();
}

/// Live, horizontally-mirrored in-app camera preview for Android/iOS,
/// backed by `package:camera` (already a project dependency -- see
/// pubspec.yaml; no new package added for this).
///
/// Mirroring is applied ONLY to the on-screen [CameraPreview] widget
/// (via a display-only `Transform`), and ONLY when the front/selfie
/// camera is active -- matching how every real camera app already
/// behaves: a front camera preview is conventionally mirrored, a rear
/// camera preview never is. [_capture] always calls
/// `CameraController.takePicture()`, which returns the camera's real,
/// unmirrored sensor frame regardless of any Transform applied to how
/// the preview widget is displayed -- the captured photo is therefore
/// never flipped, on either camera. This is the same
/// mirror-the-display-only-not-the-data principle already used for
/// Flutter Web's live preview (see MirroredWebCameraPreview's class doc
/// comment).
///
/// Every failure path here (no camera hardware, `availableCameras()`
/// throwing, `initialize()` throwing or timing out) pops this screen
/// with [NativeCameraStatus.unavailable] rather than leaving the caller
/// stuck on a blank/frozen screen -- the caller then falls back to
/// [ImageService.pickFromCamera], the existing native camera-intent
/// path this app already relied on before this screen existed.
class _NativeMirroredCameraScreen extends StatefulWidget {
  const _NativeMirroredCameraScreen();

  @override
  State<_NativeMirroredCameraScreen> createState() =>
      _NativeMirroredCameraScreenState();
}

class _NativeMirroredCameraScreenState
    extends State<_NativeMirroredCameraScreen> {
  CameraController? _controller;
  bool _mirror = false;
  bool _capturing = false;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras().timeout(
        const Duration(seconds: 8),
      );

      if (cameras.isEmpty) {
        _failUnavailable();
        return;
      }

      // Prefer the front/selfie camera -- this is what "mirror effect,
      // like a normal front-facing/selfie camera" (the actual
      // requirement) is describing. Falls back to whatever camera IS
      // available (typically the rear one) without mirroring it, rather
      // than refusing to open the camera at all on a device/emulator
      // that only exposes one.
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize().timeout(const Duration(seconds: 10));

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _mirror = camera.lensDirection == CameraLensDirection.front;
      });
    } catch (e) {
      debugPrint("NativeMirroredCameraScreen._init failed: $e");
      _failUnavailable();
    }
  }

  void _failUnavailable() {
    if (!mounted) return;

    setState(() {
      _initFailed = true;
    });

    // Give the (empty, camera-less) frame a moment to render rather than
    // popping mid-build, then hand back to the caller's fallback path.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(NativeCameraResult.unavailable());
    });
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing || !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _capturing = true;
    });

    try {
      final xfile = await controller.takePicture();

      if (!mounted) return;

      Navigator.of(context).pop(
        NativeCameraResult.success(
          CapturedImage.fromFile(File(xfile.path), name: xfile.name),
        ),
      );
    } catch (e) {
      debugPrint("NativeMirroredCameraScreen._capture failed: $e");

      if (!mounted) return;

      setState(() {
        _capturing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not capture the photo. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: (controller != null && controller.value.isInitialized)
                  ? Center(
                      child: _mirror
                          ? Transform(
                              alignment: Alignment.center,
                              // Horizontal flip -- display only. See the
                              // class doc comment for why takePicture()
                              // below is never affected by this.
                              transform: Matrix4.rotationY(math.pi),
                              child: CameraPreview(controller),
                            )
                          : CameraPreview(controller),
                    )
                  : Center(
                      child: _initFailed
                          ? const SizedBox.shrink()
                          : const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                    ),
            ),

            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () =>
                    Navigator.of(context).pop(NativeCameraResult.cancelled()),
              ),
            ),

            if (controller != null && controller.value.isInitialized)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Center(
                  child: GestureDetector(
                    onTap: _capturing ? null : _capture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.black26, width: 3),
                      ),
                      child: _capturing
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : null,
                    ),
                  ),
                ),
              ),

            const Positioned(
              left: 0,
              right: 0,
              bottom: 110,
              child: Text(
                "Please stand straight and make sure your full body from "
                "head to feet is visible.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
