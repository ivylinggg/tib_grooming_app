import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';

/// Real Firebase password-reset flow: sends the account's Firebase
/// Auth "reset password" email via [AuthService.sendPasswordResetEmail].
/// Reached from LoginScreen's "Forgot Password?" link, for both Admin
/// and Staff accounts alike -- the reset flow doesn't depend on role.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  final AuthService authService = AuthService();

  bool isLoading = false;
  bool emailSent = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your email address."),
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
      await authService.sendPasswordResetEmail(email);

      if (!mounted) return;

      setState(() {
        isLoading = false;
        emailSent = true;
      });
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
          content: Text("Could not send reset email."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text("Forgot Password")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              if (emailSent) ...[
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 64,
                  color: AppTheme.success,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Reset email sent",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  "Check ${emailController.text.trim()} for a link to "
                  "reset your password.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Back to Sign In"),
                ),
              ] else ...[
                const Text(
                  "Enter the email address associated with your account "
                  "and we'll send you a link to reset your password.",
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "Email"),
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: isLoading ? null : _sendResetEmail,
                  child: Text(isLoading ? "Sending..." : "Send Reset Email"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
