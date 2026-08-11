import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../api/google_drive_api.dart';
import '../../models/register_result.dart';
import '../../services/firebase_service.dart';
import '../../services/image_service.dart';
import '../../services/photo_validation_service.dart';
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
  final PhotoValidationService photoValidationService =
      PhotoValidationService();

  File? selectedImage;
  bool isLoading = false;

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
    photoValidationService.dispose();
    super.dispose();
  }

  Future<void> takePhoto() async {
    final result = await imageService.pickFromCamera();

    if (!mounted) return;

    switch (result.status) {
      case CameraPickStatus.success:
        setState(() {
          selectedImage = result.file;
        });
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

    final File? image;

    switch (source) {
      case _PhotoSource.gallery:
        image = await imageService.pickFromGallery();
        break;
      case _PhotoSource.files:
        image = await imageService.pickFromFiles();
        break;
    }

    if (image != null && mounted) {
      setState(() {
        selectedImage = image;
      });
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

    // Reject the reference photo before it's ever uploaded or written
    // to Firestore if ML Kit can't find a face in it.
    final hasFace = await photoValidationService.hasDetectableFace(
      selectedImage!,
    );

    if (!mounted) return;

    if (!hasFace) {
      setState(() {
        isLoading = false;
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "No face detected in the reference photo. Please retake it.",
          ),
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
