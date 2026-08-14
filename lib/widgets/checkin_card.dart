import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/assessment_api.dart';
import '../models/captured_image.dart';
import '../models/participant.dart';
import '../screens/result_screen.dart';
import '../services/assessment_service.dart';
import '../services/firebase_service.dart';
import '../services/image_service.dart';
import 'appearance_card.dart';
import 'mirrored_web_camera_preview.dart';
import 'native_mirrored_camera_screen.dart';
import 'primary_button.dart';
import 'profile_card.dart';

class CheckInCard extends StatefulWidget {
  const CheckInCard({super.key});

  @override
  State<CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends State<CheckInCard> {
  final TextEditingController staffIdController = TextEditingController();

  final ImageService imageService = ImageService();
  final AssessmentApi assessmentApi = AssessmentApi();

  Participant? participant;

  bool isLoading = false;

  /// True only once [_setAndValidatePhoto] has confirmed
  /// [AssessmentApi.detectPerson] accepted this exact file as a
  /// full-body photo. [todayPhoto] is never set without this also being
  /// set alongside it -- see [_setAndValidatePhoto] -- but "Analyse My
  /// Appearance" still re-checks server-side right before calling
  /// [AssessmentApi.analyze] rather than trusting this flag alone: the
  /// real enforcement point is the actual assessment entry point, not
  /// just this screen's own state.
  CapturedImage? todayPhoto;

  bool validatingPhoto = false;

  /// Web-only: true once "Take Photo" has been tapped and the mirrored
  /// live preview should be showing instead of the empty-state
  /// placeholder. See AppearanceCard's class doc comment.
  bool showLivePreview = false;

  /// Web-only: lets [_takePhoto] reach into the live preview to trigger
  /// a capture on the second tap.
  final GlobalKey<MirroredWebCameraPreviewState> _previewKey =
      GlobalKey<MirroredWebCameraPreviewState>();

  @override
  void dispose() {
    staffIdController.dispose();
    super.dispose();
  }

  Future<void> _findProfile() async {
    final staffId = staffIdController.text.trim();

    if (staffId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter Staff ID"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
      participant = null;
    });

    final result = await FirebaseService().getParticipant(staffId);

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Participant not found"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      participant = Participant.fromJson(result);
    });
  }

  /// On native platforms, opens the in-app, horizontally-mirrored camera
  /// screen ([pushNativeMirroredCamera]) first -- the same real CAMERA
  /// permission request as before still gates it. If that screen can't
  /// start for any reason (no camera hardware, init failure/timeout --
  /// [NativeCameraStatus.unavailable]), this falls back to
  /// [ImageService.pickFromCamera] (the plain native camera-intent path
  /// this app already relied on before the mirrored screen existed), so
  /// there is always a working way to take the photo even if the mirror
  /// preview itself can't start on a given device.
  ///
  /// On Flutter Web, this button drives a two-step flow instead -- there
  /// is no native camera app for the browser to hand off to the way
  /// there is on Android/iOS, and `image_picker`'s own web camera source
  /// can't be rendered inside Flutter or mirrored (see AppearanceCard's
  /// class doc comment). First tap reveals the mirrored live preview
  /// ([MirroredWebCameraPreview]) in place of the empty-state
  /// placeholder; the same button (now labelled "Capture") grabs a frame
  /// from it on the second tap, which flows into [_setAndValidatePhoto]
  /// exactly like a native camera pick does.
  Future<void> _takePhoto() async {
    if (kIsWeb) {
      if (!showLivePreview) {
        setState(() {
          showLivePreview = true;
          todayPhoto = null;
        });
        return;
      }

      await _previewKey.currentState?.capture();
      return;
    }

    final status = await Permission.camera.request();

    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Camera permission is required to take today's photo. "
            "Please enable it in Settings.",
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Camera permission is required to take today's photo."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    final nativeResult = await pushNativeMirroredCamera(context);

    switch (nativeResult.status) {
      case NativeCameraStatus.success:
        await _setAndValidatePhoto(nativeResult.image!);
        return;
      case NativeCameraStatus.cancelled:
        // User closed the in-app camera screen on purpose -- nothing to
        // report, same as backing out of the native camera app.
        return;
      case NativeCameraStatus.unavailable:
        // Fall through to the plain native camera-intent path below.
        break;
    }

    final result = await imageService.pickFromCamera();

    if (!mounted) return;

    switch (result.status) {
      case CameraPickStatus.success:
        await _setAndValidatePhoto(result.image!);
        break;

      case CameraPickStatus.cancelled:
        // User opened the camera and backed out -- nothing to report.
        break;

      case CameraPickStatus.denied:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Camera permission is required to take today's photo.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        break;

      case CameraPickStatus.permanentlyDenied:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Camera permission is required to take today's photo. "
              "Please enable it in Settings.",
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
  /// no camera found, browser unsupported, etc.) -- same SnackBar-based
  /// error UX every other capture failure in this app already uses.
  void _onWebPreviewError(String message) {
    if (!mounted) return;

    setState(() {
      showLivePreview = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// The one place [todayPhoto] is ever set from. Camera-only, by strict
  /// company requirement -- see AppearanceCard's class doc comment for
  /// why there is deliberately no Gallery/Files entry point here.
  ///
  /// Uses the same server-side check the app already relies on for
  /// this exact purpose ([AssessmentApi.detectPerson] ->
  /// apps_script/Claude.gs's detectPersonImage, which checks far more
  /// than "a person exists": one person, standing, front-facing, arms
  /// and legs visible, no body part cropped, entire body fits in the
  /// frame) -- never a new/duplicate detector.
  ///
  /// [todayPhoto] is only ever updated on a real accept; a rejected
  /// photo leaves whatever was there before untouched (null on a first
  /// attempt), so AppearanceCard naturally falls back to its "Tap to
  /// Take Photo" empty state -- retaking is just tapping Take Photo
  /// again.
  Future<void> _setAndValidatePhoto(CapturedImage image) async {
    setState(() {
      validatingPhoto = true;
    });

    bool isFullBody;
    try {
      isFullBody = await assessmentApi.detectPerson(image: image);
    } catch (e) {
      debugPrint("CheckInCard._setAndValidatePhoto: $e");
      isFullBody = false;
    }

    if (!mounted) return;

    setState(() {
      validatingPhoto = false;
      if (isFullBody) {
        todayPhoto = image;
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

  @override
  Widget build(BuildContext context) {
    final today =
        "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Participant Check-In",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF162B56),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: staffIdController,
                  decoration: InputDecoration(
                    labelText: "Staff ID",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: TextField(
                  readOnly: true,
                  controller: TextEditingController(text: today),
                  decoration: InputDecoration(
                    labelText: "Today's Date",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _findProfile,
              icon: const Icon(Icons.search),
              label: const Text(
                "Find My Profile",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F3D73),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),

          if (participant != null) ...[
            ProfileCard(participant: participant!),

            const SizedBox(height: 20),

            AppearanceCard(
              todayPhoto: todayPhoto,
              isValidating: validatingPhoto,
              onTakePhoto: _takePhoto,
              showLivePreview: showLivePreview,
              previewKey: _previewKey,
              onWebCapture: _onWebCapture,
              onWebPreviewError: _onWebPreviewError,
            ),

            const SizedBox(height: 20),

            PrimaryButton(
              text: isLoading ? "Please wait..." : "Analyse My Appearance",
              icon: Icons.auto_awesome,
              // Guarded by isLoading: without this, a fast double-tap
              // (or a laggy device where the first tap doesn't visibly
              // respond right away) fires this whole async callback
              // twice concurrently, and since FirebaseService
              // .saveAssessment() always writes a brand-new document via
              // .collection("assessments").add(...) with no idempotency
              // key, two concurrent calls produce two separate Firestore
              // assessment documents for what the Staff member only ever
              // did once -- this was the confirmed root cause of
              // Assessment Management showing duplicate-looking records
              // for a single real submission.
              onPressed: isLoading
                  ? null
                  : () async {
                      if (participant == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please find participant first"),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (todayPhoto == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please take today's photo"),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (participant!.photoUrl.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Reference photo not found"),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() {
                        isLoading = true;
                      });

                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);

                      // Defense-in-depth: [todayPhoto] should already be a
                      // confirmed full-body photo (see
                      // _setAndValidatePhoto's doc comment), but the actual
                      // assessment entry point re-checks it independently
                      // here rather than trusting that invariant alone --
                      // nothing downstream of this point (analyze/save) may
                      // ever run against an unvalidated photo.
                      bool isFullBody;
                      try {
                        isFullBody = await assessmentApi.detectPerson(
                          image: todayPhoto!,
                        );
                      } catch (e) {
                        debugPrint(
                          "CheckInCard: re-validation before analyze failed - $e",
                        );
                        isFullBody = false;
                      }

                      if (!mounted) return;

                      if (!isFullBody) {
                        setState(() {
                          isLoading = false;
                          todayPhoto = null;
                        });

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(kFullBodyPhotoErrorMessage),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final result = await AssessmentApi().analyze(
                        referencePhotoUrl: participant!.photoUrl,
                        todayPhoto: todayPhoto!,
                      );

                      if (!mounted) return;

                      setState(() {
                        isLoading = false;
                      });

                      if (result == null) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Analysis failed"),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (!mounted) return;

                      final assessmentService = AssessmentService();

                      // Apps Script's analyze response carries no participant
                      // context -- ResultScreen displays it, so attach what's
                      // already known locally instead of showing "-" for every
                      // field. Also uploads today's photo so saveAssessment()
                      // doesn't persist an empty todayPhotoUrl.
                      final resultWithParticipant = await assessmentService
                          .prepareAssessment(
                            result: result,
                            referencePhotoUrl: participant!.photoUrl,
                            todayPhoto: todayPhoto!,
                            participantId: participant!.staffId,
                            staffId: participant!.staffId,
                            participantName: participant!.fullName,
                            trainerName: participant!.trainerName,
                            assessmentDate: today,
                          );

                      if (!mounted) return;

                      if (resultWithParticipant == null) {
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

                      // Same persistence path AssessmentScreen uses -- both
                      // entry points save through AssessmentService instead of
                      // duplicating the FirebaseService.saveAssessment() call
                      // shape at each call site.
                      final saved = await assessmentService.saveAssessment(
                        participantId: participant!.staffId,
                        participantName: participant!.fullName,
                        result: resultWithParticipant,
                      );

                      if (!mounted) return;

                      if (!saved) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Failed to save assessment."),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ResultScreen(result: resultWithParticipant),
                        ),
                      );
                    },
            ),
          ],
        ],
      ),
    );
  }
}
