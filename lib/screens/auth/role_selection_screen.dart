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

      case PostAuthRoute.lookupFailed:
        setState(() {
          _lookupFailed = true;
          _checkingRole = false;
        });
        return;

      case PostAuthRoute.pending:
        if (result.appUser != null && result.appUser!.roles.length > 1) {
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
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_lookupFailed) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Could not confirm your account. Please check your "
                    "connection and try again.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _resolve,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Select Your Role"),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              const Text(
                "Select Your Role",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Choose how you will use the TiB AI Grooming Assessment "
                "System.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),

              const SizedBox(height: 28),

              _RoleCard(
                icon: Icons.admin_panel_settings_outlined,
                title: "ADMIN",
                description: "Administrator access",
                selected: selection == _Selection.admin,
                onTap: _selectAdmin,
              ),

              const SizedBox(height: 16),

              _RoleCard(
                icon: Icons.badge_outlined,
                title: "STAFF",
                description: "Staff grooming assessment access",
                selected: selection == _Selection.staff,
                onTap: _selectStaff,
              ),

              const SizedBox(height: 16),

              _RoleCard(
                icon: Icons.school_outlined,
                title: "TRAINER",
                description: "Manage training history and trainer reports",
                selected: selection == _Selection.trainer,
                onTap: _selectTrainer,
              ),

              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: isLoading || selection == _Selection.none
                    ? null
                    : _continue,
                child: Text(
                  isLoading ? "Saving..." : "Continue",
                ),
              ),
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
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : AppTheme.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : AppTheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: selected ? AppTheme.primary : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
