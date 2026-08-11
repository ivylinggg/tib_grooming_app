import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/overall_result.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';

/// Admin's analytics screen -- real Firestore data only, no placeholder
/// numbers. Uses hand-drawn bar rows (plain Container widgets sized by
/// percentage) rather than the fl_chart package: fl_chart is listed in
/// pubspec.yaml but isn't used anywhere else in this app yet, and its
/// exact widget API can't be verified against the pinned version from
/// this sandbox (no Flutter toolchain available to compile against --
/// see the project's standing constraint). A wrong constructor
/// parameter would break this whole screen. Plain Containers carry no
/// such risk and still satisfy "show simple charts, not just a list of
/// numbers".
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final AuthService _authService = AuthService();

  bool _checkingAccess = true;
  bool _loading = true;
  String? _error;

  int _totalStaff = 0;
  int _totalParticipants = 0;
  int _totalAssessments = 0;
  int _completed = 0;
  int _pending = 0;
  double _averageScore = 0;

  final Map<String, int> _overallCounts = {
    "Excellent": 0,
    "Good": 0,
    "Needs Work": 0,
    "Insufficient": 0,
  };

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

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
    } catch (_) {}

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

    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final staffSnapshot = await FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "staff")
          .get();

      final participantSnapshot = await FirebaseFirestore.instance
          .collection("participants")
          .get();

      final assessmentSnapshot = await FirebaseFirestore.instance
          .collection("assessments")
          .get();

      _totalStaff = staffSnapshot.docs.length;
      _totalParticipants = participantSnapshot.docs.length;
      _totalAssessments = assessmentSnapshot.docs.length;

      int completed = 0;
      for (final doc in participantSnapshot.docs) {
        final count = (doc.data()["assessmentCount"] ?? 0) as int;
        if (count > 0) completed++;
      }
      _completed = completed;
      _pending = _totalParticipants - completed;

      _overallCounts.updateAll((key, value) => 0);

      if (assessmentSnapshot.docs.isNotEmpty) {
        int totalScore = 0;

        for (final doc in assessmentSnapshot.docs) {
          final data = doc.data();
          totalScore += (data["totalScore"] ?? 0) as int;

          final overall = data["overall"]?.toString() ?? "";
          final classified = OverallResult.classify(overall);

          switch (classified) {
            case OverallResult.excellent:
              _overallCounts["Excellent"] = _overallCounts["Excellent"]! + 1;
              break;
            case OverallResult.good:
              _overallCounts["Good"] = _overallCounts["Good"]! + 1;
              break;
            case OverallResult.needsWork:
              _overallCounts["Needs Work"] = _overallCounts["Needs Work"]! + 1;
              break;
            case OverallResult.insufficient:
              _overallCounts["Insufficient"] =
                  _overallCounts["Insufficient"]! + 1;
              break;
          }
        }

        _averageScore = totalScore / assessmentSnapshot.docs.length;
      } else {
        _averageScore = 0;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Could not load statistics.";
      });
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  Color _resultColor(String label) {
    switch (label) {
      case "Excellent":
        return Colors.green;
      case "Good":
        return Colors.blue;
      case "Needs Work":
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Statistics"),
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadStats, child: const Text("Retry")),
            ],
          ),
        ),
      );
    }

    final completionRate = _totalParticipants == 0
        ? 0.0
        : _completed / _totalParticipants;

    final maxOverallCount = _overallCounts.values.isEmpty
        ? 0
        : _overallCounts.values.reduce((a, b) => a > b ? a : b);

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "System Overview",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: "Total Staff",
                    value: "$_totalStaff",
                    icon: Icons.badge,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: "Total Participants",
                    value: "$_totalParticipants",
                    icon: Icons.people,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: "Total Assessments",
                    value: "$_totalAssessments",
                    icon: Icons.fact_check,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: "Average Score",
                    value: "${_averageScore.toStringAsFixed(1)}%",
                    icon: Icons.analytics,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              "Assessment Completion",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "$_completed of $_totalParticipants Participants "
                          "assessed",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          "${(completionRate * 100).toStringAsFixed(0)}%",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F3D73),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: completionRate,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                        color: const Color(0xFF1F3D73),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "$_pending Participant(s) still pending their first "
                      "assessment.",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "Grooming Performance Breakdown",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _totalAssessments == 0
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            "No assessment records yet",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _overallCounts.entries.map((entry) {
                          final fraction = maxOverallCount == 0
                              ? 0.0
                              : entry.value / maxOverallCount;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "${entry.value}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _resultColor(entry.key),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Stack(
                                      children: [
                                        Container(
                                          height: 10,
                                          width: constraints.maxWidth,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          height: 10,
                                          width:
                                              constraints.maxWidth * fraction,
                                          decoration: BoxDecoration(
                                            color: _resultColor(entry.key),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1F3D73), size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
