import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, staff, trainer, pending }

class AppUser {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String? staffId;
  final UserRole role;
  final List<UserRole> roles;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.staffId,
    required this.role,
    this.roles = const [],
    this.createdAt,
  });

  bool hasRole(UserRole value) {
    if (roles.contains(value)) return true;
    return role == value;
  }

  bool get isAdmin => hasRole(UserRole.admin);
  bool get isTrainer => hasRole(UserRole.trainer);
  bool get isStaff => hasRole(UserRole.staff);

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
    final rawRoles = data['roles'];
    final parsedRoles = <UserRole>[];

    if (rawRoles is Iterable) {
      for (final value in rawRoles) {
        final parsed = _parseRole(value?.toString().toLowerCase());
        if (parsed != UserRole.pending && !parsedRoles.contains(parsed)) {
          parsedRoles.add(parsed);
        }
      }
    }

    final legacyRole = _parseRole(roleString);

    if (parsedRoles.isEmpty && legacyRole != UserRole.pending) {
      parsedRoles.add(legacyRole);
    }

    final primaryRole = parsedRoles.contains(legacyRole)
        ? legacyRole
        : parsedRoles.isNotEmpty
            ? parsedRoles.first
            : legacyRole;

    return AppUser(
      uid: uid,
      email: email,
      firstName: data['firstName']?.toString() ?? '',
      lastName: data['lastName']?.toString() ?? '',
      staffId: data['staffId']?.toString(),
      role: primaryRole,
      roles: parsedRoles,
      createdAt: rawRoles == null && data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
    );
  }

  static UserRole _parseRole(String? roleString) {
    switch (roleString) {
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      case 'trainer':
        return UserRole.trainer;
      default:
        return UserRole.pending;
    }
  }
}
