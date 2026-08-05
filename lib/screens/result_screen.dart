import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/assessment_result.dart';
import '../screens/checkin/checkin_screen.dart';

class ResultScreen extends StatelessWidget {
  final AssessmentResult result;

  const ResultScreen({super.key, required this.result});

  Color get resultColor {
    switch (result.overall.toUpperCase()) {
      case 'PASS':
        return Colors.green;
      case 'FAIL':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Assessment Result"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.verified, color: Colors.green, size: 80),

            const SizedBox(height: 20),

            const Text(
              "Assessment Completed",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 30),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow("Staff ID", result.staffId ?? "-"),
                    const Divider(),

                    _infoRow("Participant", result.participantName ?? "-"),
                    const Divider(),

                    _infoRow("Trainer", result.trainerName ?? "-"),
                    const Divider(),

                    _infoRow("Assessment Date", result.assessmentDate ?? "-"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              color: resultColor.withValues(alpha: 0.08),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(
                      result.overall,
                      style: TextStyle(
                        color: resultColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 30,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Total Score : ${result.totalScore}",
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "AI Summary",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(result.summary),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "Assessment Criteria",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),

            const SizedBox(height: 12),

            ...result.criteria.map(
              (c) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(c.score.toString())),
                  title: Text(c.label),
                  subtitle: Text(c.tip),
                ),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              icon: const Icon(Icons.visibility),
              label: const Text("View Report"),
              onPressed: () async {
                if (result.shareLink.isEmpty) return;

                await launchUrl(
                  Uri.parse(result.shareLink),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text("Share Report"),
              onPressed: () {
                if (result.shareLink.isEmpty) return;

                Share.share(result.shareLink);
              },
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("New Check-in"),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckInScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    );
  }
}
