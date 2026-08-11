import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/post_auth_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Unified email/password sign-in for both Admin and Staff accounts.
/// After a successful sign-in, [routeAfterAuth] (the same centralized
/// resolver SplashScreen uses) decides where to land: a confirmed
/// Admin/Staff account goes straight to its own dashboard, and only a
/// genuinely role-less (`pending`) account -- or a lookup that couldn't
/// be confirmed -- ever sees RoleSelectionScreen. This screen does not
/// re-implement that decision itself; see post_auth_router.dart for the
/// one place it's made.
///
/// "Remember me" only pre-fills email/password on this screen's next
/// appearance (see initState) -- it never signs anyone in automatically
/// or skips this screen. SplashScreen always lands here (or on
/// SignUpScreen) for a signed-out session; there is no *other*
/// session-resume path anywhere in the app.
///
/// This is the app's sole sign-in entry point going forward -- reached
/// from SplashScreen for a signed-out session, and from
/// StaffDashboardScreen/DashboardScreen/TopNavigation on sign-out. It
/// does not replace the existing no-auth Cabin Crew Check-In flow
/// (CheckInScreen/CheckInCard), which stays reachable on its own and
/// never routes through here.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService authService = AuthService();

  bool isLoading = false;
  bool obscurePassword = true;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  /// Pre-fills the form only -- does not sign in, does not navigate.
  /// The user still sees this screen, can edit either field, and still
  /// has to press Sign In.
  Future<void> _loadRememberedCredentials() async {
    final creds = await authService.getRememberedCredentials();
    if (!mounted || creds == null) return;

    setState(() {
      emailController.text = creds.email;
      passwordController.text = creds.password;
      rememberMe = true;
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter email and password."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_emailPattern.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid email address."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      // signIn's returned AppUser is not consulted directly here --
      // routeAfterAuth below re-reads the account's role itself (from
      // the server, not any value this call happened to return) so
      // there is exactly one place that decision is made. signIn still
      // runs so a missing `users/{uid}` profile gets created.
      await authService.signIn(email: email, password: password);

      // Only ever pre-fills this screen next time -- never used to skip
      // it or to sign anyone in automatically. Unchecking "Remember me"
      // wipes anything saved from an earlier session.
      if (rememberMe) {
        await authService.saveRememberedCredentials(
          email: email,
          password: password,
        );
      } else {
        await authService.clearRememberedCredentials();
      }

      if (!mounted) return;

      await routeAfterAuth(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(describeAuthError(e)),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text("Sign in failed."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.flight_takeoff_rounded,
                    size: 46,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  "Sign In",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Grooming Assessment System",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),

                const SizedBox(height: 32),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
                ),

                CheckboxListTile(
                  value: rememberMe,
                  onChanged: isLoading
                      ? null
                      : (value) {
                          setState(() {
                            rememberMe = value ?? false;
                          });
                        },
                  title: const Text("Remember me"),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                    child: const Text("Forgot Password?"),
                  ),
                ),

                const SizedBox(height: 8),

                ElevatedButton(
                  onPressed: isLoading ? null : _signIn,
                  child: Text(isLoading ? "Signing in..." : "Sign In"),
                ),

                const SizedBox(height: 12),

                Center(
                  child: TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignUpScreen(),
                              ),
                            );
                          },
                    child: const Text("Don't have an account? Sign Up"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
