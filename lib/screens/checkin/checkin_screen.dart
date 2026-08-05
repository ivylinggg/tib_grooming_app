import 'package:flutter/material.dart';

import '../../widgets/checkin_card.dart';
import '../../widgets/hero_banner.dart';
import '../../widgets/top_navigation.dart';

class CheckInScreen extends StatelessWidget {
  const CheckInScreen({super.key});

  static const Color backgroundColor = Color(0xFFF8F6F1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopNavigation(isRegister: false),

              SizedBox(height: 16),

              HeroBanner(
                badge: "DAILY GROOMING CHECK-IN",
                title: "Grooming",
                highlight: "Assessment",
                description:
                    "Enter your Staff ID to retrieve your profile before completing today's grooming assessment.",
              ),

              SizedBox(height: 24),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: CheckInCard(),
              ),

              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
