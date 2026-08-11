import 'dart:io';

import 'package:flutter/material.dart';

class UploadPhotoCard extends StatelessWidget {
  final File? image;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;
  final VoidCallback? onRemovePhoto;

  const UploadPhotoCard({
    super.key,
    required this.image,
    required this.onTakePhoto,
    required this.onPickGallery,
    this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A74F),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  "Reference Photo (Best Appearance)",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF162B56),
                  ),
                ),
              ),

              if (image != null)
                IconButton(
                  onPressed: onRemovePhoto,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 220),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD6DCE8), width: 2),
            ),
            child: image == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 30,
                      horizontal: 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.image_outlined,
                          size: 50,
                          color: Color(0xFF162B56),
                        ),

                        SizedBox(height: 16),

                        Text(
                          "Upload Reference Photo",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF162B56),
                          ),
                        ),

                        SizedBox(height: 10),

                        Text(
                          "This will be the standard for all future comparisons.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, height: 1.4),
                        ),

                        SizedBox(height: 18),

                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFFFF4DD),
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            child: Text(
                              "Ensure appearance meets Batik Air professional standards",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFB27A1A),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      image!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTakePhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text("Take Photo"),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text("From Gallery/Files"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
