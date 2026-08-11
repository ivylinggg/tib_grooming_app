import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/overall_result.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';
import '../register/register_screen.dart';
import 'assessment_detail_screen.dart';
import 'assessment_management_screen.dart';
import 'participant_management_screen.dart';
import 'participant_profile_screen.dart';
import 'staff_management_screen.dart';
import 'staff_profile_screen.dart';
import 'statistics_screen.dart';

/// Admin's home screen. Only ever reached from RoleSelectionScreen's
/// Admin choice, but that alone doesn't prove the *current* session is
/// still Admin -- role can change between sessions, and this screen can
/// be re-entered via the navigator stack -- so [initState] re-checks the
/// actual `users/{uid}` role on every load rather than trusting how the
/// screen was reached. See [_checkAdminAccess].
///
/// "Staff" and "Participant" are two distinct entities, not two labels
/// for the same headcount:
///  - Staff = a Firebase Auth login account with `role: "staff"` on its
///    `users/{uid}` doc -- the person operating the app (Trainer
///    Portal, Participant Check-In). Counted from the `users`
///    collection.
///  - Participant = a crew member being groomed/assessed, stored in
///    `participants/{staffId}`, with no login of their own. Counted
///    from the `participants` collection.
/// The two counts can differ and both are shown separately below.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();

  bool _checkingAccess = true;

  int totalStaff = 0;
  int totalParticipants = 0;
  int totalAssessments = 0;
  int completedAssessments = 0;
  int pendingAssessments = 0;

  double averageScore = 0;

  bool _loadingStats = true;
  String? _statsError;

  /// Kept separate from [_statsError]: this project has no
  /// firestore.rules file checked into the repo, so whether Admin is
  /// actually allowed to read the whole `users` collection depends on
  /// live Firebase Console rules this app has no visibility into. If
  /// that query comes back permission-denied, it shouldn't blank out
  /// the participant/assessment stats that loaded fine.
  String? _staffCountError;

  List<Map<String, dynamic>> _recentParticipants = [];
  List<Map<String, dynamic>> _recentAssessments = [];
  List<AppUser> _recentStaff = [];
  bool _loadingActivity = true;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  /// Role-based route guard: signed out -> Login. Signed in but not
  /// Admin (Staff, or a role-less/pending account) -> Role Selection,
  /// same landing point every other non-Admin path already uses. Only
  /// a confirmed `role: admin` account ever proceeds to load dashboard
  /// data -- hiding admin-only buttons elsewhere is not enough on its
  /// own, so this checks the actual stored role, not just "is someone
  /// signed in".
  Future<void> _checkAdminAccess() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    AppUser? appUser;
    try {
      appUser = await _authService.getCurrentAppUser();
    } catch (e) {
      debugPrint("DashboardScreen: role check failed - $e");
    }

    if (!mounted) return;

    if (appUser == null || appUser.role != UserRole.admin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      );
      return;
    }

    setState(() {
      _checkingAccess = false;
    });

    loadDashboard();
  }

  Future<void> loadDashboard() async {
    setState(() {
      _loadingStats = true;
      _statsError = null;
      _staffCountError = null;
    });

    // Staff (Firebase Auth login accounts with role: staff, in
    // `users/{uid}`) is queried separately from participants/assessments
    // -- it's a genuinely different collection representing a different
    // entity (see the class doc comment), not the same headcount under
    // a different label, and a failure here shouldn't block the rest of
    // the dashboard.
    try {
      final staffSnapshot = await FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "staff")
          .get();

      totalStaff = staffSnapshot.docs.length;
    } catch (e) {
      debugPrint("DashboardScreen: staff count query failed - $e");
      if (mounted) {
        setState(() {
          _staffCountError = "Could not load Staff count.";
        });
      }
    }

    try {
      final participantSnapshot = await FirebaseFirestore.instance
          .collection("participants")
          .get();

      final assessmentSnapshot = await FirebaseFirestore.instance
          .collection("assessments")
          .get();

      totalParticipants = participantSnapshot.docs.length;
      totalAssessments = assessmentSnapshot.docs.length;

      // A participant counts as "completed" once they have at least one
      // saved assessment (assessmentCount, kept in sync by
      // FirebaseService.saveAssessment on every successful save) --
      // "pending" is everyone still waiting on their first one. This is
      // real, derived data, not a status field that has to be invented.
      int completed = 0;
      for (final doc in participantSnapshot.docs) {
        final count = (doc.data()["assessmentCount"] ?? 0) as int;
        if (count > 0) completed++;
      }
      completedAssessments = completed;
      pendingAssessments = totalParticipants - completed;

      if (assessmentSnapshot.docs.isNotEmpty) {
        int totalScore = 0;

        for (final doc in assessmentSnapshot.docs) {
          final data = doc.data();
          // Matches the field name saveAssessment() actually writes.
          totalScore += (data["totalScore"] ?? 0) as int;
        }

        averageScore = totalScore / assessmentSnapshot.docs.length;
      } else {
        averageScore = 0;
      }
    } catch (e) {
      debugPrint("DashboardScreen: loadDashboard failed - $e");
      if (!mounted) return;
      setState(() {
        _statsError = "Could not load dashboard statistics.";
      });
    }

    if (!mounted) return;

    setState(() {
      _loadingStats = false;
    });

    _loadRecentActivity();
  }

  Future<void> _loadRecentActivity() async {
    setState(() {
      _loadingActivity = true;
    });

    try {
      final recentParticipants = await _firebaseService.getRecentParticipants(
        limit: 5,
      );
      final recentAssessments = await _firebaseService.getRecentAssessments(
        limit: 5,
      );

      // Sorted client-side rather than adding `.orderBy("createdAt")`
      // to AuthService.getAllStaff's `where("role", ...)` query --
      // combining a where-filter with an orderBy on a *different*
      // field requires a Firestore composite index that doesn't exist
      // for this collection, which would fail at runtime instead of
      // compile time. Sorting the already-fetched list avoids that.
      final allStaff = await _authService.getAllStaff();
      allStaff.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        _recentParticipants = recentParticipants;
        _recentAssessments = recentAssessments;
        _recentStaff = allStaff.take(5).toList();
        _loadingActivity = false;
      });
    } catch (e) {
      debugPrint("DashboardScreen: loadRecentActivity failed - $e");
      if (!mounted) return;
      setState(() {
        _loadingActivity = false;
      });
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Firebase Auth session only -- does not touch Firestore data or
    // remembered "Remember me" credentials, same contract as
    // TopNavigation's logout for the Staff side.
    await _authService.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Color _resultColor(String result) {
    switch (OverallResult.classify(result)) {
      case OverallResult.excellent:
        return Colors.green;
      case OverallResult.good:
        return Colors.blue;
      case OverallResult.needsWork:
        return Colors.orange;
      case OverallResult.insufficient:
        return Colors.red;
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "-";
    final date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Unknown";
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F6F1),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
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
                  color: const Color(0xFF1F3D73),
                  borderRadius: BorderRadius.circular(20),
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
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statsError!,
                          style: const TextStyle(color: Colors.red),
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
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_outlined,
                        color: Colors.orange,
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
                        value: "${averageScore.toStringAsFixed(1)}%",
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
}

/// Never gives itself a fixed height -- the previous version's fixed
/// `height: 135` was the exact cause of the "BOTTOM OVERFLOWED" errors:
/// any title long enough to wrap to two lines, or any device text-scale
/// setting above 1.0x, pushed content past that fixed box. Sizing to
/// content with `mainAxisSize: MainAxisSize.min` instead means the card
/// grows with its content and can never overflow itself.
class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _OverviewCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1F3D73), size: 28),

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
            style: const TextStyle(color: Colors.black54, fontSize: 13),
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
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1F3D73),
          child: Icon(icon, color: Colors.white),
        ),

        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),

        subtitle: Text(subtitle),

        trailing: const Icon(Icons.arrow_forward_ios, size: 18),

        onTap: onTap,
      ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isEmpty;
  final String emptyText;
  final List<Widget> children;

  const _RecentActivitySection({
    required this.title,
    required this.icon,
    required this.isEmpty,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF1F3D73), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  emptyText,
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}
