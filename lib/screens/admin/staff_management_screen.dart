import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';
import 'staff_profile_screen.dart';

/// Admin's list of Staff *login accounts* (`users/{uid}` with
/// `role: "staff"`) -- distinct from Participant Management, which
/// lists crew members being assessed. See AuthService.getAllStaff's
/// doc comment and DashboardScreen's class doc comment for the full
/// Staff-vs-Participant distinction.
///
/// Same role-guard pattern as every other Admin screen: reachability
/// through the UI is not access control. getAllStaff() -- which reads
/// every Staff account's name/email/Staff ID -- is never called until a
/// confirmed `role: admin` account is verified server-side.
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<AppUser> _staff = [];
  List<AppUser> _filtered = [];

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
  /// or role-less/pending) -> Role Selection. getAllStaff() is only
  /// ever called after this resolves to Admin.
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

    _loadStaff();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final staff = await _authService.getAllStaff();

      if (!mounted) return;

      setState(() {
        _staff = staff;
        _filtered = _applySearch(staff, _searchController.text);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Could not load Staff accounts.";
        _loading = false;
      });
    }
  }

  List<AppUser> _applySearch(List<AppUser> source, String keyword) {
    final trimmed = keyword.trim().toLowerCase();
    if (trimmed.isEmpty) return source;

    return source.where((staff) {
      final name = staff.displayName.toLowerCase();
      final email = staff.email.toLowerCase();
      final staffId = (staff.staffId ?? '').toLowerCase();

      return name.contains(trimmed) ||
          email.contains(trimmed) ||
          staffId.contains(trimmed);
    }).toList();
  }

  void _onSearchChanged(String keyword) {
    setState(() {
      _filtered = _applySearch(_staff, keyword);
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Unknown";
    return "${date.day}/${date.month}/${date.year}";
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
        title: const Text("Staff Management"),
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Search Staff by name, email or Staff ID",
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

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadStaff, child: const Text("Retry")),
            ],
          ),
        ),
      );
    }

    if (_staff.isEmpty) {
      // Zero results here means the `users` collection genuinely has no
      // documents with role == "staff" yet -- not a permission problem.
      // A Firestore rules denial throws instead of returning an empty
      // snapshot, which _loadStaff's catch block turns into _error (the
      // red banner above), a state this empty view never reaches. Staff
      // accounts appear here automatically once someone selects "Staff"
      // on Role Selection -- nothing to configure by hand.
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.badge_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                "No Staff accounts yet",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                "A Staff account appears here the first time it signs in "
                "and selects \"Staff\" on the Role Selection screen.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return const Center(
        child: Text(
          "No staff match your search",
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStaff,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filtered.length,
        itemBuilder: (context, index) {
          final staff = _filtered[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF1F3D73),
                child: Text(
                  staff.displayName.isNotEmpty
                      ? staff.displayName[0].toUpperCase()
                      : "?",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                staff.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Staff ID : ${(staff.staffId?.isNotEmpty ?? false) ? staff.staffId : "Not assigned"}",
                    ),
                    const SizedBox(height: 4),
                    Text("Email : ${staff.email}"),
                    const SizedBox(height: 4),
                    // This list is already filtered to role == "staff",
                    // so this is always "Staff" today -- shown anyway
                    // per the explicit field list Admin asked for, and
                    // it stops being redundant the moment this screen
                    // is ever reused for a mixed-role list.
                    Text(
                      "Role : ${staff.role == UserRole.admin ? "Admin" : "Staff"}",
                    ),
                    const SizedBox(height: 4),
                    Text("Registered : ${_formatDate(staff.createdAt)}"),
                  ],
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StaffProfileScreen(uid: staff.uid),
                  ),
                );

                _loadStaff();
              },
            ),
          );
        },
      ),
    );
  }
}
