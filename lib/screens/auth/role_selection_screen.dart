import 'package:flutter/material.dart';

import '../auth/post_auth_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../admin/dashboard_screen.dart';
import '../trainer/trainer_dashboard_screen.dart';
import 'multi_role_dashboard_screen.dart';
import '../register/register_screen.dart';
import 'login_screen.dart';

enum _Selection { none, admin, staff, trainer }

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final AuthService authService = AuthService();

  _Selection selection = _Selection.none;
  bool isLoading = false;
  bool _checkingRole = true;
  bool _lookupFailed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() {
      _checkingRole = true;
    });

    final result = await resolvePostAuthRoute();

    if (!mounted) return;

    switch (result.route) {
      case PostAuthRoute.notSignedIn:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;

      case PostAuthRoute.admin:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
        return;

      case PostAuthRoute.staff:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
          (route) => false,
        );
        return;

      case PostAuthRoute.trainer:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const TrainerDashboardScreen(),
          ),
          (route) => false,
        );
        return;

      case PostAuthRoute.lookupFailed:
        setState(() {
          _lookupFailed = true;
          _checkingRole = false;
        });
        return;

      case PostAuthRoute.multiRole:
        if (result.appUser != null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => MultiRoleDashboardScreen(
                appUser: result.appUser!,
              ),
            ),
            (route) => false,
          );
          return;
        }
        setState(() {
          _lookupFailed = false;
          _checkingRole = false;
        });
        return;

      case PostAuthRoute.pending:
        setState(() {
          _lookupFailed = false;
          _checkingRole = false;
        });
        return;
    }
  }

  void _selectAdmin() {
    if (isLoading) return;
    setState(() {
      selection = _Selection.admin;
    });
  }

  void _selectStaff() {
    if (isLoading) return;
    setState(() {
      selection = _Selection.staff;
    });
  }

  void _selectTrainer() {
    if (isLoading) return;
    setState(() {
      selection = _Selection.trainer;
    });
  }

  Future<void> _continue() async {
    setState(() {
      isLoading = true;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (selection == _Selection.admin) {
        await authService.selectAdminRole();

        if (!mounted) return;

        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
        return;
      }

      if (selection == _Selection.trainer) {
        await authService.selectTrainerRole();

        if (!mounted) return;

        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const TrainerDashboardScreen(),
          ),
          (route) => false,
        );
        return;
      }

      if (selection == _Selection.staff) {
        await authService.selectStaffRole();

        if (!mounted) return;

        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      final message = e is StateError
          ? e.message
          : "Could not save your role. Please try again.";

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingRole) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_lookupFailed) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Account access')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 44,
                      color: AppTheme.error,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Could not confirm your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _resolve,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Select Your Role'),
        leading: IconButton(
          tooltip: 'Back to Sign In',
          onPressed: isLoading
              ? null
              : () async {
                  await authService.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose your workspace',
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select the role you will use for this session.',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'ADMIN',
                description: 'Participants, assessments, reports and system management',
                selected: selection == _Selection.admin,
                onTap: _selectAdmin,
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.badge_outlined,
                title: 'STAFF',
                description: 'Daily grooming check-in and appearance assessment',
                selected: selection == _Selection.staff,
                onTap: _selectStaff,
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.school_outlined,
                title: 'TRAINER',
                description: 'Training history, trainer reports and training photos',
                selected: selection == _Selection.trainer,
                onTap: _selectTrainer,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isLoading || selection == _Selection.none
                      ? null
                      : _continue,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(isLoading ? 'Saving...' : 'Continue'),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your available portals depend on the role assigned to your account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
