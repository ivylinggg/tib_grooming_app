import 'package:flutter/material.dart';

class FeedbackCard extends StatelessWidget {
  final String feedback;

  const FeedbackCard({super.key, required this.feedback});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "AI Feedback",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(feedback, style: const TextStyle(height: 1.6)),
          ],
        ),
      ),
    );
  }
}
