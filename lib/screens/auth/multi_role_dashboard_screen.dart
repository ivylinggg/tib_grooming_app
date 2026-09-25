import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../admin/dashboard_screen.dart';
import '../register/register_screen.dart';
import '../trainer/trainer_dashboard_screen.dart';

class MultiRoleDashboardScreen extends StatelessWidget {
  const MultiRoleDashboardScreen({super.key, required this.appUser});

  final AppUser appUser;

  void _openAdmin(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _openTrainer(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TrainerDashboardScreen()),
    );
  }

  void _openStaff(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = <UserRole>{
      if (appUser.isAdmin) UserRole.admin,
      if (appUser.isTrainer) UserRole.trainer,
      if (appUser.isStaff) UserRole.staff,
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
        title: const Text('Select Portal'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome, ${appUser.displayName}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This account has multiple roles. Choose the portal you want to open.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (roles.contains(UserRole.admin))
              _PortalButton(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin Portal',
                subtitle: 'Manage staff, participants and assessments',
                onTap: () => _openAdmin(context),
              ),
            if (roles.contains(UserRole.trainer))
              _PortalButton(
                icon: Icons.school_outlined,
                title: 'Trainer Portal',
                subtitle: 'Manage Training History and training photos',
                onTap: () => _openTrainer(context),
              ),
            if (roles.contains(UserRole.staff))
              _PortalButton(
                icon: Icons.badge_outlined,
                title: 'Staff Portal',
                subtitle: 'Open staff registration and grooming workflow',
                onTap: () => _openStaff(context),
              ),
          ],
        ),
      ),
    );
  }
}

class _PortalButton extends StatelessWidget {
  const _PortalButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: const Color(0xFF1F3D73),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
