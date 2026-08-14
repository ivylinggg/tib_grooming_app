import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../api/assessment_api.dart';
import '../../api/google_drive_api.dart';
import '../../models/captured_image.dart';
import '../../models/register_result.dart';
import '../../services/firebase_service.dart';
import '../../services/image_service.dart';
import '../../widgets/hero_banner.dart';
import '../../widgets/participant_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/top_navigation.dart';
import '../../widgets/upload_photo_card.dart';
import '../auth/login_screen.dart';

/// Display text for each [RegisterResult]. Kept here, not in
/// FirebaseService, so the service layer stays free of UI copy.
///
/// `uploadFailed` is the one case that isn't a fixed string: its
/// `exception` is a [DriveUploadException] carrying the actual reason
/// (a specific HTTP status, the real Apps Script error, a malformed
/// response, etc. -- see GoogleDriveApi.uploadImage) rather than a
/// single generic "check your connection" message for every possible
/// failure.
String _messageFor(RegisterResult result) {
  switch (result.error) {
    case RegisterErrorType.none:
      return "Participant registered successfully.";
    case RegisterErrorType.duplicateStaffId:
      return "Staff ID already exists.";
    case RegisterErrorType.firestoreReadFailed:
      return "Could not check Staff ID. Please check your connection and try again.";
    case RegisterErrorType.uploadFailed:
      final exception = result.exception;
      if (exception is DriveUploadException) {
        return "Reference photo upload failed: ${exception.message}";
      }
      return "Reference photo upload failed. Please check your connection and try again.";
    case RegisterErrorType.firestoreWriteFailed:
      return "Registration could not be saved. Please check your connection and try again.";
  }
}

/// Register Participant -- Reference Photo.
///
/// STRICT COMPANY REQUIREMENT: the Reference Photo must be a FULL-BODY
/// photo (head to feet), exactly like every other appearance photo in
/// this app. Both Take Photo AND Gallery/Files are real entry points
/// into the same photo -- both are validated the same way, by the same
/// authoritative validator every other capture path in this app already
/// uses: [AssessmentApi.detectPerson] (Apps Script/Claude.gs's
/// detectPersonImage -- one person, standing, front-facing, full body,
/// head to shoes, no cropping). There is no second, conflicting
/// validation system here -- this used to be gated by
/// PhotoValidationService's on-device ML Kit face-only check instead,
/// which never enforced full-body framing at all; that gate has been
/// replaced, not layered on top of, for this exact reason.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController staffIdController = TextEditingController();
  final TextEditingController trainerNameController = TextEditingController();
  final TextEditingController registrationDateController =
      TextEditingController();

  final ImageService imageService = ImageService();
  final FirebaseService firebaseService = FirebaseService();
  final AssessmentApi assessmentApi = AssessmentApi();

  /// True only once [_setAndValidatePhoto] has confirmed
  /// [AssessmentApi.detectPerson] accepted this exact image as a
  /// full-body photo -- but [registerParticipant] still re-checks
  /// server-side right before the actual upload/Firestore write, rather
  /// than trusting this flag alone. Never set directly from
  /// [takePhoto]/[pickGallery]; see [_setAndValidatePhoto].
  CapturedImage? selectedImage;

  bool isLoading = false;

  /// True while a just-picked photo is being checked by
  /// [AssessmentApi.detectPerson] -- covers the brief window between "a
  /// photo was picked" and "the full-body check finished".
  bool validatingPhoto = false;

  @override
  void initState() {
    super.initState();

    // Admin route protection: RegisterScreen is reachable both from the
    // admin Dashboard and from TopNavigation's "TRAINER ADMIN" tab
    // (which CheckInScreen -- a no-auth-required screen -- also uses),
    // so it needs its own guard rather than relying only on Dashboard's.
    if (FirebaseAuth.instance.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    staffIdController.dispose();
    trainerNameController.dispose();
    registrationDateController.dispose();
    super.dispose();
  }

  Future<void> takePhoto() async {
    final status = await Permission.camera.request();

    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Camera permission is required to take a photo. "
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
          content: Text("Camera permission is required to take a photo."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

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
            content: Text("Camera permission is required to take a photo."),
            backgroundColor: Colors.red,
          ),
        );
        break;

      case CameraPickStatus.permanentlyDenied:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Camera permission is required to take a photo. "
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

  /// The "From Gallery/Files" button's actual entry point: shows an
  /// explicit choice between the two real, distinct Android pickers --
  /// tapping the button no longer silently picks one for the user.
  Future<void> pickGallery() async {
    final source = await showModalBottomSheet<_PhotoSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => const _PhotoSourceSheet(),
    );

    if (source == null || !mounted) return;

    final CapturedImage? image;

    switch (source) {
      case _PhotoSource.gallery:
        image = await imageService.pickFromGallery();
        break;
      case _PhotoSource.files:
        image = await imageService.pickFromFiles();
        break;
    }

    if (image == null || !mounted) return;

    await _setAndValidatePhoto(image);
  }

  /// The one place [selectedImage] is ever set from -- whether [image]
  /// came from the camera or Gallery/Files, both funnel through here so
  /// there is exactly one full-body validation path to keep correct,
  /// not two that could drift apart. Reuses
  /// [AssessmentApi.detectPerson] -- the app's existing, already-strict
  /// server-side full-body check (see the class doc comment); never a
  /// new/duplicate detector. Fails closed: any exception, timeout, or
  /// non-success response is treated as rejection, never as an
  /// accepted photo.
  ///
  /// [selectedImage] is only ever updated on a real accept; a rejected
  /// photo leaves whatever was there before untouched (null on a first
  /// attempt), so UploadPhotoCard naturally falls back to its "Upload
  /// Reference Photo" empty state -- retrying is just tapping Take Photo
  /// or Gallery/Files again.
  Future<void> _setAndValidatePhoto(CapturedImage image) async {
    setState(() {
      validatingPhoto = true;
    });

    bool isFullBody;
    try {
      isFullBody = await assessmentApi.detectPerson(image: image);
    } catch (e) {
      debugPrint("RegisterScreen._setAndValidatePhoto: $e");
      isFullBody = false;
    }

    if (!mounted) return;

    setState(() {
      validatingPhoto = false;
      if (isFullBody) {
        selectedImage = image;
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

  void removePhoto() {
    setState(() {
      selectedImage = null;
    });
  }

  Future<void> registerParticipant() async {
    FocusScope.of(context).unfocus();

    if (fullNameController.text.trim().isEmpty ||
        staffIdController.text.trim().isEmpty ||
        trainerNameController.text.trim().isEmpty ||
        registrationDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please complete all information."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please upload a reference photo."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final messenger = ScaffoldMessenger.of(context);

    // Defense-in-depth: [selectedImage] should already be a confirmed
    // full-body photo (see _setAndValidatePhoto's doc comment), but the
    // actual registration entry point re-checks it independently here
    // rather than trusting that invariant alone -- nothing downstream of
    // this point (Google Drive upload, Firestore participant write) may
    // ever run against an unvalidated photo. Fails closed, same as
    // _setAndValidatePhoto.
    bool isFullBody;
    try {
      isFullBody = await assessmentApi.detectPerson(image: selectedImage!);
    } catch (e) {
      debugPrint("RegisterScreen: re-validation before register failed - $e");
      isFullBody = false;
    }

    if (!mounted) return;

    if (!isFullBody) {
      setState(() {
        isLoading = false;
        selectedImage = null;
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text(kFullBodyPhotoErrorMessage),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final result = await firebaseService.registerParticipant(
        staff: staffIdController.text.trim(),
        name: fullNameController.text.trim(),
        trainer: trainerNameController.text.trim(),
        date: registrationDateController.text.trim(),
        referencePhoto: selectedImage!,
      );

      if (!mounted) return;

      final message = _messageFor(result);

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );

        fullNameController.clear();
        staffIdController.clear();
        trainerNameController.clear();
        registrationDateController.clear();

        setState(() {
          selectedImage = null;
        });
      } else {
        final color = result.error == RegisterErrorType.duplicateStaffId
            ? Colors.orange
            : Colors.red;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: color),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Registration failed.\n$e"),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            children: [
              const TopNavigation(isRegister: true),

              const HeroBanner(
                badge: "TRAINER PORTAL",
                title: "Register Reference",
                highlight: "Appearance",
                description:
                    "Register a participant and upload a reference appearance photo for future AI grooming assessment.",
              ),

              ParticipantCard(
                fullNameController: fullNameController,
                staffIdController: staffIdController,
                trainerNameController: trainerNameController,
                registrationDateController: registrationDateController,
              ),

              UploadPhotoCard(
                image: selectedImage,
                isValidating: validatingPhoto,
                onTakePhoto: takePhoto,
                onPickGallery: pickGallery,
                onRemovePhoto: removePhoto,
              ),

              const SizedBox(height: 24),

              PrimaryButton(
                text: isLoading ? "Registering..." : "Register Participant",
                onPressed: isLoading ? null : registerParticipant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PhotoSource { gallery, files }

/// "Select Photo Source" bottom sheet -- the explicit choice between
/// Gallery/Photos and Files that RegisterScreen.pickGallery shows
/// before opening either real Android picker.
class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "Select Photo Source",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),

            const Divider(height: 1),

            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text("Gallery / Photos"),
              onTap: () => Navigator.of(context).pop(_PhotoSource.gallery),
            ),

            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text("Files"),
              onTap: () => Navigator.of(context).pop(_PhotoSource.files),
            ),

            const Divider(height: 1),

            ListTile(
              title: const Text(
                "Cancel",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
