import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/overall_result.dart';
import '../../models/participant.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';

/// Admin's read/edit view of a single Participant record -- the crew
/// member being assessed, not a Staff login account (see
/// DashboardScreen's class doc comment for that distinction). Reached
/// from Participant Management's list, and from Staff Profile's
/// Activity section (tapping a Participant that Staff account
/// registered).
///
/// Same role-guard pattern as every other Admin screen: reachability
/// through the UI is not access control. The participant's personal
/// info, scores, and assessment history are never fetched until a
/// confirmed `role: admin` account is verified server-side.
class ParticipantProfileScreen extends StatefulWidget {
  final String staffId;

  const ParticipantProfileScreen({super.key, required this.staffId});

  @override
  State<ParticipantProfileScreen> createState() =>
      _ParticipantProfileScreenState();
}

class _ParticipantProfileScreenState extends State<ParticipantProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();

  Participant? _participant;
  bool _checkingAccess = true;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  /// Same guard pattern as every other Admin screen: not-signed-in ->
  /// Login; signed-in but not a confirmed `role: admin` account (Staff,
  /// or role-less/pending) -> Role Selection. The target Participant's
  /// data ([_load]) is only ever fetched after this resolves to Admin.
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
    } catch (_) {
      // Falls through to the role check below, which treats a failed
      // lookup the same as "not Admin" -- fail closed, not open.
    }

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

    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _firebaseService.getParticipant(widget.staffId);

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _error = "This Participant record no longer exists.";
          _loading = false;
        });
        return;
      }

      setState(() {
        _participant = Participant.fromJson(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Could not load this Participant profile.";
        _loading = false;
      });
    }
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

  Future<void> _editParticipant(Participant participant) async {
    final nameController = TextEditingController(text: participant.fullName);
    final trainerController = TextEditingController(
      text: participant.trainerName,
    );
    final dateController = TextEditingController(
      text: participant.registrationDate,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Edit Participant"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Full Name"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: trainerController,
                  decoration: const InputDecoration(labelText: "Trainer Name"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: "Registration Date",
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (saved != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    final success = await _firebaseService.updateParticipant(
      staff: participant.staffId,
      name: nameController.text.trim(),
      trainer: trainerController.text.trim(),
      registrationDate: dateController.text.trim(),
    );

    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? "Participant updated successfully."
              : "Could not save changes.",
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      _load();
    }
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
        title: const Text("Participant Profile"),
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _participant == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _error ?? "Could not load this Participant profile.",
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

    final participant = _participant!;
    final hasKnownCreator =
        (participant.createdByName?.isNotEmpty ?? false) ||
        (participant.createdByStaffId?.isNotEmpty ?? false);

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Color(0xFF1F3D73)),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    backgroundImage: participant.photoUrl.isNotEmpty
                        ? NetworkImage(participant.photoUrl)
                        : null,
                    child: participant.photoUrl.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Color(0xFF1F3D73),
                          )
                        : null,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    participant.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Staff ID: ${participant.staffId}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            Padding(
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
                          const Text(
                            "Profile Information",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _InfoRow(
                            label: "Full Name",
                            value: participant.fullName,
                          ),
                          _InfoRow(
                            label: "Staff ID",
                            value: participant.staffId,
                          ),
                          _InfoRow(
                            label: "Trainer",
                            value: participant.trainerName,
                          ),
                          _InfoRow(
                            label: "Registered",
                            value: participant.registrationDate,
                          ),
                          _InfoRow(
                            label: "Status",
                            value: participant.isActive ? "Active" : "Inactive",
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

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
                          const Text(
                            "Latest Grooming Result",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _StatBox(
                                  label: "Latest Score",
                                  value: "${participant.latestScore}/60",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatBox(
                                  label: "Latest Result",
                                  value: participant.latestResult.isEmpty
                                      ? "No Assessment"
                                      : participant.latestResult,
                                  valueColor: participant.latestResult.isEmpty
                                      ? Colors.grey
                                      : _resultColor(participant.latestResult),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatBox(
                                  label: "Assessments",
                                  value: "${participant.assessmentCount}",
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // See Participant.createdByUid's doc comment -- these
                  // three fields are additive and only exist on records
                  // registered after Staff-Participant tracking was
                  // added. A record with none of them is not an error,
                  // it just predates the feature.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.blueGrey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            hasKnownCreator
                                ? "Registered by: ${participant.createdByName ?? "Unknown"}"
                                      "${participant.createdByStaffId != null ? " (${participant.createdByStaffId})" : ""}"
                                : "Registered by: Unknown / Not recorded",
                            style: const TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Assessment results are already shown directly above
                  // (Latest Grooming Result card) -- no separate History
                  // screen link here. AssessmentHistoryScreen itself is
                  // NOT deleted (Staff Dashboard still uses it); this
                  // screen simply no longer navigates to it, so Admin
                  // never hits its Firestore composite-index requirement.
                  // Full assessment detail remains reachable via Admin
                  // Dashboard -> Assessment Management -> Assessment
                  // Detail.
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit Participant"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F3D73),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _editParticipant(participant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatBox({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }
}
