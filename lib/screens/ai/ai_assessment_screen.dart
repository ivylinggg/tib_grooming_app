import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../api/assessment_api.dart';
import '../../models/captured_image.dart';
import '../../services/assessment_service.dart';
import '../../services/firebase_service.dart';
import '../../services/image_service.dart';
import '../../widgets/captured_image_view.dart';
import '../../widgets/mirrored_web_camera_preview.dart';
import '../../widgets/native_mirrored_camera_screen.dart';

import '../assessment_screen.dart';
/// Admin -> Participant Dashboard -> "Assessment" entry point.
///
/// Root cause of the previous "Capture does nothing" bug: this screen
/// used to drive its own raw `camera` package `CameraController` preview
/// plus a mandatory local ML Kit face/eyes/facing-direction gate before
/// a captured photo could go anywhere -- entirely separate code from
/// every other capture path in the app, with no try/catch anywhere in
/// `takePicture()`/`processImage()`, and no permission handling at all
/// (the `camera` plugin only requests CAMERA permission implicitly,
/// with no retry/Settings path if it was ever denied). A full-body
/// grooming photo very often doesn't have a face large/frontal enough
/// for ML Kit to detect, so `detectFace()` would silently fail its own
/// gate and return -- no image shown, no error, nothing -- which is
/// exactly what was reported as "Capture doesn't work". Worse, on a
/// device/emulator where `CameraController.initialize()` itself threw
/// (denied permission, no camera hardware), that exception was never
/// caught either, so the screen could hang on its loading spinner
/// forever with the Capture button never even appearing.
///
/// The fix reuses [ImageService.pickFromCamera]/[ImageService.
/// pickFromGallery] -- the same real, already-working capture paths
/// (backed by `image_picker` + explicit `permission_handler` runtime
/// request for camera) RegisterScreen's reference-photo capture already
/// uses successfully.
///
/// Full-body validation ([AssessmentApi.detectPerson], the app's real
/// server-side check -- see its own doc comment for why this is
/// genuinely full-body detection, not just "a person exists") now runs
/// immediately once a photo is picked, from either source, before the
/// photo is ever shown as accepted (see [_setAndValidatePhoto]) -- not
/// only later, mid [_analyze]. [_analyze] still re-checks it
/// independently right before calling [AssessmentApi.analyze]: the
/// actual assessment entry point must reject an invalid photo on its
/// own regardless of what any earlier screen state claims, not just
/// rely on how the UI got here.
class AIAssessmentScreen extends StatefulWidget {
  final String participantId;
  final String participantName;

  const AIAssessmentScreen({
    super.key,
    required this.participantId,
    required this.participantName,
  });

  @override
  State<AIAssessmentScreen> createState() => _AIAssessmentScreenState();
}

class _AIAssessmentScreenState extends State<AIAssessmentScreen> {
  final ImageService imageService = ImageService();
  final AssessmentApi assessmentApi = AssessmentApi();
  final AssessmentService assessmentService = AssessmentService();
  final FirebaseService firebaseService = FirebaseService();

  /// Only ever set once [_setAndValidatePhoto] has confirmed
  /// [AssessmentApi.detectPerson] accepted this exact file -- but
  /// [_analyze] still re-validates it again before actually using it;
  /// see the class doc comment.
  CapturedImage? capturedImage;

  bool capturing = false;
  bool validatingPhoto = false;
  bool analyzing = false;

  /// Web-only: true once "Capture" has been tapped and the mirrored
  /// live preview should be showing instead of the empty-state
  /// placeholder -- see AppearanceCard's class doc comment for the full
  /// explanation of why Flutter Web needs a dedicated in-app preview at
  /// all here.
  bool showLivePreview = false;

  /// Web-only: lets [_capture] reach into the live preview to trigger a
  /// capture on the second tap.
  final GlobalKey<MirroredWebCameraPreviewState> _previewKey =
      GlobalKey<MirroredWebCameraPreviewState>();

  /// On native platforms, opens the in-app, horizontally-mirrored camera
  /// screen ([pushNativeMirroredCamera]) first -- gated by the same real
  /// CAMERA permission request as before. If that screen can't start
  /// for any reason ([NativeCameraStatus.unavailable]: no camera
  /// hardware, init failure/timeout), falls back to
  /// [ImageService.pickFromCamera] -- the permission-aware,
  /// try/catch-wrapped path this screen already relied on before the
  /// mirrored screen existed -- so there is always a working capture
  /// path. Every [CameraPickStatus]/[NativeCameraStatus] is handled
  /// explicitly; none of them are ever treated as a silent success.
  ///
  /// On Flutter Web, drives the same two-step mirrored-live-preview flow
  /// as CheckInCard's Take Photo button -- see AppearanceCard's class
  /// doc comment for why.
  Future<void> _capture() async {
    if (kIsWeb) {
      if (!showLivePreview) {
        setState(() {
          showLivePreview = true;
          capturedImage = null;
        });
        return;
      }

      await _previewKey.currentState?.capture();
      return;
    }

    if (capturing) return;

    setState(() {
      capturing = true;
    });

    final status = await Permission.camera.request();

    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      setState(() {
        capturing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Camera permission is required to capture the grooming "
            "photo. Please enable it in Settings.",
          ),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: "Open Settings",
            textColor: Colors.white,
            onPressed: openAppSettings,
          ),
        ),
      );
      return;
    }

    if (!status.isGranted) {
      if (!mounted) return;
      setState(() {
        capturing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Camera permission is required to capture the grooming photo.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    final nativeResult = await pushNativeMirroredCamera(context);

    if (!mounted) return;

    if (nativeResult.status == NativeCameraStatus.success) {
      setState(() {
        capturing = false;
      });
      await _setAndValidatePhoto(nativeResult.image!);
      return;
    }

    if (nativeResult.status == NativeCameraStatus.cancelled) {
      setState(() {
        capturing = false;
      });
      return;
    }

    // NativeCameraStatus.unavailable -- fall through to the plain
    // native camera-intent path below.
    final result = await imageService.pickFromCamera();

    if (!mounted) return;

    setState(() {
      capturing = false;
    });

    switch (result.status) {
      case CameraPickStatus.success:
        await _setAndValidatePhoto(result.image!);
        break;

      case CameraPickStatus.cancelled:
        // User opened the camera and backed out -- nothing to report,
        // same as every other capture entry point in this app.
        break;

      case CameraPickStatus.denied:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Camera permission is required to capture the grooming photo.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        break;

      case CameraPickStatus.permanentlyDenied:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Camera permission is required to capture the grooming "
              "photo. Please enable it in Settings.",
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: "Open Settings",
              textColor: Colors.white,
              onPressed: openAppSettings,
            ),
          ),
        );
        break;
    }
  }

  /// Opens the real Android Gallery/Photos picker via
  /// [ImageService.pickFromGallery] -- the same picker RegisterScreen's
  /// reference-photo upload already uses, so selecting an existing
  /// photo goes through exactly the same full-body validation as a
  /// fresh capture; there is no way to bypass it by picking from
  /// Gallery instead of the camera.
  Future<void> _chooseFromGallery() async {
    final image = await imageService.pickFromGallery();

    if (!mounted) return;

    if (image == null) {
      // User backed out of the gallery picker -- nothing to report.
      return;
    }

    // If the mirrored live preview (web) was showing, picking from
    // Gallery instead supersedes it.
    setState(() {
      showLivePreview = false;
    });

    await _setAndValidatePhoto(image);
  }

  /// Web-only: called by [MirroredWebCameraPreview.onCapture] with the
  /// frame it grabbed -- always the real, unmirrored frame; see that
  /// widget's class doc comment. Funnels into the same
  /// [_setAndValidatePhoto] every other capture/gallery entry point uses.
  Future<void> _onWebCapture(CapturedImage image) async {
    setState(() {
      showLivePreview = false;
    });

    await _setAndValidatePhoto(image);
  }

  /// Web-only: called if the live preview fails to start (camera denied,
  /// no camera found, browser unsupported, etc.).
  void _onWebPreviewError(String message) {
    if (!mounted) return;

    setState(() {
      showLivePreview = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// The one place [capturedImage] is ever set from -- camera and
  /// gallery both funnel through here, so there is exactly one
  /// full-body validation path to keep correct, not two that could
  /// drift apart. Reuses [AssessmentApi.detectPerson] (the app's
  /// existing, already-strict server-side full-body check -- see the
  /// class doc comment); never a new/duplicate detector.
  ///
  /// [capturedImage] is only ever updated on a real accept; a rejected
  /// photo leaves the empty-capture state showing (with both Capture
  /// and Choose from Gallery still offered) rather than showing a
  /// rejected photo with no way forward.
  Future<void> _setAndValidatePhoto(CapturedImage image) async {
    setState(() {
      validatingPhoto = true;
    });

    bool isFullBody;
    try {
      isFullBody = await assessmentApi.detectPerson(image: image);
    } catch (e) {
      debugPrint("AIAssessmentScreen._setAndValidatePhoto: $e");
      isFullBody = false;
    }

    if (!mounted) return;

    setState(() {
      validatingPhoto = false;
      if (isFullBody) {
        capturedImage = image;
      }
    });

    if (!isFullBody) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(kFullBodyPhotoErrorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _retake() {
    setState(() {
      capturedImage = null;
    });
  }

  /// Runs the existing, untouched AI grooming pipeline against the
  /// already-captured, already-shown photo: server-side full-body check
  /// ([AssessmentApi.detectPerson] -- re-checked here independently of
  /// [_setAndValidatePhoto]'s earlier pass; see the class doc comment
  /// for why), then the real AI analysis ([AssessmentApi.analyze]),
  /// then attaches photo URLs ([AssessmentService.prepareAssessment]).
  /// [widget.participantId] is the real Staff ID passed in from
  /// ParticipantManagementScreen's Participant card -- never the
  /// signed-in Admin's Firebase Auth uid, never a generated ID -- and is
  /// threaded through every step unchanged, exactly as CheckInCard
  /// already does for its own entry point.
  Future<void> _analyze() async {
    if (capturedImage == null || analyzing) return;

    setState(() {
      analyzing = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final participant = await firebaseService.getParticipant(
        widget.participantId,
      );

      if (!mounted) return;

      if (participant == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Participant not found."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final validPhoto = await assessmentApi.detectPerson(
        image: capturedImage!,
      );

      if (!mounted) return;

      if (!validPhoto) {
        setState(() {
          capturedImage = null;
        });

        messenger.showSnackBar(
          const SnackBar(
            content: Text(kFullBodyPhotoErrorMessage),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // participant is a raw Firestore map (dynamic values) -- guard the
      // cast so a missing/malformed photoUrl fails gracefully through
      // analyze()'s own try/catch instead of throwing before it's even
      // called.
      final referencePhotoUrl = (participant["photoUrl"] as String?) ?? "";

      final aiResult = await assessmentApi.analyze(
        referencePhotoUrl: referencePhotoUrl,
        todayPhoto: capturedImage!,
      );

      if (!mounted) return;

      if (aiResult == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("AI assessment failed. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Apps Script's analyze response never echoes the reference photo
      // URL back -- attach it here so AssessmentScreen's
      // saveAssessment() call doesn't persist an empty
      // referencePhotoUrl to Firestore. Also uploads today's captured
      // photo so todayPhotoUrl isn't empty either.
      final resultWithPhotos = await assessmentService.prepareAssessment(
        result: aiResult,
        referencePhotoUrl: referencePhotoUrl,
        todayPhoto: capturedImage!,
        participantId: widget.participantId,
      );

      if (!mounted) return;

      if (resultWithPhotos == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              assessmentService.lastUploadError ??
                  "Failed to upload today's photo.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => AssessmentScreen(
            participantId: widget.participantId,
            participantName: widget.participantName,
            assessmentResult: resultWithPhotos,
          ),
        ),
      );
    } catch (e) {
      debugPrint("AIAssessmentScreen._analyze error: $e");

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text("Assessment failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          analyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Grooming Detection"),
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(widget.participantName),
                subtitle: Text("Staff ID : ${widget.participantId}"),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: capturedImage == null
                  ? _buildCaptureEmptyState()
                  : _buildCapturedPreview(),
            ),

            const SizedBox(height: 20),

            if (capturedImage == null) ...[
              // Full-width, stacked buttons -- not a Row -- matching
              // the rest of the app's established fix for two-button
              // rows overflowing at larger accessibility text sizes
              // (see AssessmentDetailScreen's Export/Download/Share
              // buttons).
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F3D73),
                    foregroundColor: Colors.white,
                  ),
                  icon: capturing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(capturing ? "Opening Camera..." : "Capture"),
                  onPressed: (capturing || validatingPhoto) ? null : _capture,
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text("Choose from Gallery"),
                  onPressed: (capturing || validatingPhoto)
                      ? null
                      : _chooseFromGallery,
                ),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retake"),
                        onPressed: analyzing ? null : _retake,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F3D73),
                          foregroundColor: Colors.white,
                        ),
                        icon: analyzing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(analyzing ? "Analyzing..." : "Continue"),
                        onPressed: analyzing ? null : _analyze,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureEmptyState() {
    // Flutter Web: once Capture has been tapped, this slot shows the
    // mirrored live preview instead of the placeholder below -- see
    // AppearanceCard's class doc comment for why Flutter Web needs a
    // dedicated in-app preview at all, and _capture for the two-tap
    // flow that drives [showLivePreview].
    if (kIsWeb && showLivePreview && !validatingPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          color: Colors.grey.shade100,
          child: MirroredWebCameraPreview(
            key: _previewKey,
            onCapture: _onWebCapture,
            onError: _onWebPreviewError,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: validatingPhoto
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      "Validating photo...",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 56,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Please stand straight and make sure your full body "
                      "from head to feet is visible.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCapturedPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CapturedImageView(
        image: capturedImage!,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}
