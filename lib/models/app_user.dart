import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, staff, trainer, pending }

class AppUser {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String? staffId;
  final UserRole role;
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
      case 'trainer':
        return UserRole.trainer;
      default:
        return UserRole.pending;
    }
  }
}
