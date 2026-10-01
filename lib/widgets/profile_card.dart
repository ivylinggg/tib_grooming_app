import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/participant.dart';

class ProfileCard extends StatelessWidget {
  final Participant participant;
  const ProfileCard({super.key, required this.participant});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = participant.photoUrl.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.person_outline, color: AppTheme.primary),
                ),
                const SizedBox(width: 11),
                const Expanded(child: Text('Profile Found', style: TextStyle(color: AppTheme.text, fontSize: 17, fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20)),
                  child: Text(participant.staffId, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.mutedSurface,
                  backgroundImage: hasPhoto ? NetworkImage(participant.photoUrl) : null,
                  child: hasPhoto ? null : const Icon(Icons.person, size: 30, color: AppTheme.primary),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(participant.fullName, style: const TextStyle(color: AppTheme.text, fontSize: 19, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 7),
                      Text('Trainer: ${participant.trainerName}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Registered: ${participant.registrationDate}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
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