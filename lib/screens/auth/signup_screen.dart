import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'role_selection_screen.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final RegExp _uppercase = RegExp(r'[A-Z]');
final RegExp _lowercase = RegExp(r'[a-z]');
final RegExp _digit = RegExp(r'[0-9]');
final RegExp _specialChar = RegExp(r'[^A-Za-z0-9]');

/// Create Account screen. Collects First/Last Name, Email, Password and
/// Confirm Password -- deliberately no Staff ID here, since Staff ID
/// belongs to the participant/assessee profile (Participant, registered
/// separately by an admin/trainer), not to the login account this
/// screen creates.
///
/// Creates the account via AuthService.signUp, which writes it to
/// `users/{uid}` with no role yet and leaves it signed in. On success
/// this screen continues straight into RoleSelectionScreen using that
/// same session -- it does not return to Login, since the account still
/// has to pick Admin or Staff before it has anywhere to go.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final AuthService authService = AuthService();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasDigit = false;
  bool hasSpecialChar = false;

  bool get _passwordMeetsRequirements =>
      hasMinLength &&
      hasUppercase &&
      hasLowercase &&
      hasDigit &&
      hasSpecialChar;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final password = passwordController.text;

    setState(() {
      hasMinLength = password.length >= 8;
      hasUppercase = _uppercase.hasMatch(password);
      hasLowercase = _lowercase.hasMatch(password);
      hasDigit = _digit.hasMatch(password);
      hasSpecialChar = _specialChar.hasMatch(password);
    });
  }

  @override
  void dispose() {
    passwordController.removeListener(_onPasswordChanged);
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
      _showError("Please complete all fields.");
      return;
    }

    if (!_emailPattern.hasMatch(email)) {
      _showError("Please enter a valid email address.");
      return;
    }

    if (!_passwordMeetsRequirements) {
      _showError("Password does not meet all requirements.");
      return;
    }

    if (password != confirmPassword) {
      _showError("Passwords do not match.");
      return;
    }

    setState(() {
      isLoading = true;
    });

    final navigator = Navigator.of(context);

    try {
      await authService.signUp(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );

      if (!mounted) return;

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showError(describeAuthError(e));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showError("Could not create account. Please try again.");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text("Create Account")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Sign Up",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 6),

              const Text(
                "Create your account to get started.",
                style: TextStyle(color: Colors.black54),
              ),

              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: firstNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: "First Name",
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: "Last Name"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

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

              const SizedBox(height: 12),

              _PasswordRequirements(
                hasMinLength: hasMinLength,
                hasUppercase: hasUppercase,
                hasLowercase: hasLowercase,
                hasDigit: hasDigit,
                hasSpecialChar: hasSpecialChar,
              ),

              const SizedBox(height: 16),

              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: isLoading ? null : _signUp,
                child: Text(isLoading ? "Creating account..." : "Sign Up"),
              ),

              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text("Already have an account? Sign In"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecialChar;

  const _PasswordRequirements({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialChar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Password must contain:",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _Requirement(met: hasMinLength, label: "At least 8 characters"),
          _Requirement(
            met: hasUppercase,
            label: "At least 1 uppercase letter (A-Z)",
          ),
          _Requirement(
            met: hasLowercase,
            label: "At least 1 lowercase letter (a-z)",
          ),
          _Requirement(met: hasDigit, label: "At least 1 number (0-9)"),
          _Requirement(
            met: hasSpecialChar,
            label: "At least 1 special character (!@#\$%^&* etc.)",
          ),
        ],
      ),
    );
  }
}

class _Requirement extends StatelessWidget {
  final bool met;
  final String label;

  const _Requirement({required this.met, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: met ? AppTheme.success : Colors.black38,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: met ? Colors.black87 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
