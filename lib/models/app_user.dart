import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, staff, pending }

/// The signed-in Firebase user's role, read from `users/{uid}` in
/// Firestore right after sign-in. Firebase Auth alone only proves *who*
/// signed in, not *what they're allowed to do* -- this is the extra
/// state that answers that.
///
/// A brand-new account (AuthService.signUp) is written with no `role`
/// field at all -- it starts as [UserRole.pending] and stays that way
/// until RoleSelectionScreen calls
/// AuthService.selectAdminRole/selectStaffRole to assign the real one.
/// Nothing about self-registration can ever produce `role: "admin"`;
/// that only happens through selectAdminRole or a manual edit in the
/// Firebase Console. An unrecognized role string, or a `users/{uid}`
/// document with no `role` field, also resolves to [UserRole.pending]
/// rather than defaulting into either real role. Every entry point that
/// can produce a [UserRole.pending] account -- SignUpScreen right after
/// creation, LoginScreen signing in to one, SplashScreen resuming one
/// -- routes it to RoleSelectionScreen, and never to a dashboard.
///
/// This is also the model Admin's Staff Management screens
/// (staff_management_screen.dart, staff_profile_screen.dart,
/// edit_staff_screen.dart) read and write for every account with
/// `role: "staff"` -- a Staff *login account* is this model, not a
/// [Participant] (see that model's own doc comment for the distinction
/// between the two).
class AppUser {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;

  /// This account's real Staff ID -- the same identifier a Participant
  /// types into themselves during registration/Check-In
  /// (`participants/{staffId}`), kept in sync here by
  /// AuthService.linkCurrentStaffToParticipant every time this account
  /// completes a grooming assessment. An Admin can also set it directly
  /// via Edit Staff (AuthService.updateStaffAccount), e.g. to link an
  /// account before its first check-in. Null until either of those has
  /// happened -- never auto-generated, never a synthetic value of its
  /// own.
  final String? staffId;

  final UserRole role;

  /// When this `users/{uid}` document was created (set via
  /// FieldValue.serverTimestamp() in AuthService.signUp/
  /// _loadOrCreateAppUser). Null only for the rare case where the read
  /// races the server timestamp being resolved.
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.staffId,
    required this.role,
    this.createdAt,
  });

  /// "First Last", falling back to the email when no name is on file
  /// (e.g. an account created directly in the Firebase Console without
  /// going through SignUpScreen).
  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  factory AppUser.fromFirestore({
    required String uid,
    required String email,
    required Map<String, dynamic> data,
  }) {
    final roleString = data['role']?.toString().toLowerCase();

    final rawCreatedAt = data['createdAt'];

    return AppUser(
      uid: uid,
      email: email,
      firstName: data['firstName']?.toString() ?? '',
      lastName: data['lastName']?.toString() ?? '',
      staffId: data['staffId']?.toString(),
      role: _parseRole(roleString),
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
    );
  }

  static UserRole _parseRole(String? roleString) {
    switch (roleString) {
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      default:
        return UserRole.pending;
    }
  }
}
