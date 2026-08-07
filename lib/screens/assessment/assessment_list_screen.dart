import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';
import 'assessment_history_screen.dart';

class AssessmentListScreen extends StatefulWidget {
  const AssessmentListScreen({super.key});

  @override
  State<AssessmentListScreen> createState() => _AssessmentListScreenState();
}

class _AssessmentListScreenState extends State<AssessmentListScreen> {
  final FirebaseService firebaseService = FirebaseService();

  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> participants = [];
  List<Map<String, dynamic>> filteredParticipants = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadParticipants();
  }

  Future<void> loadParticipants() async {
    final data = await firebaseService.getAllParticipants();

    setState(() {
      participants = data;
      filteredParticipants = data;
      loading = false;
    });
  }

  void searchParticipant(String keyword) {
    if (keyword.trim().isEmpty) {
      setState(() {
        filteredParticipants = participants;
      });
      return;
    }

    final lower = keyword.toLowerCase();

    setState(() {
      filteredParticipants = participants.where((participant) {
        final staff = (participant["staff"] ?? "").toString().toLowerCase();

        final name = (participant["name"] ?? "").toString().toLowerCase();

        return staff.contains(lower) || name.contains(lower);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assessment List"),
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    onChanged: searchParticipant,
                    decoration: InputDecoration(
                      hintText: "Search Staff ID or Name",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: filteredParticipants.isEmpty
                      ? const Center(
                          child: Text(
                            "No participant found",
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredParticipants.length,
                          itemBuilder: (context, index) {
                            final participant = filteredParticipants[index];

                            final staff = participant["staff"] ?? "";

                            final name = participant["name"] ?? "";

                            final trainer = participant["trainer"] ?? "";

                            final latestScore =
                                participant["latestScore"] ?? "-";

                            final latestResult =
                                participant["latestResult"] ?? "No Assessment";

                            final assessmentCount =
                                participant["assessmentCount"] ?? 0;

                            final Timestamp? lastAssessment =
                                participant["lastAssessmentDate"];

                            String lastAssessmentDate = "-";

                            if (lastAssessment != null) {
                              final date = lastAssessment.toDate();

                              lastAssessmentDate =
                                  "${date.day}/${date.month}/${date.year}";
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 14),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: const Color(0xFF1F3D73),

                                  child: Text(
                                    name.toString().isNotEmpty
                                        ? name.toString()[0].toUpperCase()
                                        : "?",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),

                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("Staff ID : $staff"),
                                      const SizedBox(height: 4),

                                      Text("Trainer : $trainer"),
                                      const SizedBox(height: 4),

                                      Text("Latest Score : $latestScore%"),
                                      const SizedBox(height: 4),

                                      Text(
                                        "Latest Result : $latestResult",
                                        style: TextStyle(
                                          color: latestResult == "PASS"
                                              ? Colors.green
                                              : latestResult == "FAIL"
                                              ? Colors.red
                                              : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      Text(
                                        "Assessment Count : $assessmentCount",
                                      ),
                                      const SizedBox(height: 4),

                                      Text(
                                        "Last Assessment : $lastAssessmentDate",
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: ElevatedButton.icon(
                                  icon: const Icon(Icons.history),
                                  label: const Text("View"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1F3D73),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AssessmentHistoryScreen(
                                          participantId: staff,
                                          participantName: name,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
