import 'package:flutter/material.dart';

import '../auth/post_auth_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../admin/dashboard_screen.dart';
import '../register/register_screen.dart';
import 'login_screen.dart';

enum _Selection { none, admin, staff }

/// The single, mandatory stop between authentication and the rest of
/// the app -- reached after *every* successful sign-in that
/// [resolvePostAuthRoute] resolves to [PostAuthRoute.pending] or
/// [PostAuthRoute.lookupFailed], and by every Admin-only screen's role
/// guard redirecting a non-admin account away.
///
/// [initState] runs the exact same centralized resolver LoginScreen and
/// SplashScreen use (see post_auth_router.dart) and reacts to whichever
/// of its five outcomes comes back:
/// - [PostAuthRoute.admin] / [PostAuthRoute.staff]: a *confirmed* role
///   already exists -- navigate straight past this screen to that
///   role's destination without the user tapping anything. Nothing is
///   written in either case; this is a read-only check.
/// - [PostAuthRoute.pending]: no role has ever been chosen -- show the
///   manual Admin/Staff picker below.
/// - [PostAuthRoute.lookupFailed]: the Firestore read could not be
///   confirmed (network error, etc.) -- show a distinct Retry screen,
///   never the picker. This distinction is the actual fix for a bug
///   where a transient failure used to be treated exactly like
///   [PostAuthRoute.pending], which could let an account that already
///   had a role see the picker again; see
///   AuthService._guardRoleChange's doc comment for the full story and
///   the second, independent layer that also closes it.
/// - [PostAuthRoute.notSignedIn]: defensively routes to LoginScreen;
///   this screen is not normally reached in this state.
///
/// Admin goes straight to DashboardScreen. Staff goes to RegisterScreen
/// -- the existing "TRAINER PORTAL" screen, shared via TopNavigation
/// with CheckInScreen -- NOT to StaffDashboardScreen. This screen asks
/// nothing beyond "which role" -- no Staff ID, no participant lookup.
/// Staff ID belongs to Participant registration/check-in, a separate
/// concern collected later, in a separate screen, once it's actually
/// needed; a brand-new account with zero participant/assessment history
/// must be able to pick Staff here regardless.
///
/// StaffDashboardScreen is the far end of the assessment flow (Trainer
/// Portal -> Participant Check-In -> Assessment -> Result ->
/// StaffDashboardScreen), reached from ResultScreen after an assessment
/// completes, not the Staff landing page; see its own doc comment. This
/// stays true for the auto-routed path too -- a returning Staff account
/// lands on the Trainer Portal, never on StaffDashboardScreen directly.
///
/// Both manual choices write to `users/{uid}` via
/// AuthService.selectAdminRole/selectStaffRole, clearing the stack
/// behind the resulting screen so there's no way back to Role Selection
/// or Login with the back button. The auto-routed path clears the stack
/// the same way. Both writers refuse to overwrite an already-confirmed
/// *different* role -- see AuthService._guardRoleChange -- so even if
/// this screen is somehow reached for an account that already has a
/// role, selecting the other one fails loudly instead of silently
/// clobbering it.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final AuthService authService = AuthService();

  _Selection selection = _Selection.none;
  bool isLoading = false;

  /// True while [_resolve] is still deciding whether this session can
  /// skip straight past the picker. Neither the picker nor the Retry
  /// state is built while this is true, so there's no flash of either
  /// for an account this screen is about to auto-route away from
  /// anyway.
  bool _checkingRole = true;

  /// True when [_resolve] came back as [PostAuthRoute.lookupFailed] --
  /// shows the Retry screen instead of the picker. See the class doc
  /// comment for why this must never be folded into "show the picker".
  bool _lookupFailed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  /// Runs the centralized resolver and reacts to its outcome -- see the
  /// class doc comment for exactly what each of the five cases does.
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

      if (selection == _Selection.staff) {
        // Result intentionally unused: RoleSelectionScreen's job ends
        // at saving the role, not at loading a dashboard -- Staff goes
        // to the Trainer Portal (RegisterScreen) to perform an
        // assessment, not to StaffDashboardScreen (see the class doc
        // comment).
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

      // AuthService._guardRoleChange throws a specific StateError when
      // this account already has a different confirmed role -- surface
      // that message rather than a generic one, since it points at the
      // real fix (ask an Admin) instead of "try again", which would
      // just fail the same way again.
      final message = e is StateError
          ? e.message
          : "Could not save your role. Please try again.";

      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
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
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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

              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: isLoading || selection == _Selection.none
                    ? null
                    : _continue,
                child: Text(isLoading ? "Saving..." : "Continue"),
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
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),

            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? AppTheme.primary : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
