import 'package:flutter/material.dart';

class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        Row(
          children: [
            const Text(
              "PREVIOUS CHECK-INS",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
          ],
        ),

        const SizedBox(height: 15),

        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F7F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "2026-07-27",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F3D73),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8A3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Fail",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7A4A00),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              const Text(
                "This photo shows a complete departure from airline cabin crew grooming standards. "
                "The individual is wearing an incorrect uniform and lacks proper grooming.",
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
