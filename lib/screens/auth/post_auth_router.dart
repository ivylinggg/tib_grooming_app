import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../screens/admin/dashboard_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/role_selection_screen.dart';
import '../../screens/register/register_screen.dart';
import '../../services/auth_service.dart';

/// Every distinct place a signed-in (or signed-out) session can land,
/// as decided purely from Firebase Auth + `users/{uid}.role` -- nothing
/// else. [lookupFailed] is deliberately its own case, never folded into
/// [pending]: a transient read failure must never be treated the same
/// as "this account genuinely has no role yet", because that confusion
/// is exactly what let a Staff account see the role picker again and
/// have its saved role put at risk. See [resolvePostAuthRoute]'s doc
/// comment for the full reasoning.
enum PostAuthRoute { notSignedIn, admin, staff, pending, lookupFailed }

class PostAuthResult {
  final PostAuthRoute route;
  final AppUser? appUser;

  const PostAuthResult(this.route, this.appUser);
}

/// The single source of truth for "given whoever is signed in right
/// now, which screen should they be looking at" -- used identically by
/// SplashScreen (app cold start), LoginScreen (right after a successful
/// sign-in), and RoleSelectionScreen (its own initState, and its Retry
/// button after a failed lookup). Previously each of those three had
/// its own copy of this decision; this is now the only place it's made,
/// so it can't drift or be gotten wrong independently in any one of
/// them.
///
/// Firestore's `users/{uid}.role` is the *only* signal consulted here.
/// Never SharedPreferences, never a static/global variable, never the
/// previously signed-in account's role, never the email address, never
/// a default -- see AuthService._loadAppUser's doc comment for why the
/// read itself is forced to the server rather than the SDK's local
/// cache: a role decision this security-relevant must never be made
/// from a value that might not have finished syncing yet.
///
/// A failed lookup ([PostAuthRoute.lookupFailed]) is the one case that
/// never silently becomes [PostAuthRoute.pending]. Folding the two
/// together was the actual bug behind a Staff account occasionally
/// landing on Admin Dashboard: a transient read failure used to show
/// the manual Admin/Staff picker exactly as if the account had never
/// chosen a role, and selecting Staff there called an *unconditional*
/// `.update({'role': 'staff'})` with nothing to stop it from clobbering
/// a different role that already existed on the server. Every caller of
/// this function must treat [PostAuthRoute.lookupFailed] as "we don't
/// know yet, let them retry" -- never as permission to show the picker
/// or land on any dashboard.
Future<PostAuthResult> resolvePostAuthRoute() async {
  final authService = AuthService();

  if (authService.currentUser == null) {
    return const PostAuthResult(PostAuthRoute.notSignedIn, null);
  }

  AppUser? appUser;
  try {
    appUser = await authService.getCurrentAppUser();
  } catch (_) {
    return const PostAuthResult(PostAuthRoute.lookupFailed, null);
  }

  if (appUser == null) {
    return const PostAuthResult(PostAuthRoute.lookupFailed, null);
  }

  switch (appUser.role) {
    case UserRole.admin:
      return PostAuthResult(PostAuthRoute.admin, appUser);
    case UserRole.staff:
      return PostAuthResult(PostAuthRoute.staff, appUser);
    case UserRole.pending:
      return PostAuthResult(PostAuthRoute.pending, appUser);
  }
}

/// Performs the actual navigation for [resolvePostAuthRoute]'s result,
/// clearing the navigation stack behind the destination -- used by
/// SplashScreen and LoginScreen, which both just want to land somewhere
/// and don't need to react differently to any one outcome.
/// RoleSelectionScreen does NOT use this: it needs to render its own
/// inline UI for [PostAuthRoute.pending] (the picker) and
/// [PostAuthRoute.lookupFailed] (a Retry state) rather than navigating
/// away, so it calls [resolvePostAuthRoute] directly instead.
///
/// [PostAuthRoute.lookupFailed] intentionally routes to
/// RoleSelectionScreen, not to any dashboard and not back into a retry
/// loop here -- RoleSelectionScreen shows its own Retry UI for exactly
/// this case rather than guessing.
Future<void> routeAfterAuth(BuildContext context) async {
  final result = await resolvePostAuthRoute();

  if (!context.mounted) return;

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
    case PostAuthRoute.pending:
    case PostAuthRoute.lookupFailed:
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
      return;
  }
}
