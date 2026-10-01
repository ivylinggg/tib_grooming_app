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
    final rawRole = data['role'];
    final rawRoles = data['roles'];
    final parsedRoles = <UserRole>[];

    void addRole(Object? value) {
      final parsed = _parseRole(value?.toString().toLowerCase());
      if (parsed != UserRole.pending && !parsedRoles.contains(parsed)) {
        parsedRoles.add(parsed);
      }
    }

    // Accept the Firebase format currently used by this account:
    // role: ['admin', 'trainer']
    if (rawRole is Iterable) {
      for (final value in rawRole) {
        addRole(value);
      }
    } else {
      addRole(rawRole);
    }

    // Also accept the temporary/alternate `roles` array format.
    if (rawRoles is Iterable) {
      for (final value in rawRoles) {
        addRole(value);
      }
    }

    final primaryRole =
        parsedRoles.isNotEmpty ? parsedRoles.first : UserRole.pending;

    return AppUser(
      uid: uid,
      email: email,
      firstName: data['firstName']?.toString() ?? '',
      lastName: data['lastName']?.toString() ?? '',
      staffId: data['staffId']?.toString(),
      role: primaryRole,
      roles: parsedRoles,
      createdAt: data['createdAt'] is Timestamp
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
