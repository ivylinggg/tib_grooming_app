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

    await _guardRoleChange(user.uid, 'admin');

    await _firestore.collection('users').doc(user.uid).update({
      'role': 'admin',
    });

    return (await _loadAppUser(user))!;
  }

  Future<AppUser> selectStaffRole() async {
    final user = _requireCurrentUser();

    await _guardRoleChange(user.uid, 'staff');

    await _firestore.collection('users').doc(user.uid).update({
      'role': 'staff',
    });

    return (await _loadAppUser(user))!;
  }

  Future<AppUser> selectTrainerRole() async {
    final user = _requireCurrentUser();

    await _guardRoleChange(user.uid, 'trainer');

    await _firestore.collection('users').doc(user.uid).update({
      'role': 'trainer',
    });

    return (await _loadAppUser(user))!;
  }

  Future<void> _guardRoleChange(
    String uid,
    String targetRole,
  ) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));

    final currentRole = doc.data()?['role']?.toString();

    if (currentRole != null &&
        currentRole != 'pending' &&
        currentRole != targetRole) {
      throw StateError(
        'This account already has a role assigned and cannot be '
        'changed here. Ask an Admin to change it via Edit Staff instead.',
      );
    }
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
      throw StateError(
        'No signed-in user to assign a role to.',
      );
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

  static final RegExp _obsoleteStaffIdPattern = RegExp(
    r'^STF\d+$',
  );

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
    } catch (_) {
      // Non-fatal cleanup.
    }

    return null;
  }

  Future<AppUser?> _loadAppUser(User user) async {
    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));

    if (!doc.exists) return null;

    final data = Map<String, dynamic>.from(
      doc.data()!,
    );

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
      final data = Map<String, dynamic>.from(
        doc.data(),
      );

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
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) return null;

    final data = Map<String, dynamic>.from(
      doc.data()!,
    );

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
            .where(
              'staffId',
              isEqualTo: trimmedStaffId,
            )
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
        'staffId':
            trimmedStaffId.isEmpty ? null : trimmedStaffId,
        'role': _roleToString(role),
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
    return _auth.sendPasswordResetEmail(
      email: email,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> saveRememberedCredentials({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _rememberedEmailKey,
      email,
    );

    await const FlutterSecureStorage().write(
      key: _rememberedPasswordKey,
      value: password,
    );
  }

  Future<RememberedCredentials?> getRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    final email = prefs.getString(
      _rememberedEmailKey,
    );

    final password = await const FlutterSecureStorage().read(
      key: _rememberedPasswordKey,
    );

    if (email == null || password == null) {
      return null;
    }

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

String describeAuthError(FirebaseAuthException e) {
  if ((e.message ?? '').contains(
    'CONFIGURATION_NOT_FOUND',
  )) {
    return 'Sign-in is not enabled for this app yet. '
        'Please contact the administrator.';
  }

  switch (e.code) {
    case 'invalid-email':
      return 'That email address is not valid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password.';
    case 'email-already-in-use':
      return 'An account already exists for that email.';
    case 'weak-password':
      return 'That password is too weak.';
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled for this app yet. '
          'Please contact the administrator.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'network-request-failed':
      return 'Network error. Please check your connection and try again.';
    case 'internal-error':
      return 'Something went wrong. Please try again.';
    default:
      return e.message ??
          'Authentication failed. Please try again.';
  }
}
