import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/checkin/checkin_screen.dart';
import '../screens/register/register_screen.dart';
import '../services/auth_service.dart';

/// Tab bar shared by RegisterScreen (Trainer Portal) and CheckInScreen
/// (Participant Check-In) -- the same operational area Staff lands in
/// after Role Selection. Also the Logout entry point for that whole
/// area: shown only when someone is actually signed in, since
/// CheckInScreen doubles as the no-auth Cabin Crew self-service flow,
/// where there's no session to log out of.
class TopNavigation extends StatelessWidget {
  final bool isRegister;

  const TopNavigation({super.key, required this.isRegister});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Only ends the Firebase Auth session. Does not touch the Firestore
    // `users/{uid}` profile, participants, assessment history,
    // reference photos, or remembered "Remember me" credentials --
    // LoginScreen still pre-fills those on the next screen it builds.
    await AuthService().signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      width: double.infinity,
      color: const Color(0xFF162B56),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (!isRegister) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: isRegister
                  ? const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE5C27A), width: 2),
                      ),
                    )
                  : null,
              child: Text(
                "TRAINER ADMIN",
                style: TextStyle(
                  color: isRegister ? const Color(0xFFE5C27A) : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          const SizedBox(width: 25),

          GestureDetector(
            onTap: () {
              if (isRegister) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckInScreen()),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: !isRegister
                  ? const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE5C27A), width: 2),
                      ),
                    )
                  : null,
              child: Text(
                "PARTICIPANT CHECK-IN",
                style: TextStyle(
                  color: !isRegister ? const Color(0xFFE5C27A) : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          const Spacer(),

          if (FirebaseAuth.instance.currentUser != null)
            IconButton(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
              tooltip: "Logout",
            ),
        ],
      ),
    );
  }
}
