import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import '../../models/app_user.dart';
import '../admin/dashboard_screen.dart';
import '../register/register_screen.dart';
import '../trainer/trainer_dashboard_screen.dart';

class MultiRoleDashboardScreen extends StatelessWidget {
  const MultiRoleDashboardScreen({super.key, required this.appUser});

  final AppUser appUser;

  void _openAdmin(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _openTrainer(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TrainerDashboardScreen()),
    );
  }

  void _openStaff(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = <UserRole>{
      if (appUser.isAdmin) UserRole.admin,
      if (appUser.isTrainer) UserRole.trainer,
      if (appUser.isStaff) UserRole.staff,
    };

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Select Portal')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.switch_account_outlined, color: Colors.white, size: 27),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('MULTIPLE ACCESS', style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                            const SizedBox(height: 5),
                            Text('Welcome, ${appUser.displayName}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('Choose your portal', style: TextStyle(color: AppTheme.text, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  const Text('Open the workspace you need without changing your account.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  const SizedBox(height: 16),
                  if (roles.contains(UserRole.admin)) _PortalButton(icon: Icons.admin_panel_settings_outlined, title: 'Admin Portal', subtitle: 'Manage staff, participants, assessments and reports.', onTap: () => _openAdmin(context)),
                  if (roles.contains(UserRole.trainer)) _PortalButton(icon: Icons.school_outlined, title: 'Trainer Portal', subtitle: 'Manage training history, reviews and training photos.', onTap: () => _openTrainer(context)),
                  if (roles.contains(UserRole.staff)) _PortalButton(icon: Icons.badge_outlined, title: 'Staff Portal', subtitle: 'Complete daily grooming check-in and assessment.', onTap: () => _openStaff(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
