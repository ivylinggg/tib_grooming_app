
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          _NotificationBellAction(notificationService: _notificationService),
          IconButton(
            tooltip: 'Switch Portal',
            onPressed: _switchPortal,
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Sign Out',
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryDark, AppTheme.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome Back",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Training Department",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Manage staff, AI grooming assessments and system records.",
                      style: TextStyle(color: Colors.white70, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                "Overview",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              if (_statsError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statsError!,
                          style: const TextStyle(color: AppTheme.error),
                        ),
                      ),
                      TextButton(
                        onPressed: loadDashboard,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              if (_staffCountError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_outlined,
                        color: AppTheme.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "${_staffCountError!} This may mean Firestore "
                          "security rules don't allow Admin to read the "
                          "users collection yet.",
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                      TextButton(
                        onPressed: loadDashboard,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              if (_loadingStats && _statsError == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_statsError == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _OverviewCard(
                        title: "Total Staff",
                        value: _staffCountError != null ? "—" : "$totalStaff",
                        icon: Icons.badge,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _OverviewCard(
                        title: "Total Participants",
                        value: "$totalParticipants",
                        icon: Icons.people,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _OverviewCard(
                        title: "Grooming Assessments",
                        value: "$totalAssessments",
                        icon: Icons.fact_check,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _OverviewCard(
                        title: "Average Score",
                        value: "${averageScore.toStringAsFixed(1)}/60",
                        icon: Icons.analytics,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _OverviewCard(
                        title: "Completed Assessments",
                        value: "$completedAssessments",
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _OverviewCard(
                        title: "Pending Participants",
                        value: "$pendingAssessments",
                        icon: Icons.pending_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _OverviewCard(
                  title: "Failed Grooming Assessments",
                  value: "$failedAssessments",
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppTheme.error,
                ),
              ],
              const SizedBox(height: 30),
              const Text(
                "Management",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              _DashboardButton(
                icon: Icons.person_add_alt,
                title: "Register Participant",
                subtitle: "Create a new participant profile",
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                  if (!context.mounted) return;
                  loadDashboard();
                },
              ),
              _DashboardButton(
                icon: Icons.badge,
                title: "Staff Management",
                subtitle: "Staff list, profiles, edit, activity",
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StaffManagementScreen(),
                    ),
                  );
                  if (!context.mounted) return;
                  loadDashboard();
                },
              ),
              _DashboardButton(
                icon: Icons.groups,
                title: "Participant Management",
                subtitle: "Participant list, profiles, assessment history",
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ParticipantManagementScreen(),
                    ),
                  );
                  if (!context.mounted) return;
                  loadDashboard();
                },
              ),
              _DashboardButton(
                icon: Icons.assignment_outlined,
                title: "Assessment Management",
                subtitle: "Every grooming assessment record, searchable",
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssessmentManagementScreen(),
                    ),
                  );
                  if (!context.mounted) return;
                  loadDashboard();
                },
              ),
              _DashboardButton(
                icon: Icons.bar_chart,
                title: "Statistics",
                subtitle: "System-wide analytics and performance",
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                  );
                },
              ),
              _DashboardButton(
                icon: Icons.history_edu_outlined,
                title: "Training History",
                subtitle:
                    "Search previous training records by participant name",
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TrainingHistoryScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              const Text(
                "Recent Activity",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              if (_loadingActivity)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _RecentActivitySection(
                  title: "Recently Registered Participants",
                  icon: Icons.person_add_alt,
                  isEmpty: _recentParticipants.isEmpty,
                  emptyText: "No participants registered yet",
                  children: _recentParticipants.map((participant) {
                    final name = participant["name"]?.toString() ?? "-";
                    final staffId = participant["staff"]?.toString() ?? "-";

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF1F3D73),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text("Staff ID: $staffId"),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ParticipantProfileScreen(staffId: staffId),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _RecentActivitySection(
                  title: "Recent Grooming Assessments",
                  icon: Icons.fact_check,
                  isEmpty: _recentAssessments.isEmpty,
                  emptyText: "No assessment records yet",
                  children: _recentAssessments.map((assessment) {
                    final name =
                        assessment["participantName"]?.toString() ?? "-";
                    final overall = assessment["overall"]?.toString() ?? "-";
                    final date = _formatTimestamp(
                      assessment["createdAt"] as Timestamp?,
                    );

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: _resultColor(overall),
                        child: const Icon(
                          Icons.assignment,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text("$overall  •  $date"),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AssessmentDetailScreen(
                              assessmentId: assessment["id"].toString(),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _RecentActivitySection(
                  title: "Recent Staff Accounts",
                  icon: Icons.badge,
                  isEmpty: _recentStaff.isEmpty,
                  emptyText: "No Staff accounts yet",
                  children: _recentStaff.map((staff) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF1F3D73),
                        child: Icon(Icons.badge, color: Colors.white, size: 18),
                      ),
                      title: Text(staff.displayName),
                      subtitle: Text(
                        "${staff.staffId ?? "No Staff ID"}  •  "
                        "${_formatDate(staff.createdAt)}",
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StaffProfileScreen(uid: staff.uid),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchPortal() async {
    final appUser = await _authService.getCurrentAppUser();
    if (!mounted) return;

    if (appUser != null && appUser.roles.length > 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MultiRoleDashboardScreen(appUser: appUser),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const TrainerDashboardScreen(),
        ),
      );
    }
  }
}

class _NotificationBellAction extends StatelessWidget {
  final NotificationService notificationService;

  const _NotificationBellAction({required this.notificationService});

  @override
  Widget build(BuildContext context) {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;

    Widget bell({int unreadCount = 0}) {
      return IconButton(
        tooltip: "Notifications",
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
        icon: Badge(
          isLabelVisible: unreadCount > 0,
          label: Text("$unreadCount"),
          child: const Icon(Icons.notifications_outlined),
        ),
      );
    }

    if (adminUid == null) return bell();

    return StreamBuilder<int>(
      stream: notificationService.streamUnreadCount(adminUid),
      builder: (context, snapshot) {
        return bell(unreadCount: snapshot.data ?? 0);
      },
    );
  }
}

class _AdminUiMetric extends StatelessWidget {
  const _AdminUiMetric({
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = AppTheme.primary,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 11),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _OverviewCard({
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _DashboardButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded, size: 21),