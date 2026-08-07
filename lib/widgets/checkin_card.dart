import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/assessment_api.dart';
import '../models/participant.dart';
import '../screens/result_screen.dart';
import '../services/firebase_service.dart';
import 'appearance_card.dart';
import 'primary_button.dart';
import 'profile_card.dart';

class CheckInCard extends StatefulWidget {
  const CheckInCard({super.key});

  @override
  State<CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends State<CheckInCard> {
  final TextEditingController staffIdController = TextEditingController();

  Participant? participant;

  bool isLoading = false;

  File? todayPhoto;

  final ImagePicker picker = ImagePicker();

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

  Future<void> _takePhoto() async {
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    setState(() {
      todayPhoto = File(image.path);
    });
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

            AppearanceCard(todayPhoto: todayPhoto, onTakePhoto: _takePhoto),

            const SizedBox(height: 20),

            PrimaryButton(
              text: "Analyse My Appearance",
              icon: Icons.auto_awesome,
              onPressed: () async {
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

                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => ResultScreen(result: result),
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
