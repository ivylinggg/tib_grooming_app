import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AssessmentHistoryScreen extends StatelessWidget {
  const AssessmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),

      appBar: AppBar(
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text("Assessment History"),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("assessments")
            .orderBy("createdAt", descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No assessment records."));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final score = data["score"] ?? 0;

              final result = data["result"] ?? "";

              final participant = data["participantName"] ?? "";

              final staff = data["participantId"] ?? "";

              final time = data["createdAt"];

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: result == "PASS"
                        ? Colors.green
                        : Colors.red,

                    child: Icon(
                      result == "PASS" ? Icons.check : Icons.close,
                      color: Colors.white,
                    ),
                  ),

                  title: Text(
                    participant,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Staff ID : $staff"),

                      Text("Score : $score%"),

                      Text("Result : $result"),

                      if (time != null)
                        Text(
                          (time as Timestamp).toDate().toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: Chip(
                    backgroundColor: result == "PASS"
                        ? Colors.green
                        : Colors.red,
                    label: Text(
                      result,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) {
                        return AlertDialog(
                          title: const Text("Assessment Details"),

                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Participant : $participant"),

                                Text("Staff ID : $staff"),

                                const Divider(),

                                ListTile(
                                  dense: true,
                                  leading: Icon(
                                    (data["hair"] ?? false)
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: (data["hair"] ?? false)
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  title: const Text("Hair"),
                                ),

                                ListTile(
                                  dense: true,
                                  leading: Icon(
                                    (data["uniform"] ?? false)
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: (data["uniform"] ?? false)
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  title: const Text("Uniform"),
                                ),

                                ListTile(
                                  dense: true,
                                  leading: Icon(
                                    (data["tie"] ?? false)
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: (data["tie"] ?? false)
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  title: const Text("Tie / Scarf"),
                                ),

                                ListTile(
                                  dense: true,
                                  leading: Icon(
                                    (data["shoes"] ?? false)
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: (data["shoes"] ?? false)
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  title: const Text("Shoes"),
                                ),

                                ListTile(
                                  dense: true,
                                  leading: Icon(
                                    (data["nameTag"] ?? false)
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: (data["nameTag"] ?? false)
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  title: const Text("Name Tag"),
                                ),

                                const Divider(),

                                Text(
                                  "Final Score : $score%",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                Text(
                                  "Result : $result",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: result == "PASS"
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
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
              );
            },
          );
        },
      ),
    );
  }
}
