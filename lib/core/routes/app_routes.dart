import 'package:flutter/material.dart';

import '../../screens/auth/login_portal.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/welcome/welcome_screen.dart';
import '../../screens/auth/role_selection_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = "/";
  static const welcome = "/welcome";
  static const role = "/role";
  static const login = "/login";

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());

      case role:
        return MaterialPageRoute(builder: (_) => const RoleSelectionScreen());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginPortal());

      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}
