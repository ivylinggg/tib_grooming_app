import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';

/// Admin's Edit Staff form. Writes to `users/{uid}` for an account that
/// is NOT the currently signed-in one -- see
/// AuthService.updateStaffAccount's doc comment for why that's a
/// distinct, deliberate capability rather than a reuse of
/// selectAdminRole/selectStaffRole.
///
/// This is the highest-stakes Admin screen in the app: its Role dropdown
/// can write `role: "admin"` onto ANY account, including turning a
/// Staff account's own session into Admin. Same role-guard pattern as
/// every other Admin screen applies here, with extra weight -- the form
/// (and therefore [_save], and therefore the role dropdown) is not built
/// at all until a confirmed `role: admin` account is verified
/// server-side. A Staff account has no way to reach the Save button,
/// let alone the Role field, without that verification passing first.
class EditStaffScreen extends StatefulWidget {
  final AppUser staff;

  const EditStaffScreen({super.key, required this.staff});

  @override
  State<EditStaffScreen> createState() => _EditStaffScreenState();
}

class _EditStaffScreenState extends State<EditStaffScreen> {
  final AuthService _authService = AuthService();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _staffIdController;

  late UserRole _selectedRole;
  bool _saving = false;

  bool _checkingAccess = true;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.staff.firstName);
    _lastNameController = TextEditingController(text: widget.staff.lastName);
    _staffIdController = TextEditingController(
      text: widget.staff.staffId ?? '',
    );

    // Role Selection only ever produces "admin" or "staff" for a real
    // account -- "pending" means no role was ever chosen. It's not
    // offered as a selectable target here (see the dropdown items
    // below); if an account is somehow still pending, default the
    // selector to Staff (this screen is only reachable from Staff
    // Management, which already filters to role: "staff", so this is a
    // defensive fallback, not the expected path).
    _selectedRole = widget.staff.role == UserRole.admin
        ? UserRole.admin
        : UserRole.staff;

    _checkAdminAccess();
  }

  /// Same guard pattern as every other Admin screen, and the most
  /// important instance of it in the app: not-signed-in -> Login;
  /// signed-in but not a confirmed `role: admin` account (Staff, or
  /// role-less/pending) -> Role Selection. Until this resolves to
  /// Admin, [build] never renders the form -- there is no path for a
  /// Staff account to reach [_save] or the Role dropdown, so a
  /// non-Admin account cannot edit another account or promote itself,
  /// no matter how this screen was reached.
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
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _staffIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final staffId = _staffIdController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter both First Name and Last Name."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final result = await _authService.updateStaffAccount(
      uid: widget.staff.uid,
      firstName: firstName,
      lastName: lastName,
      staffId: staffId,
      role: _selectedRole,
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    if (result.success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Staff profile updated successfully."),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop();
      return;
    }

    final message = switch (result.error) {
      UpdateStaffErrorType.duplicateStaffId =>
        "That Staff ID is already assigned to another Staff account. "
            "Please use a different Staff ID.",
      UpdateStaffErrorType.writeFailed =>
        "Could not save changes. Please check your connection and try again.",
      UpdateStaffErrorType.none => "Could not save changes.",
    };

    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
        title: const Text("Edit Staff"),
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.staff.email,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              "Email cannot be changed here -- it's tied to this "
              "account's Firebase Authentication sign-in.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: "First Name",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: "Last Name",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _staffIdController,
              decoration: InputDecoration(
                labelText: "Staff ID (optional)",
                helperText: "Must be unique across all Staff accounts.",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<UserRole>(
              initialValue: _selectedRole,
              decoration: InputDecoration(
                labelText: "Role",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // Only Staff/Admin are offered -- "pending" is an internal
              // "no role chosen yet" state produced by sign-up, not a
              // role an Admin would deliberately assign to someone.
              items: const [
                DropdownMenuItem(value: UserRole.staff, child: Text("Staff")),
                DropdownMenuItem(value: UserRole.admin, child: Text("Admin")),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedRole = value;
                      });
                    },
            ),

            if (_selectedRole == UserRole.admin &&
                widget.staff.role != UserRole.admin)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_outlined, color: Colors.orange),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Changing this account to Admin grants full "
                          "Admin access. This account will no longer "
                          "appear under Staff Management once saved.",
                          style: TextStyle(color: Colors.orange, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F3D73),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_saving ? "Saving..." : "Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
