import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../api/assessment_api.dart';
import '../../models/assessment_result.dart';
import '../../services/assessment_service.dart';
import '../../services/firebase_service.dart';

import '../assessment_screen.dart';

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
  CameraController? controller;

  final AssessmentApi assessmentApi = AssessmentApi();
  final AssessmentService assessmentService = AssessmentService();

  final FirebaseService firebaseService = FirebaseService();

  AssessmentResult? result;

  bool analyzing = false;

  File? capturedImage;

  bool isLoading = true;
  bool detecting = false;

  final FaceDetector faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();

    controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller!.initialize();

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> detectFace() async {
    if (controller == null) return;

    if (detecting) return;

    detecting = true;

    final picture = await controller!.takePicture();

    capturedImage = File(picture.path);

    final image = InputImage.fromFile(capturedImage!);

    final faces = await faceDetector.processImage(image);

    if (!mounted) return;

    detecting = false;

    if (faces.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No face detected.")));
      return;
    }

    final face = faces.first;

    bool facingFront = true;

    if (face.headEulerAngleY != null) {
      facingFront = face.headEulerAngleY!.abs() < 15;
    }

    bool eyesOpen = true;

    if (face.leftEyeOpenProbability != null &&
        face.rightEyeOpenProbability != null) {
      eyesOpen =
          face.leftEyeOpenProbability! > 0.5 &&
          face.rightEyeOpenProbability! > 0.5;
    }

    if (!facingFront) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please face the camera.")));
      return;
    }

    if (!eyesOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please keep your eyes open.")),
      );
      return;
    }

    setState(() {
      analyzing = true;
    });

    final participant = await firebaseService.getParticipant(
      widget.participantId,
    );

    if (participant == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Participant not found.")));

      setState(() {
        analyzing = false;
      });

      return;
    }

    final validPhoto = await assessmentApi.detectPerson(image: capturedImage!);

    if (!validPhoto) {
      if (!mounted) return;

      setState(() {
        analyzing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("Please upload a full-body standing photo."),
        ),
      );

      return;
    }

    // participant is a raw Firestore map (dynamic values) -- guard the cast
    // so a missing/malformed photoUrl fails gracefully through analyze()'s
    // own try/catch instead of throwing before it's even called.
    final referencePhotoUrl = (participant["photoUrl"] as String?) ?? "";

    final aiResult = await assessmentApi.analyze(
      referencePhotoUrl: referencePhotoUrl,
      todayPhoto: capturedImage!,
    );

    if (!mounted) return;

    setState(() {
      analyzing = false;
    });

    if (aiResult == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("AI assessment failed.")));

      return;
    }

    if (!mounted) return;

    // Apps Script's analyze response never echoes the reference photo URL
    // back -- attach it here so AssessmentScreen's saveAssessment() call
    // doesn't persist an empty referencePhotoUrl to Firestore. Also
    // uploads today's captured photo so todayPhotoUrl isn't empty either.
    final resultWithPhotos = await assessmentService.prepareAssessment(
      result: aiResult,
      referencePhotoUrl: referencePhotoUrl,
      todayPhoto: capturedImage!,
      participantId: widget.participantId,
    );

    if (!mounted) return;

    if (resultWithPhotos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
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

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AssessmentScreen(
          participantId: widget.participantId,
          participantName: widget.participantName,
          assessmentResult: resultWithPhotos,
        ),
      ),
    );
  } // detectFace() 结束

  @override
  void dispose() {
    controller?.dispose();
    faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Grooming Detection"),
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: CameraPreview(controller!)),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F3D73),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Capture"),
                    onPressed: detecting
                        ? null
                        : () async {
                            await detectFace();
                          },
                  ),
                ),
              ],
            ),
    );
  }
}
