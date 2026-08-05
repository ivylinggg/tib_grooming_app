import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../services/image_service.dart';
import '../../widgets/hero_banner.dart';
import '../../widgets/participant_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/top_navigation.dart';
import '../../widgets/upload_photo_card.dart';

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

  File? selectedImage;
  bool isLoading = false;

  @override
  void dispose() {
    fullNameController.dispose();
    staffIdController.dispose();
    trainerNameController.dispose();
    registrationDateController.dispose();
    super.dispose();
  }

  Future<void> takePhoto() async {
    final image = await imageService.pickFromCamera();

    if (image != null && mounted) {
      setState(() {
        selectedImage = image;
      });
    }
  }

  Future<void> pickGallery() async {
    final image = await imageService.pickFromGallery();

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

    try {
      final success = await firebaseService.registerParticipant(
        staff: staffIdController.text.trim(),
        name: fullNameController.text.trim(),
        trainer: trainerNameController.text.trim(),
        date: registrationDateController.text.trim(),
        referencePhoto: selectedImage!,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Participant registered successfully."),
            backgroundColor: Colors.green,
          ),
        );

        fullNameController.clear();
        staffIdController.clear();
        trainerNameController.clear();
        registrationDateController.clear();

        setState(() {
          selectedImage = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Staff ID already exists."),
            backgroundColor: Colors.orange,
          ),
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
