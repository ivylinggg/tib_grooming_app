import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/overall_result.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';

/// Full read view of one grooming assessment record -- every field the
/// existing AssessmentResult/saveAssessment contract actually produces:
/// participant info, score, overall result, per-criterion breakdown, AI
/// summary, and both photos where available. Nothing invented beyond
/// what FirebaseService.saveAssessment writes.
///
/// Dual audience, reused rather than duplicated for
/// StaffDashboardScreen's "View Result" button:
/// - An Admin account may view any assessment.
/// - A signed-in Staff account may view only the one assessment whose
///   `participantId` matches their own linked `users/{uid}.staffId`
///   (see AuthService.linkCurrentStaffToParticipant) -- checked in
///   [_load], after the data is fetched, not just at the initial role
///   check, since the initial check alone can't know which assessment
///   this is yet.
/// - Anyone else (not signed in, or a role-less/pending account) is
///   redirected away before any assessment data is fetched at all --
///   reachability through the UI is not access control (see
///   ParticipantManagementScreen._checkAdminAccess's doc comment for
///   the same reasoning applied to every other Admin screen).
///
/// Deleting a record stays Admin-only -- the delete action is hidden
/// entirely for a Staff viewer, regardless of whose assessment it is.
class AssessmentDetailScreen extends StatefulWidget {
  final String assessmentId;

  const AssessmentDetailScreen({super.key, required this.assessmentId});

  @override
  State<AssessmentDetailScreen> createState() => _AssessmentDetailScreenState();
}

class _AssessmentDetailScreenState extends State<AssessmentDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();

  bool _checkingAccess = true;

  /// Set once [_checkAccess] resolves. True for a confirmed Admin
  /// account; false for a confirmed Staff account viewing their own
  /// assessment. Controls whether the delete action is shown at all.
  bool _isAdmin = false;

  /// The signed-in Staff viewer's own real Staff ID, used in [_load] to
  /// verify this assessment is actually theirs. Null/unused for an
  /// Admin viewer.
  String? _viewerStaffId;

  Map<String, dynamic>? _assessment;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  /// Not-signed-in -> Login. Signed-in but role-less/pending -> Role
  /// Selection (fail closed, same as every other Admin screen). Admin
  /// and Staff both pass this initial check -- which one determines
  /// what [_load] is allowed to show once the data comes back.
  Future<void> _checkAccess() async {
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
    } catch (_) {
      // Falls through to the role check below, which treats a failed
      // lookup the same as "not allowed" -- fail closed, not open.
    }

    if (!mounted) return;

    if (appUser == null ||
        (appUser.role != UserRole.admin && appUser.role != UserRole.staff)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      );
      return;
    }

    setState(() {
      _isAdmin = appUser!.role == UserRole.admin;
      _viewerStaffId = appUser.staffId;
      _checkingAccess = false;
    });

    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final data = await _firebaseService.getAssessmentById(widget.assessmentId);

    if (!mounted) return;

    if (data == null) {
      setState(() {
        _error = "This assessment record no longer exists.";
        _loading = false;
      });
      return;
    }

    // A Staff viewer may only see their own assessment -- never guessed,
    // never partially shown. An Admin viewer skips this check entirely.
    if (!_isAdmin) {
      final ownerStaffId = data["participantId"]?.toString() ?? "";
      final viewerStaffId = _viewerStaffId ?? "";

      if (viewerStaffId.isEmpty || ownerStaffId != viewerStaffId) {
        setState(() {
          _error = "You do not have permission to view this assessment.";
          _loading = false;
        });
        return;
      }
    }

    setState(() {
      _assessment = data;
      _loading = false;
    });
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

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Assessment"),
        content: const Text(
          "Are you sure you want to delete this assessment? This "
          "cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await _firebaseService.deleteAssessment(widget.assessmentId);

    if (!mounted) return;

    navigator.pop();

    messenger.showSnackBar(
      const SnackBar(content: Text("Assessment deleted successfully.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("Assessment Details"),
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
        actions: [
          if (_isAdmin && _assessment != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: "Delete assessment",
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _assessment == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _error ?? "Could not load this assessment.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text("Retry")),
            ],
          ),
        ),
      );
    }

    final data = _assessment!;

    final name = data["participantName"]?.toString() ?? "-";
    final staffId = data["participantId"]?.toString() ?? "-";
    final score = (data["totalScore"] ?? 0) as int;
    final overall = data["overall"]?.toString() ?? "-";
    final summary = data["summary"]?.toString() ?? "";
    final suggestion = data["suggestion"]?.toString() ?? "";
    final date = _formatDate(data["createdAt"] as Timestamp?);
    final referencePhotoUrl = data["referencePhotoUrl"]?.toString() ?? "";
    final todayPhotoUrl = data["todayPhotoUrl"]?.toString() ?? "";
    final criteria = (data["criteria"] as List<dynamic>? ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text("Staff ID: $staffId  •  $date"),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Both reference and today's photos, side by side where both
          // exist -- exactly the two URLs saveAssessment() writes, no
          // additional photo fields invented.
          if (referencePhotoUrl.isNotEmpty || todayPhotoUrl.isNotEmpty)
            Row(
              children: [
                if (referencePhotoUrl.isNotEmpty)
                  Expanded(
                    child: _PhotoCard(
                      label: "Reference Photo",
                      url: referencePhotoUrl,
                    ),
                  ),
                if (referencePhotoUrl.isNotEmpty && todayPhotoUrl.isNotEmpty)
                  const SizedBox(width: 12),
                if (todayPhotoUrl.isNotEmpty)
                  Expanded(
                    child: _PhotoCard(
                      label: "Check-In Photo",
                      url: todayPhotoUrl,
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 16),

          Card(
            color: _resultColor(overall).withValues(alpha: 0.08),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text(
                    overall,
                    style: TextStyle(
                      color: _resultColor(overall),
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Overall Score: $score%",
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (criteria.isNotEmpty) ...[
            const Text(
              "Grooming Criteria",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 10),
            ...criteria.map((c) {
              final map = c as Map<String, dynamic>;
              final label = map["label"]?.toString() ?? "-";
              final criterionScore = map["score"]?.toString() ?? "-";
              final tip = map["tip"]?.toString() ?? "";

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1F3D73),
                    child: Text(
                      criterionScore,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: tip.isNotEmpty ? Text(tip) : null,
                ),
              );
            }),
            const SizedBox(height: 10),
          ],

          if (summary.isNotEmpty) ...[
            const Text(
              "AI Summary",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(summary),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (suggestion.isNotEmpty) ...[
            const Text(
              "AI Recommendation",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(suggestion),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String label;
  final String url;

  const _PhotoCard({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
