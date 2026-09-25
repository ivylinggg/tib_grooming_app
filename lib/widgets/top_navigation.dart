import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../screens/auth/login_screen.dart';
import '../screens/checkin/checkin_screen.dart';
import '../screens/register/register_screen.dart';
import '../services/auth_service.dart';

class TopNavigation extends StatelessWidget {
  final bool isRegister;

  const TopNavigation({super.key, required this.isRegister});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      color: AppTheme.primaryDark,
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.person_add_alt_1_outlined,
              label: 'TRAINER ADMIN',
              selected: isRegister,
              onTap: () {
                if (!isRegister) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterScreen(),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NavItem(
              icon: Icons.badge_outlined,
              label: 'CHECK-IN',
              selected: !isRegister,
              onTap: () {
                if (isRegister) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CheckInScreen(),
                    ),
                  );
                }
              },
            ),
          ),
          if (FirebaseAuth.instance.currentUser != null) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Logout',
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_outlined, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? AppTheme.primary : Colors.white70,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppTheme.primary : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
