import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'core/routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const BatikAirApp());
}

class BatikAirApp extends StatelessWidget {
  const BatikAirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Batik Air Grooming Assessment',
      debugShowCheckedModeBanner: false,

      // Global Theme
      theme: AppTheme.lightTheme,

      // First Screen
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
