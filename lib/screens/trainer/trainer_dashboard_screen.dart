import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/multi_role_dashboard_screen.dart';
import '../admin/dashboard_screen.dart';
import 'trainer_history_editor_screen.dart';
import 'trainer_training_history_screen.dart';

class TrainerDashboardScreen extends StatelessWidget {
  const TrainerDashboardScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _addTrainingReport(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TrainerHistoryEditorScreen(),
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Training report created.')),
      );
    }
  }

  void _openHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TrainerTrainingHistoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Trainer Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Switch Portal',
            onPressed: () async {
              final appUser = await AuthService().getCurrentAppUser();
              if (!context.mounted) return;
              if (appUser != null && appUser.roles.length > 1) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MultiRoleDashboardScreen(appUser: appUser)));
              } else {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
              }
            },
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Sign Out',
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.school_outlined, color: Colors.white, size: 26)),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('TRAINING PORTAL', style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5))),
                  ]),
                  const SizedBox(height: 18),
                  const Text('Trainer Dashboard', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  const Text('Manage training history, reports, trainer reviews and training photos.', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
                ]),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: () => _addTrainingReport(context), icon: const Icon(Icons.add, size: 19), label: const Text('Add Training Report')),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openHistory(context),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      Container(width: 50, height: 50, decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.folder_copy_outlined, color: AppTheme.primary, size: 27)),
                      const SizedBox(width: 14),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Training History', style: TextStyle(color: AppTheme.text, fontSize: 17, fontWeight: FontWeight.w700)),
                        SizedBox(height: 5),
                        Text('Search, edit and manage historical training records.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4)),
                      ])),
                      const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
