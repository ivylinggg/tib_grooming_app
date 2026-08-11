import 'package:flutter/material.dart';

import '../models/participant.dart';

class ProfileCard extends StatelessWidget {
  final Participant participant;

  const ProfileCard({super.key, required this.participant});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = participant.photoUrl.isNotEmpty;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Profile Found",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF162B56),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundImage: hasPhoto
                      ? NetworkImage(participant.photoUrl)
                      : null,
                  child: hasPhoto ? null : const Icon(Icons.person, size: 35),
                ),

                const SizedBox(width: 18),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant.fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text("Trainer: ${participant.trainerName}"),

                      const SizedBox(height: 4),

                      Text("Registered: ${participant.registrationDate}"),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F3D73),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    participant.staffId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
}
