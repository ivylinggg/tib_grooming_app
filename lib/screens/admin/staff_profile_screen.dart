import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/overall_result.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';
import 'edit_staff_screen.dart';
import 'participant_profile_screen.dart';

/// Admin's read view of a single Staff login account. Fetches fresh by
/// [uid] rather than taking an [AppUser] directly from the list screen,
/// so returning here after Edit Staff always shows what was actually
/// saved instead of a stale in-memory copy.
///
/// Same role-guard pattern as every other Admin screen: reachability
/// through the UI is not access control. The target account's name,
/// email, Staff ID, role, and registration activity are never fetched
/// until a confirmed `role: admin` account is verified server-side --
/// a Staff account navigating here directly must not see another
/// account's details, not even briefly.
class StaffProfileScreen extends StatefulWidget {
  final String uid;

  const StaffProfileScreen({super.key, required this.uid});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();

  AppUser? _staff;
  bool _checkingAccess = true;
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _handledParticipants = [];
  bool _loadingActivity = true;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  /// Same guard pattern as every other Admin screen: not-signed-in ->
  /// Login; signed-in but not a confirmed `role: admin` account (Staff,
  /// or role-less/pending) -> Role Selection. The target Staff account's
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
      final staff = await _authService.getStaffByUid(widget.uid);

      if (!mounted) return;

      if (staff == null) {
        setState(() {
          _error = "This Staff account no longer exists.";
          _loading = false;
        });
        return;
      }

      setState(() {
        _staff = staff;
        _loading = false;
      });

      _loadActivity();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Could not load this Staff profile.";
        _loading = false;
      });
    }
  }

  /// Real, live data -- every Participant record whose `createdByUid`
  /// matches this account, via FirebaseService.getParticipantsCreated
  /// ByStaff. Participants registered before that field existed simply
  /// never match this query (they have no such field at all), so they
  /// correctly never appear here rather than being guessed at -- see
  /// that method's own doc comment.
  Future<void> _loadActivity() async {
    setState(() {
      _loadingActivity = true;
    });

    final participants = await _firebaseService.getParticipantsCreatedByStaff(
      widget.uid,
    );

    if (!mounted) return;

    setState(() {
      _handledParticipants = participants;
      _loadingActivity = false;
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Unknown";
    return "${date.day}/${date.month}/${date.year}";
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return "Admin";
      case UserRole.staff:
        return "Staff";
      case UserRole.pending:
        return "Pending (no role assigned yet)";
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
        title: const Text("Staff Profile"),
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

    if (_error != null || _staff == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _error ?? "Could not load this Staff profile.",
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

    final staff = _staff!;

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
      },
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
                    child: Text(
                      staff.displayName.isNotEmpty
                          ? staff.displayName[0].toUpperCase()
                          : "?",
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F3D73),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    staff.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    staff.email,
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
                  const Text(
                    "Staff Information",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),

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
                          _InfoRow(
                            label: "Full Name",
                            value: staff.displayName,
                          ),
                          _InfoRow(
                            label: "Staff ID",
                            value: (staff.staffId?.isNotEmpty ?? false)
                                ? staff.staffId!
                                : "Not assigned",
                          ),
                          _InfoRow(label: "Email", value: staff.email),
                          _InfoRow(
                            label: "Role",
                            value: _roleLabel(staff.role),
                          ),
                          _InfoRow(
                            label: "Registered",
                            value: _formatDate(staff.createdAt),
                          ),
                          _InfoRow(
                            label: "Status",
                            value: staff.role == UserRole.staff
                                ? "Active Staff account"
                                : _roleLabel(staff.role),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    "Staff Activity",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),

                  _buildActivitySection(),

                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit Staff"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F3D73),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditStaffScreen(staff: staff),
                        ),
                      );

                      _load();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    if (_loadingActivity) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.groups, color: Color(0xFF1F3D73)),
                const SizedBox(width: 12),
                Text(
                  "${_handledParticipants.length}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text("Participant(s) registered by this account"),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Persistent, not conditional on the list being empty -- an
        // empty list here could mean "genuinely handled nothing" or
        // "handled things before this tracking existed", and there's no
        // way to tell those apart from this data, so the caveat always
        // shows rather than only appearing when it happens to look
        // suspicious.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blueGrey, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Only Participants registered by this account after "
                  "Staff-Participant tracking was added are listed here. "
                  "Earlier activity, if any, was not recorded and cannot "
                  "be reconstructed.",
                  style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (_handledParticipants.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                "Historical activity not recorded",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._handledParticipants.map((participant) {
            final name = participant["name"]?.toString() ?? "-";
            final staffId = participant["staff"]?.toString() ?? "-";
            final registrationDate =
                participant["registrationDate"]?.toString() ?? "-";
            final latestResult =
                participant["latestResult"]?.toString() ?? "No Assessment";
            final latestScore = participant["latestScore"] ?? "-";

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
                    name.isNotEmpty ? name[0].toUpperCase() : "?",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Staff ID: $staffId  •  Registered: $registrationDate\n"
                  "Latest: $latestResult ($latestScore%)",
                ),
                isThreeLine: true,
                trailing: Text(
                  latestResult,
                  style: TextStyle(
                    color: _resultColor(latestResult),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ParticipantProfileScreen(staffId: staffId),
                    ),
                  );
                },
              ),
            );
          }),
      ],
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
