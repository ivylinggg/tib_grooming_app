import 'package:flutter/material.dart';

class PhotoComparisonCard extends StatelessWidget {
  const PhotoComparisonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Text(
                    "Reference Photo",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: Icon(Icons.person, size: 60)),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 20),

            Expanded(
              child: Column(
                children: [
                  const Text(
                    "Today's Photo",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.camera_alt, size: 60),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
