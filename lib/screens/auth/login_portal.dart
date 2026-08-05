import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../admin/dashboard_screen.dart';
import '../checkin/checkin_screen.dart';

class LoginPortal extends StatelessWidget {
  const LoginPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(30, 55, 30, 45),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF234A84), Color(0xFF1F3D73)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(35),
                    bottomRight: Radius.circular(35),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.flight_takeoff_rounded,
                        color: AppTheme.primary,
                        size: 48,
                      ),
                    ),

                    const SizedBox(height: 25),

                    const Text(
                      "BATIK AIR",
                      style: TextStyle(
                        color: Color(0xFFE5C27A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),

                    const SizedBox(height: 15),

                    const Text(
                      "Grooming Assessment\nSystem",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Choose your role to continue.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _RoleCard(
                  icon: Icons.admin_panel_settings_rounded,
                  title: "Trainer Administrator",
                  subtitle:
                      "Manage participants, AI grooming assessments, reports and system data.",
                  buttonText: "ENTER ADMIN PORTAL",
                  color: AppTheme.primary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DashboardScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 22),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _RoleCard(
                  icon: Icons.badge_rounded,
                  title: "Cabin Crew",
                  subtitle:
                      "Daily grooming check-in and AI appearance assessment.",
                  buttonText: "ENTER STAFF PORTAL",
                  color: AppTheme.secondary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CheckInScreen()),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                "Version 1.0.0",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),

              const SizedBox(height: 8),

              const Text(
                "Powered by Batik Air Digital Innovation",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),

              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final Color color;
  final VoidCallback onPressed;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 34),
          ),

          const SizedBox(height: 18),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF162B56),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black54,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
