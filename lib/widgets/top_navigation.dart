import 'package:flutter/material.dart';

import '../screens/register/register_screen.dart';
import '../screens/checkin/checkin_screen.dart';

class TopNavigation extends StatelessWidget {
  final bool isRegister;

  const TopNavigation({super.key, required this.isRegister});

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
        ],
      ),
    );
  }
}
