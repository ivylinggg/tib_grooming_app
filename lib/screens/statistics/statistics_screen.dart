import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int totalParticipants = 0;
  int totalAssessments = 0;

  int pass = 0;
  int fail = 0;

  double averageScore = 0;
  double passRate = 0;

  @override
  void initState() {
    super.initState();
    loadStatistics();
  }

  Future<void> loadStatistics() async {
    final participantSnapshot = await FirebaseFirestore.instance
        .collection("participants")
        .get();

    final assessmentSnapshot = await FirebaseFirestore.instance
        .collection("assessments")
        .get();

    totalParticipants = participantSnapshot.docs.length;

    totalAssessments = assessmentSnapshot.docs.length;

    int totalScore = 0;

    pass = 0;
    fail = 0;

    for (final doc in assessmentSnapshot.docs) {
      final data = doc.data();

      totalScore += (data["score"] ?? 0) as int;

      if (data["result"] == "PASS") {
        pass++;
      } else {
        fail++;
      }
    }

    if (assessmentSnapshot.docs.isNotEmpty) {
      averageScore = totalScore / assessmentSnapshot.docs.length;

      passRate = pass / assessmentSnapshot.docs.length * 100;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),

      appBar: AppBar(
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text("Statistics"),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatisticCard(
                    title: "Participants",
                    value: "$totalParticipants",
                    icon: Icons.people,
                  ),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: _StatisticCard(
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
                  child: _StatisticCard(
                    title: "Average Score",
                    value: "${averageScore.toStringAsFixed(1)}%",
                    icon: Icons.analytics,
                  ),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: _StatisticCard(
                    title: "Pass Rate",
                    value: "${passRate.toStringAsFixed(1)}%",
                    icon: Icons.verified,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            Card(
              elevation: 3,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),

              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Column(
                  children: [
                    const Text(
                      "Pass vs Fail",

                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      height: 220,

                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: pass.toDouble(),
                              title: "PASS\n$pass",
                              color: Colors.green,
                              radius: 70,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            PieChartSectionData(
                              value: fail.toDouble(),
                              title: "FAIL\n$fail",
                              color: Colors.red,
                              radius: 70,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],

                          centerSpaceRadius: 40,
                          sectionsSpace: 4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          children: const [
                            CircleAvatar(
                              radius: 7,
                              backgroundColor: Colors.green,
                            ),

                            SizedBox(width: 8),

                            Text("PASS"),
                          ],
                        ),

                        Row(
                          children: const [
                            CircleAvatar(
                              radius: 7,
                              backgroundColor: Colors.red,
                            ),

                            SizedBox(width: 8),

                            Text("FAIL"),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            Card(
              elevation: 3,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),

              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      "Assessment Summary",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text("Total Participants : $totalParticipants"),

                    const SizedBox(height: 10),

                    Text("Total Assessments : $totalAssessments"),

                    const SizedBox(height: 10),

                    Text("PASS : $pass"),

                    const SizedBox(height: 10),

                    Text("FAIL : $fail"),

                    const SizedBox(height: 10),

                    Text("Average Score : ${averageScore.toStringAsFixed(1)}%"),

                    const SizedBox(height: 10),

                    Text("Pass Rate : ${passRate.toStringAsFixed(1)}%"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      "Pass / Fail Overview",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      height: 250,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (pass > fail ? pass : fail).toDouble() + 2,
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  switch (value.toInt()) {
                                    case 0:
                                      return const Text("PASS");
                                    case 1:
                                      return const Text("FAIL");
                                    default:
                                      return const SizedBox();
                                  }
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: true),
                          barGroups: [
                            BarChartGroupData(
                              x: 0,
                              barRods: [
                                BarChartRodData(
                                  toY: pass.toDouble(),
                                  color: Colors.green,
                                  width: 30,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ],
                            ),
                            BarChartGroupData(
                              x: 1,
                              barRods: [
                                BarChartRodData(
                                  toY: fail.toDouble(),
                                  color: Colors.red,
                                  width: 30,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _StatisticCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatisticCard({
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
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
