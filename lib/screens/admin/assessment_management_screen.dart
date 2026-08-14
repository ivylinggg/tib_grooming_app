import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/overall_result.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';
import 'assessment_detail_screen.dart';

/// Admin's flat list of every grooming assessment record across every
/// Participant -- distinct from the existing AssessmentListScreen,
/// which lists Participants by their *latest* result, not individual
/// assessment records. Uses FirebaseService.streamAllAssessments (the
/// existing `assessments` collection, unfiltered by participant).
class AssessmentManagementScreen extends StatefulWidget {
  const AssessmentManagementScreen({super.key});

  @override
  State<AssessmentManagementScreen> createState() =>
      _AssessmentManagementScreenState();
}

class _AssessmentManagementScreenState
    extends State<AssessmentManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  bool _checkingAccess = true;

  String _keyword = "";
  String _statusFilter = "All";
  DateTime? _fromDate;
  DateTime? _toDate;

  static const _statusOptions = [
    "All",
    "Excellent",
    "Good",
    "Needs Work",
    "Insufficient",
  ];

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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "-";
    final date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final keyword = _keyword.trim().toLowerCase();

    return docs.where((doc) {
      final data = doc.data();

      final name = (data["participantName"] ?? "").toString().toLowerCase();
      final staffId = (data["participantId"] ?? "").toString().toLowerCase();
      final overall = (data["overall"] ?? "").toString();

      if (keyword.isNotEmpty &&
          !name.contains(keyword) &&
          !staffId.contains(keyword)) {
        return false;
      }

      if (_statusFilter != "All" &&
          OverallResult.classify(overall) !=
              OverallResult.classify(_statusFilter)) {
        return false;
      }

      final createdAt = data["createdAt"] as Timestamp?;

      if (createdAt != null) {
        final date = createdAt.toDate();

        if (_fromDate != null &&
            date.isBefore(
              DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day),
            )) {
          return false;
        }

        if (_toDate != null &&
            date.isAfter(
              DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59),
            )) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );

    if (range == null) return;

    setState(() {
      _fromDate = range.start;
      _toDate = range.end;
    });
  }

  void _clearDateRange() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
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
        title: const Text("Assessment Management"),
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _keyword = value),
              decoration: InputDecoration(
                hintText: "Search by participant name or Staff ID",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    decoration: InputDecoration(
                      labelText: "Status",
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _statusOptions
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _statusFilter = value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _fromDate != null && _toDate != null
                        ? "${_fromDate!.day}/${_fromDate!.month} - "
                              "${_toDate!.day}/${_toDate!.month}"
                        : "Date",
                  ),
                ),
                if (_fromDate != null || _toDate != null)
                  IconButton(
                    onPressed: _clearDateRange,
                    icon: const Icon(Icons.close),
                    tooltip: "Clear date filter",
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firebaseService.streamAllAssessments(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Could not load assessments.\n${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];

                if (allDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No assessment records yet",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                final docs = _applyFilters(allDocs);

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No assessments match your search/filter",
                      style: TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    final name = data["participantName"]?.toString() ?? "-";
                    final staffId = data["participantId"]?.toString() ?? "-";
                    final score = (data["totalScore"] ?? 0) as int;
                    final overall = data["overall"]?.toString() ?? "-";
                    final date = _formatDate(data["createdAt"] as Timestamp?);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1F3D73),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : "?",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Staff ID: $staffId  •  $date"),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "$score/60",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _resultColor(overall),
                              ),
                            ),
                            Text(
                              overall,
                              style: TextStyle(
                                fontSize: 11,
                                color: _resultColor(overall),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AssessmentDetailScreen(assessmentId: doc.id),
                            ),
                          );
                        },
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
}
