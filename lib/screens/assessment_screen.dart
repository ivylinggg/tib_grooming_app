import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

import '../models/assessment_result.dart';
import '../models/overall_result.dart';
import '../services/assessment_service.dart';

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
  final AssessmentService assessmentService = AssessmentService();

  Color _resultColor(String result) {
    switch (OverallResult.classify(result)) {
      case OverallResult.excellent:
        return AppTheme.primary;
      case OverallResult.good:
        return AppTheme.primary;
      case OverallResult.needsWork:
        return AppTheme.primary;
      case OverallResult.insufficient:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Grooming Assessment"),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.mutedSurface,
                child: Icon(Icons.person, color: AppTheme.primary),
              ),
              title: Text(
                widget.participantName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text("Staff ID : ${widget.participantId}"),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "AI Assessment Result",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text,
                ),
              ),
            ],
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
              subtitle: Text("${widget.assessmentResult.totalScore} / 60"),
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

          Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Assessment Details",
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ...widget.assessmentResult.criteria.map(
            (item) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.mutedSurface,
                  child: Icon(
                    Icons.check_circle_outline,
                    color: AppTheme.primary,
                  ),
                ),
                title: Text(
                  item.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(item.tip),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.mutedSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${item.score}/10",
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
            ),
            onPressed: () async {
              final score = widget.assessmentResult.totalScore;
              final result = widget.assessmentResult.overall;

              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              final success = await assessmentService.saveAssessment(
                participantId: widget.participantId,
                participantName: widget.participantName,
                result: widget.assessmentResult,
              );

              if (!mounted) return;

              if (!success) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("Failed to save assessment."),
                    backgroundColor: AppTheme.primary,
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
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _resultColor(result),
                              ),
                            ),

                            const SizedBox(height: 20),

                            const Text(
                              "Total Score",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              "$score / 60",
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
                      FilledButton(
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
