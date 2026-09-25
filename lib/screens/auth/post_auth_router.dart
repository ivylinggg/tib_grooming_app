import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../screens/admin/dashboard_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/role_selection_screen.dart';
import 'multi_role_dashboard_screen.dart';
import '../../screens/register/register_screen.dart';
import '../../screens/trainer/trainer_dashboard_screen.dart';
import '../../services/auth_service.dart';

enum PostAuthRoute {
  notSignedIn,
  admin,
  staff,
  trainer,
  pending,
  multiRole,
  lookupFailed,
}

class PostAuthResult {
  final PostAuthRoute route;
  final AppUser? appUser;

  const PostAuthResult(this.route, this.appUser);
}

Future<PostAuthResult> resolvePostAuthRoute() async {
  final authService = AuthService();

  if (authService.currentUser == null) {
    return const PostAuthResult(
      PostAuthRoute.notSignedIn,
      null,
    );
  }

  AppUser? appUser;

  try {
    appUser = await authService.getCurrentAppUser();
  } catch (_) {
    return const PostAuthResult(
      PostAuthRoute.lookupFailed,
      null,
    );
  }

  if (appUser == null) {
    return const PostAuthResult(
      PostAuthRoute.lookupFailed,
      null,
    );
  }

  if (appUser.roles.length > 1 || (appUser.isAdmin && appUser.isTrainer)) {
    return PostAuthResult(
      PostAuthRoute.multiRole,
      appUser,
    );
  }

  switch (appUser.role) {
    case UserRole.admin:
      return PostAuthResult(
        PostAuthRoute.admin,
        appUser,
      );

    case UserRole.staff:
      return PostAuthResult(
        PostAuthRoute.staff,
        appUser,
      );

    case UserRole.trainer:
      return PostAuthResult(
        PostAuthRoute.trainer,
        appUser,
      );

    case UserRole.pending:
      return PostAuthResult(
        PostAuthRoute.pending,
        appUser,
      );
  }
}

Future<void> routeAfterAuth(BuildContext context) async {
  final result = await resolvePostAuthRoute();

  if (!context.mounted) return;

  switch (result.route) {
    case PostAuthRoute.notSignedIn:
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
      return;

    case PostAuthRoute.admin:
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
        ),
        (route) => false,
      );
      return;

    case PostAuthRoute.staff:
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
        ),
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
      return;

    case PostAuthRoute.pending:
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const RoleSelectionScreen(),
        ),
        (route) => false,
      );
      return;

    case PostAuthRoute.lookupFailed:
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const RoleSelectionScreen(),
        ),
        (route) => false,
      );
      return;
  }
}
