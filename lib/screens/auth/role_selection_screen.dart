import 'package:flutter/material.dart';

import '../auth/post_auth_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../admin/dashboard_screen.dart';
import '../register/register_screen.dart';
import 'login_screen.dart';

enum _Selection { none, admin, staff }

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
    if (mounted) {
      setState(() {
        _checkingRole = true;
        _lookupFailed = false;
      });
    }

    try {
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
          setState(() {
            _lookupFailed = false;
            _checkingRole = false;
          });
          return;
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _lookupFailed = true;
        _checkingRole = false;
      });
    }
  }

  void _selectAdmin() {
    if (isLoading) return;
    setState(() => selection = _Selection.admin);
  }

  void _selectStaff() {
    if (isLoading) return;
    setState(() => selection = _Selection.staff);
  }

  Future<void> _continue() async {
    if (selection == _Selection.none || isLoading) return;

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

      if (selection == _Selection.staff) {
        await authService.selectStaffRole();

        if (!mounted) return;

        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
          (route) => false,
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      final message = e is StateError
          ? e.message
          : 'Could not continue. Please try again.';

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.primary,
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
        appBar: AppBar(
          title: const Text('Account Check'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 52,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'We could not confirm your account role.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isLoading ? null : _resolve,
                    child: const Text('Retry'),
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
        title: const Text('Select Your Role'),
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
                'Select Your Role',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you will use the TiB AI Grooming Assessment System.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 28),
              _RoleCard(
                icon: Icons.admin_panel_settings_outlined,
                title: 'ADMIN',
                description: 'Administrator access',
                selected: selection == _Selection.admin,
                onTap: _selectAdmin,
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.badge_outlined,
                title: 'STAFF',
                description: 'Staff grooming assessment access',
                selected: selection == _Selection.staff,
                onTap: _selectStaff,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: isLoading || selection == _Selection.none
                    ? null
                    : _continue,
                child: Text(isLoading ? 'Saving...' : 'Continue'),
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
