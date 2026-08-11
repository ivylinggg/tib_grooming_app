import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/participant.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../admin/assessment_detail_screen.dart';
import '../assessment/assessment_history_screen.dart';
import '../auth/login_screen.dart';
import '../checkin/checkin_screen.dart';

/// The FINAL personal dashboard in the Staff flow -- reached only from
/// ResultScreen's "Continue to Staff Dashboard" button, after a
/// grooming assessment completes. It is deliberately NOT where
/// RoleSelectionScreen sends a Staff account; that goes straight to the
/// Trainer Portal instead (see RoleSelectionScreen._checkExistingRole),
/// since the whole point of this app is that Staff perform a check-in
/// every time, not land on an empty dashboard.
///
/// "Staff ID" here is always the *real* one -- the identifier a person
/// types into themselves during Participant registration/Check-In
/// (Participant.staffId), kept in sync onto this account's
/// `users/{uid}.staffId` by AuthService.linkCurrentStaffToParticipant
/// every time this account completes an assessment. Nothing here ever
/// invents an ID: an account that has never completed a check-in shows
/// "Staff ID: Not registered", not a placeholder value.
///
/// Shows the account's most recent assessment (real Firestore data --
/// Overall Score, Result, Assessment Date -- with a "View Result"
/// button reusing Admin's AssessmentDetailScreen rather than a
/// duplicate result screen) or an empty state before the first one, and
/// a "Start New Check-In" button that sends the user back into
/// CheckInScreen to run another one -- the same account can check in
/// repeatedly, on different days, with different results.
class StaffDashboardScreen extends StatefulWidget {
  final AppUser user;

  const StaffDashboardScreen({super.key, required this.user});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  Participant? _participant;
  bool _loadingParticipant = true;

  @override
  void initState() {
    super.initState();
    _loadParticipant();
  }

  /// Looks up the Participant record this account's real Staff ID
  /// points to, so the profile section can show a reference photo and
  /// Trainer Name "if available" -- neither of which live on AppUser
  /// itself. Silently leaves [_participant] null if there's no Staff ID
  /// yet, or no matching record (e.g. it was deleted); the profile
  /// section already handles that with its own "if available" checks.
  Future<void> _loadParticipant() async {
    final staffId = widget.user.staffId;

    if (staffId == null || staffId.isEmpty) {
      setState(() {
        _loadingParticipant = false;
      });
      return;
    }

    final data = await _firebaseService.getParticipant(staffId);

    if (!mounted) return;

    setState(() {
      _participant = data == null ? null : Participant.fromJson(data);
      _loadingParticipant = false;
    });
  }

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context);

    await AuthService().signOut();

    if (!context.mounted) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _startNewCheckIn(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckInScreen()),
    );
  }

  void _viewHistory(BuildContext context) {
    final staffId = widget.user.staffId;
    if (staffId == null || staffId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssessmentHistoryScreen(
          participantId: staffId,
          participantName: widget.user.displayName,
        ),
      ),
    );
  }

  void _viewResult(BuildContext context, String assessmentId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssessmentDetailScreen(assessmentId: assessmentId),
      ),
    );
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt is! Timestamp) return "-";
    final date = createdAt.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final staffId = widget.user.staffId;
    final hasStaffId = staffId != null && staffId.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Staff Dashboard"),
        actions: [
          IconButton(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            tooltip: "Sign Out",
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileSection(hasStaffId, staffId),

              const SizedBox(height: 28),

              const Text(
                "Latest Grooming Result",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),

              const SizedBox(height: 12),

              if (!hasStaffId)
                const _EmptyResultCard(
                  message:
                      "No Staff ID on file yet. Complete a Check-In to "
                      "link one.",
                )
              else
                _buildLatestResult(staffId),

              if (hasStaffId) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _viewHistory(context),
                  icon: const Icon(Icons.history),
                  label: const Text("View Assessment History"),
                ),
              ],

              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: () => _startNewCheckIn(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Start New Check-In"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(bool hasStaffId, String? staffId) {
    final photoUrl = _participant?.photoUrl ?? "";
    final trainerName = _participant?.trainerName ?? "";

    return Column(
      children: [
        if (!_loadingParticipant && photoUrl.isNotEmpty)
          ClipOval(
            child: Image.network(
              photoUrl,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.badge_outlined,
                size: 64,
                color: AppTheme.primary,
              ),
            ),
          )
        else
          const Icon(Icons.badge_outlined, size: 64, color: AppTheme.primary),

        const SizedBox(height: 16),

        Text(
          "Welcome, ${widget.user.displayName}",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 6),

        Text(
          hasStaffId ? "Staff ID: $staffId" : "Staff ID: Not registered",
          style: const TextStyle(color: Colors.black54),
          textAlign: TextAlign.center,
        ),

        if (!_loadingParticipant && trainerName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            "Trainer: $trainerName",
            style: const TextStyle(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildLatestResult(String staffId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firebaseService.streamParticipantAssessments(staffId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const _EmptyResultCard(
            message: "Could not load your latest result right now.",
          );
        }

        final docs = [...snapshot.data?.docs ?? []];

        if (docs.isEmpty) {
          return const _EmptyResultCard(message: "No assessments yet.");
        }

        // streamParticipantAssessments() is a single-field `where` with
        // no `orderBy` (avoids requiring a Firestore composite index --
        // see its doc comment), so "latest" is sorted client-side here.
        docs.sort((a, b) {
          final aTime = a.data()["createdAt"];
          final bTime = b.data()["createdAt"];
          if (aTime is! Timestamp || bTime is! Timestamp) return 0;
          return bTime.compareTo(aTime);
        });

        final latestDoc = docs.first;
        final latest = latestDoc.data();
        final totalScore = latest["totalScore"] ?? 0;
        final overall = latest["overall"]?.toString() ?? "-";
        final dateText = _formatDate(latest["createdAt"]);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Overall Score: $totalScore%",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text("Result: $overall"),
                const SizedBox(height: 6),
                Text(
                  "Assessment Date: $dateText",
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () => _viewResult(context, latestDoc.id),
                    child: const Text("View Result"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyResultCard extends StatelessWidget {
  final String message;

  const _EmptyResultCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}
