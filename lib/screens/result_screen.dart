import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/assessment_result.dart';
import '../models/overall_result.dart';
import '../screens/checkin/checkin_screen.dart';
import '../services/auth_service.dart';
import 'staff/staff_dashboard_screen.dart';

class ResultScreen extends StatelessWidget {
  final AssessmentResult result;

  const ResultScreen({super.key, required this.result});

  Color get resultColor {
    switch (OverallResult.classify(result.overall)) {
      case OverallResult.excellent:
        return Colors.green;
      case OverallResult.good:
        return Colors.blue;
      case OverallResult.needsWork:
        return Colors.orange;
      case OverallResult.insufficient:
        return Colors.red;
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
                      "Total Score : ${result.totalScore}/60",
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

            // shareLink is never populated by the current Apps Script
            // analyze response -- these actions have nothing to open or
            // share yet, so they're hidden rather than shown as buttons
            // that silently do nothing when tapped.
            if (result.shareLink.isNotEmpty) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.visibility),
                label: const Text("View Report"),
                onPressed: () async {
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
                  Share.share(result.shareLink);
                },
              ),

              const SizedBox(height: 12),
            ],

            ElevatedButton.icon(
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text("Continue to Staff Dashboard"),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                final appUser = await AuthService().getCurrentAppUser();

                if (!context.mounted) return;

                if (appUser == null) {
                  // Reached from the anonymous, no-auth Cabin Crew
                  // self-service check-in flow -- there's no signed-in
                  // Staff session to build a dashboard for.
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Sign in as Staff to view your dashboard."),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => StaffDashboardScreen(user: appUser),
                  ),
                  (route) => false,
                );
              },
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
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
