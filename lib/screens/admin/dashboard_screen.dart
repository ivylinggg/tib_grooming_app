import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'participant_management_screen.dart';
import '../register/register_screen.dart';
import '../assessment/assessment_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int totalParticipants = 0;
  int totalAssessments = 0;

  double averageScore = 0;
  double passRate = 0;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    final participantSnapshot = await FirebaseFirestore.instance
        .collection("participants")
        .get();

    final assessmentSnapshot = await FirebaseFirestore.instance
        .collection("assessments")
        .get();

    totalParticipants = participantSnapshot.docs.length;

    totalAssessments = assessmentSnapshot.docs.length;

    if (assessmentSnapshot.docs.isNotEmpty) {
      int totalScore = 0;
      int pass = 0;

      for (final doc in assessmentSnapshot.docs) {
        final data = doc.data();

        totalScore += (data["score"] ?? 0) as int;

        if (data["result"] == "PASS") {
          pass++;
        }
      }

      averageScore = totalScore / assessmentSnapshot.docs.length;

      passRate = pass / assessmentSnapshot.docs.length * 100;
    }

    if (!mounted) return;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
      ),

      body: RefreshIndicator(
        onRefresh: loadDashboard,

        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.all(20),

          child: Column(
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
                      "Manage participants, AI grooming assessments and system records.",
                      style: TextStyle(color: Colors.white70, height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              Row(
                children: [
                  Expanded(
                    child: _OverviewCard(
                      title: "Participants",
                      value: "$totalParticipants",
                      icon: Icons.people,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: _OverviewCard(
                      title: "Assessments",
                      value: "$totalAssessments",
                      icon: Icons.fact_check,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: _OverviewCard(
                      title: "Average Score",
                      value: "${averageScore.toStringAsFixed(1)}%",
                      icon: Icons.analytics,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: _OverviewCard(
                      title: "Pass Rate",
                      value: "${passRate.toStringAsFixed(1)}%",
                      icon: Icons.verified,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
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
                icon: Icons.groups,
                title: "Participant Management",
                subtitle: "View, edit and search participants",
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
                icon: Icons.history,
                title: "Assessment List",
                subtitle: "Browse participant assessment records",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssessmentListScreen(),
                    ),
                  );
                },
              ),
              _DashboardButton(
                icon: Icons.bar_chart,
                title: "Statistics",
                subtitle: "Dashboard analytics and reports",
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) {
                      return AlertDialog(
                        title: const Text("Dashboard Statistics"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Participants : $totalParticipants"),

                            const SizedBox(height: 8),

                            Text("Assessments : $totalAssessments"),

                            const SizedBox(height: 8),

                            Text(
                              "Average Score : ${averageScore.toStringAsFixed(1)}%",
                            ),

                            const SizedBox(height: 8),

                            Text("Pass Rate : ${passRate.toStringAsFixed(1)}%"),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text("Close"),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              _DashboardButton(
                icon: Icons.logout,
                title: "Logout",
                subtitle: "Return to Login Screen",
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      height: 135,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1F3D73), size: 30),

          const SizedBox(height: 12),

          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
          ),

          const SizedBox(height: 4),

          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
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
