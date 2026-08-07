import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/firebase_service.dart';

class AssessmentHistoryScreen extends StatelessWidget {
  final String participantId;
  final String participantName;

  const AssessmentHistoryScreen({
    super.key,
    required this.participantId,
    required this.participantName,
  });

  Color _resultColor(String result) {
    switch (result.toLowerCase()) {
      case "excellent":
        return Colors.green;

      case "good":
        return Colors.blue;

      case "fair":
        return Colors.orange;

      default:
        return Colors.red;
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "-";

    final date = timestamp.toDate();

    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
        title: const Text(
          "Assessment History",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1F3D73),
            ),

            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    size: 42,
                    color: Color(0xFF1F3D73),
                  ),
                ),

                const SizedBox(height: 15),

                Text(
                  participantName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  participantId,
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firebaseService.streamParticipantAssessments(
                participantId,
              ),

              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(snapshot.error.toString()),
                  );
                }

                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No Assessment History",
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,

                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    final score = (data["score"] ?? 0) as int;
                    final result =
                        data["result"]?.toString() ?? "-";

                    final date = _formatDate(
                      data["createdAt"] as Timestamp?,
                    );

                    return Card(
                      elevation: 4,
                      margin:
                          const EdgeInsets.only(bottom: 20),

                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(20),
                      ),

                      child: Padding(
                        padding:
                            const EdgeInsets.all(20),

                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor:
                                      const Color(
                                    0xFF1F3D73,
                                  ),

                                  child: const Icon(
                                    Icons.assignment,
                                    color: Colors.white,
                                  ),
                                ),

                                const SizedBox(width: 15),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,

                                    children: [
                                      Text(
                                        date,
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                          fontSize: 16,
                                        ),
                                      ),

                                      const SizedBox(
                                        height: 4,
                                      ),

                                      const Text(
                                        "Assessment Record",
                                        style: TextStyle(
                                          color:
                                              Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),

                                  decoration:
                                      BoxDecoration(
                                    color: _resultColor(
                                      result,
                                    ).withValues(
                                      alpha: 0.15,
                                    ),

                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      30,
                                    ),
                                  ),

                                  child: Text(
                                    "$score%",
                                    style: TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      color:
                                          _resultColor(
                                        result,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                                                        Row(
                              children: [
                                const Text(
                                  "Result",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),

                                const Spacer(),

                                Chip(
                                  backgroundColor:
                                      _resultColor(result),

                                  label: Text(
                                    result,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.visibility,
                                    ),

                                    label: const Text(
                                      "Details",
                                    ),

                                    style:
                                        ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(
                                        0xFF1F3D73,
                                      ),
                                      foregroundColor:
                                          Colors.white,
                                    ),

                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) {
                                          return AlertDialog(
                                            title: const Text(
                                              "Assessment Details",
                                            ),

                                            content:
                                                SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize:
                                                    MainAxisSize
                                                        .min,

                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,

                                                children: [
                                                  Text(
                                                    participantName,
                                                    style:
                                                        const TextStyle(
                                                      fontWeight:
                                                          FontWeight
                                                              .bold,
                                                      fontSize:
                                                          18,
                                                    ),
                                                  ),

                                                  const SizedBox(
                                                    height: 18,
                                                  ),

                                                  Text(
                                                    "Date : $date",
                                                  ),

                                                  Text(
                                                    "Score : $score%",
                                                  ),

                                                  Text(
                                                    "Result : $result",
                                                  ),

                                                  const Divider(
                                                    height: 30,
                                                  ),

                                                  _buildItem(
                                                    "Hair",
                                                    data["hair"] ==
                                                        true,
                                                  ),

                                                  _buildItem(
                                                    "Uniform",
                                                    data["uniform"] ==
                                                        true,
                                                  ),

                                                  _buildItem(
                                                    "Tie",
                                                    data["tie"] ==
                                                        true,
                                                  ),

                                                  _buildItem(
                                                    "Shoes",
                                                    data["shoes"] ==
                                                        true,
                                                  ),

                                                  _buildItem(
                                                    "Name Tag",
                                                    data["nameTag"] ==
                                                        true,
                                                  ),
                                                ],
                                              ),
                                            ),

                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(
                                                      context);
                                                },

                                                child: const Text(
                                                  "Close",
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.delete,
                                    ),

                                    label: const Text(
                                      "Delete",
                                    ),

                                    style:
                                        ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.red,
                                      foregroundColor:
                                          Colors.white,
                                    ),

                                    onPressed: () async {
                                      final confirm =
                                          await showDialog<bool>(
                                        context: context,
                                        builder: (_) =>
                                            AlertDialog(
                                          title: const Text(
                                              "Delete Assessment"),
                                          content: const Text(
                                            "Are you sure you want to delete this assessment?",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      context,
                                                      false),
                                              child: const Text(
                                                  "Cancel"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      context,
                                                      true),
                                              child: const Text(
                                                  "Delete"),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm != true) {
                                        return;
                                      }

                                      await firebaseService
                                          .deleteAssessment(
                                              doc.id);

                                      if (!context.mounted) {
                                        return;
                                      }

                                      ScaffoldMessenger.of(
                                              context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Assessment deleted successfully",
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      ),
                    );
                  },
                              );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(String title, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
              ),
            ),
          ),
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }
}