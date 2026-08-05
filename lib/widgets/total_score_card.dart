import 'package:flutter/material.dart';

class TotalScoreCard extends StatelessWidget {
  final int score;
  final int maxScore;

  const TotalScoreCard({
    super.key,
    required this.score,
    required this.maxScore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1F3D73),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Total Score",
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              "$score / $maxScore",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
