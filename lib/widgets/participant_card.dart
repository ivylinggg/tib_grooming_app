import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class ParticipantCard extends StatelessWidget {
  final TextEditingController fullNameController;
  final TextEditingController staffIdController;
  final TextEditingController trainerNameController;
  final TextEditingController registrationDateController;

  const ParticipantCard({
    super.key,
    required this.fullNameController,
    required this.staffIdController,
    required this.trainerNameController,
    required this.registrationDateController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.badge_outlined,
            title: 'Participant Details',
            subtitle: 'Basic information for the grooming record',
          ),
          const SizedBox(height: 18),
          _Field(
            controller: fullNameController,
            label: 'Full Name',
            icon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: staffIdController,
            label: 'Staff ID',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: trainerNameController,
            label: 'Trainer Name',
            icon: Icons.school_outlined,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: registrationDateController,
            label: 'Registration Date',
            icon: Icons.calendar_today_outlined,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.badge_outlined, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.text)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.textCapitalization,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextCapitalization? textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization:
          textCapitalization ?? TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
