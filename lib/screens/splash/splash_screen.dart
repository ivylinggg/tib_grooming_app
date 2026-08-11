import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/post_auth_router.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _fadeAnimation;

  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnimation = Tween<double>(
      begin: 0.75,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    Timer(const Duration(seconds: 3), _routeNext);
  }

  /// Routes based on whatever Firebase Auth session already exists on
  /// this device -- never assumes Admin, never assumes signed-out.
  /// [routeAfterAuth] (the same centralized resolver LoginScreen uses)
  /// reads `FirebaseAuth.instance.currentUser` and, if present,
  /// `users/{uid}.role`: a saved Admin/Staff account goes straight to
  /// its dashboard, a signed-out or role-less session lands on
  /// Sign In / Role Selection. This is not a "remember me" convenience
  /// -- it only reflects whatever Firebase Auth itself already decided
  /// is signed in; "Remember me" is unrelated and only ever pre-fills
  /// LoginScreen's email/password fields (see LoginScreen.initState).
  void _routeNext() {
    if (!mounted) return;

    routeAfterAuth(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF234A84), Color(0xFF1F3D73), Color(0xFF17305D)],
          ),
        ),

        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,

              child: ScaleTransition(
                scale: _scaleAnimation,

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),

                      child: const Icon(
                        Icons.flight_takeoff_rounded,
                        size: 65,
                        color: AppTheme.primary,
                      ),
                    ),

                    const SizedBox(height: 35),

                    const Text(
                      "BATIK AIR",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      "Grooming Assessment System",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      "Professional • Secure • Efficient",
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 80),

                    const SizedBox(
                      width: 35,
                      height: 35,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "Loading...",
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
