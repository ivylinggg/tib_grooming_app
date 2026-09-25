import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

const _rememberedEmailKey = 'rememberedEmail';
const _rememberedPasswordKey = 'rememberedPassword';

class RememberedCredentials {
  final String email;
  final String password;

  const RememberedCredentials({
    required this.email,
    required this.password,
  });
}

enum UpdateStaffErrorType { none, duplicateStaffId, writeFailed }

class UpdateStaffResult {
  final bool success;
  final UpdateStaffErrorType error;
  final Object? exception;

  const UpdateStaffResult._(
    this.success,
    this.error, [
    this.exception,
  ]);

  factory UpdateStaffResult.success() =>
      const UpdateStaffResult._(true, UpdateStaffErrorType.none);

  factory UpdateStaffResult.duplicateStaffId() =>
      const UpdateStaffResult._(
        false,
        UpdateStaffErrorType.duplicateStaffId,
      );

  factory UpdateStaffResult.writeFailed(Object exception) =>
      UpdateStaffResult._(
        false,
        UpdateStaffErrorType.writeFailed,
        exception,
      );
}

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<AppUser> selectAdminRole() async {
    final user = _requireCurrentUser();
    await _setSingleRoleIfAllowed(user.uid, 'admin');
    return (await _loadAppUser(user))!;
  }

  Future<AppUser> selectStaffRole() async {
    final user = _requireCurrentUser();
    await _setSingleRoleIfAllowed(user.uid, 'staff');
    return (await _loadAppUser(user))!;
  }

  Future<AppUser> selectTrainerRole() async {
    final user = _requireCurrentUser();
    await _setSingleRoleIfAllowed(user.uid, 'trainer');
    return (await _loadAppUser(user))!;
  }

  Future<void> _setSingleRoleIfAllowed(
    String uid,
    String targetRole,
  ) async {
    final doc = await _firestore.collection('users').doc(uid).get(
          const GetOptions(source: Source.server),
        );

    final data = doc.data() ?? <String, dynamic>{};
    final currentRole = data['role']?.toString();
    final rawRoles = data['roles'];
    final currentRoles = rawRoles is Iterable
        ? rawRoles.map((value) => value.toString().toLowerCase()).toSet()
        : <String>{};

    if (currentRoles.isNotEmpty) {
      if (currentRoles.contains(targetRole)) return;

      throw StateError(
        'This account already has one or more roles assigned. '
        'Ask an Admin to change roles via Edit Staff.',
      );
    }

    if (currentRole != null &&
        currentRole != 'pending' &&
        currentRole != targetRole) {
      throw StateError(
        'This account already has a role assigned and cannot be '
        'changed here. Ask an Admin to change it via Edit Staff instead.',
      );
    }

    await _firestore.collection('users').doc(uid).update({
      'role': targetRole,
      'roles': [targetRole],
    });
  }

  Future<void> setUserRoles({
    required String uid,
    required List<UserRole> roles,
  }) async {
    if (roles.isEmpty) {
      throw StateError('At least one role is required.');
    }

    final roleStrings = roles
        .where((role) => role != UserRole.pending)
        .map(_roleToString)
        .toSet()
        .toList();

    if (roleStrings.isEmpty) {
      throw StateError('At least one valid role is required.');
    }

    await _firestore.collection('users').doc(uid).update({
      'role': roleStrings.first,
      'roles': roleStrings,
    });
  }

  Future<void> linkCurrentStaffToParticipant(String staffId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (staffId.trim().isEmpty) return;

    await _firestore.collection('users').doc(user.uid).update({
      'staffId': staffId.trim(),
    });
  }

  User _requireCurrentUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No signed-in user to assign a role to.');
    }

    return user;
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return _loadOrCreateAppUser(credential.user!);
  }

  Future<AppUser?> getCurrentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _loadOrCreateAppUser(user);
  }

  Future<AppUser> _loadOrCreateAppUser(User user) async {
    final appUser = await _loadAppUser(user);
    if (appUser != null) return appUser;

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email ?? '',
      'firstName': '',
      'lastName': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return (await _loadAppUser(user))!;
  }

  static final RegExp _obsoleteStaffIdPattern = RegExp(r'^STF\d+$');

  Future<String?> _sanitizeStaffId(
    String uid,
    String? rawStaffId,
  ) async {
    if (rawStaffId == null ||
        !_obsoleteStaffIdPattern.hasMatch(rawStaffId)) {
      return rawStaffId;
    }

    try {
      await _firestore.collection('users').doc(uid).update({
        'staffId': FieldValue.delete(),
      });
    } catch (_) {}

    return null;
  }

  Future<AppUser?> _loadAppUser(User user) async {
    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));

    if (!doc.exists) return null;

    final data = Map<String, dynamic>.from(doc.data()!);

    data['staffId'] = await _sanitizeStaffId(
      user.uid,
      data['staffId']?.toString(),
    );

    return AppUser.fromFirestore(
      uid: user.uid,
      email: user.email ?? '',
      data: data,
    );
  }

  Future<List<AppUser>> getAllStaff() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'staff')
        .get();

    final results = <AppUser>[];

    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());

      data['staffId'] = await _sanitizeStaffId(
        doc.id,
        data['staffId']?.toString(),
      );

      results.add(
        AppUser.fromFirestore(
          uid: doc.id,
          email: data['email']?.toString() ?? '',
          data: data,
        ),
      );
    }

    return results;
  }

  Future<AppUser?> getStaffByUid(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = Map<String, dynamic>.from(doc.data()!);

    data['staffId'] = await _sanitizeStaffId(
      uid,
      data['staffId']?.toString(),
    );

    return AppUser.fromFirestore(
      uid: uid,
      email: data['email']?.toString() ?? '',
      data: data,
    );
  }

  Future<UpdateStaffResult> updateStaffAccount({
    required String uid,
    required String firstName,
    required String lastName,
    String? staffId,
    required UserRole role,
  }) async {
    final trimmedStaffId = staffId?.trim() ?? '';

    try {
      if (trimmedStaffId.isNotEmpty) {
        final duplicateCheck = await _firestore
            .collection('users')
            .where('staffId', isEqualTo: trimmedStaffId)
            .get();

        final isDuplicate =
            duplicateCheck.docs.any((doc) => doc.id != uid);

        if (isDuplicate) {
          return UpdateStaffResult.duplicateStaffId();
        }
      }

      await _firestore.collection('users').doc(uid).update({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'staffId': trimmedStaffId.isEmpty ? null : trimmedStaffId,
        'role': _roleToString(role),
        'roles': [_roleToString(role)],
      });

      return UpdateStaffResult.success();
    } catch (e) {
      return UpdateStaffResult.writeFailed(e);
    }
  }

  static String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.staff:
        return 'staff';
      case UserRole.trainer:
        return 'trainer';
      case UserRole.pending:
        return 'pending';
    }
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> saveRememberedCredentials({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_rememberedEmailKey, email);

    await const FlutterSecureStorage().write(
      key: _rememberedPasswordKey,
      value: password,
    );
  }

  Future<RememberedCredentials?> getRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    final email = prefs.getString(_rememberedEmailKey);
    final password =
        await const FlutterSecureStorage().read(key: _rememberedPasswordKey);

    if (email == null || password == null) return null;

    return RememberedCredentials(
      email: email,
      password: password,
    );
  }

  Future<void> clearRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_rememberedEmailKey);
    await const FlutterSecureStorage().delete(
      key: _rememberedPasswordKey,
    );
  }
}
