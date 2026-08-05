import 'package:flutter/material.dart';

class ScoreCard extends StatelessWidget {
  final String title;
  final int score;

  const ScoreCard({super.key, required this.title, required this.score});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1F3D73),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$score / 10",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
