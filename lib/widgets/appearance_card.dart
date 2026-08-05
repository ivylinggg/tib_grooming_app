import 'dart:io';

import 'package:flutter/material.dart';

class AppearanceCard extends StatelessWidget {
  final File? todayPhoto;
  final VoidCallback onTakePhoto;

  const AppearanceCard({
    super.key,
    required this.todayPhoto,
    required this.onTakePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Appearance Photo",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF162B56),
              ),
            ),

            const SizedBox(height: 20),

            GestureDetector(
              onTap: onTakePhoto,
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: todayPhoto == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 50,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 15),
                          Text("Tap to Take Photo"),
                          SizedBox(height: 8),
                          Text(
                            "Please take a clear,\nfull-body photo",
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          todayPhoto!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTakePhoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(todayPhoto == null ? "Take Photo" : "Retake Photo"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
