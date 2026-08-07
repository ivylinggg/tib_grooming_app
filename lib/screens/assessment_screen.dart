import 'package:flutter/material.dart';
import '../../models/assessment_result.dart';
import '../../services/firebase_service.dart';

class AssessmentScreen extends StatefulWidget {
  final String participantId;
  final String participantName;
  final AssessmentResult assessmentResult;

  const AssessmentScreen({
    super.key,
    required this.participantId,
    required this.participantName,
    required this.assessmentResult,
  });

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final FirebaseService firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Grooming Assessment"),
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(widget.participantName),
              subtitle: Text("Staff ID : ${widget.participantId}"),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "AI Assessment Result",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          Card(
            child: ListTile(
              leading: const Icon(Icons.verified),
              title: const Text("Overall"),
              subtitle: Text(widget.assessmentResult.overall),
            ),
          ),

          const SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: const Icon(Icons.score),
              title: const Text("Total Score"),
              subtitle: Text("${widget.assessmentResult.totalScore} / 100"),
            ),
          ),

          const SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: const Icon(Icons.description),
              title: const Text("Summary"),
              subtitle: Text(widget.assessmentResult.summary),
            ),
          ),

          const SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: const Icon(Icons.tips_and_updates),
              title: const Text("Suggestion"),
              subtitle: Text(widget.assessmentResult.suggestion),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Assessment Details",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          ...widget.assessmentResult.criteria.map(
            (item) => Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),

                title: Text(item.label),

                subtitle: Text(item.tip),

                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: item.score >= 8
                        ? Colors.green.shade100
                        : item.score >= 5
                        ? Colors.orange.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${item.score}/10",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F3D73),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 55),
            ),
            onPressed: () async {
              final score = widget.assessmentResult.totalScore;
              final result = widget.assessmentResult.overall;

              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              final success = await firebaseService.saveAssessment(
                participantId: widget.participantId,
                participantName: widget.participantName,

                totalScore: score,
                overall: result,

                summary: widget.assessmentResult.summary,
                suggestion: widget.assessmentResult.suggestion,
                referencePhotoUrl:
                    widget.assessmentResult.referencePhotoUrl ?? "",
                todayPhotoUrl: widget.assessmentResult.todayPhotoUrl ?? "",

                criteria: widget.assessmentResult.criteria
                    .map(
                      (e) => {"label": e.label, "score": e.score, "tip": e.tip},
                    )
                    .toList(),
              );

              if (!mounted) return;

              if (!success) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("Failed to save assessment."),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              showDialog(
                context: navigator.context,
                builder: (_) {
                  return AlertDialog(
                    title: const Text("AI Assessment Completed"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.participantName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 15),

                        Column(
                          children: [
                            const Text(
                              "Overall",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              result,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),

                            const SizedBox(height: 20),

                            const Text(
                              "Total Score",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              "$score / 100",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: const Text("OK"),
                      ),
                    ],
                  );
                },
              );
            },
            child: const Text("Submit Assessment"),
          ),
        ],
      ),
    );
  }
}
