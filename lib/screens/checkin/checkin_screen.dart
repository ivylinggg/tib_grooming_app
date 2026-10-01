import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import '../../widgets/checkin_card.dart';
import '../../widgets/hero_banner.dart';
import '../../widgets/top_navigation.dart';

class CheckInScreen extends StatelessWidget {
  const CheckInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopNavigation(isRegister: false),

              SizedBox(height: 20),

              HeroBanner(
                badge: "DAILY GROOMING CHECK-IN",
                title: "Grooming",
                highlight: "Assessment",
                description:
                    "Enter your Staff ID to retrieve your profile before completing today's grooming assessment.",
              ),

              SizedBox(height: 28),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: CheckInCard(),
              ),

              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
