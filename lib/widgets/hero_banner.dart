import 'package:flutter/material.dart';

class HeroBanner extends StatelessWidget {
  final String badge;
  final String title;
  final String highlight;
  final String description;

  const HeroBanner({
    super.key,
    required this.badge,
    required this.title,
    required this.highlight,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: const BoxDecoration(color: Color(0xFF1F3D73)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Circle
          Positioned(
            top: -60,
            right: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE5C27A)),
                ),
                child: Text(
                  badge.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFE5C27A),
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Title
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: "$title ",
                      style: const TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: highlight,
                      style: const TextStyle(
                        color: Color(0xFFE5C27A),
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Description
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
