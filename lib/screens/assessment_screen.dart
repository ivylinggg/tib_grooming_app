import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';

class AssessmentScreen extends StatefulWidget {
  final String participantId;
  final String participantName;

  const AssessmentScreen({
    super.key,
    required this.participantId,
    required this.participantName,
  });

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final FirebaseService firebaseService = FirebaseService();

  bool hair = true;
  bool uniform = true;
  bool tie = true;
  bool shoes = true;
  bool nameTag = true;

  int calculateScore() {
    int score = 0;

    if (hair) score += 20;
    if (uniform) score += 20;
    if (tie) score += 20;
    if (shoes) score += 20;
    if (nameTag) score += 20;

    return score;
  }

  String getResult() {
    return calculateScore() >= 80 ? "PASS" : "FAIL";
  }

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
            "Assessment Checklist",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          SwitchListTile(
            title: const Text("Hair"),
            value: hair,
            onChanged: (value) {
              setState(() {
                hair = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text("Uniform"),
            value: uniform,
            onChanged: (value) {
              setState(() {
                uniform = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text("Tie / Scarf"),
            value: tie,
            onChanged: (value) {
              setState(() {
                tie = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text("Shoes"),
            value: shoes,
            onChanged: (value) {
              setState(() {
                shoes = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text("Name Tag"),
            value: nameTag,
            onChanged: (value) {
              setState(() {
                nameTag = value;
              });
            },
          ),

          const SizedBox(height: 30),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F3D73),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 55),
            ),
            onPressed: () async {
              final score = calculateScore();
              final result = getResult();

              final navigator = Navigator.of(context);

              await firebaseService.saveAssessment(
                participantId: widget.participantId,
                participantName: widget.participantName,
                score: score,
                result: result,
                hair: hair,
                uniform: uniform,
                tie: tie,
                shoes: shoes,
                nameTag: nameTag,
              );

              if (!mounted) return;

              showDialog(
                context: navigator.context,
                builder: (_) {
                  return AlertDialog(
                    title: const Text("Assessment Saved"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.participantName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 15),

                        Text(
                          "Score : $score%",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 15),

                        Text(
                          result,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: result == "PASS" ? Colors.green : Colors.red,
                          ),
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
