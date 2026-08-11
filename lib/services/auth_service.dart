import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

const _rememberedEmailKey = 'rememberedEmail';
const _rememberedPasswordKey = 'rememberedPassword';

/// Email/password remembered for LoginScreen to pre-fill on its next
/// appearance -- see [AuthService.getRememberedCredentials]. This is
/// deliberately not a session-resume mechanism: having these does not
/// sign anyone in by itself.
class RememberedCredentials {
  final String email;
  final String password;

  const RememberedCredentials({required this.email, required this.password});
}

/// What happened on an [AuthService.updateStaffAccount] call. Distinct
/// failure modes get distinct handling -- a duplicate Staff ID is a
/// validation problem the Admin can fix by picking a different ID; a
/// write failure is a network/Firestore problem worth retrying -- so
/// this follows the same typed-result-object pattern already used for
/// [RegisterResult]/[DriveUploadResult]/[CameraPickResult] rather than
/// collapsing both into a single `false`.
enum UpdateStaffErrorType { none, duplicateStaffId, writeFailed }

class UpdateStaffResult {
  final bool success;
  final UpdateStaffErrorType error;
  final Object? exception;

  const UpdateStaffResult._(this.success, this.error, [this.exception]);

  factory UpdateStaffResult.success() =>
      const UpdateStaffResult._(true, UpdateStaffErrorType.none);

  factory UpdateStaffResult.duplicateStaffId() =>
      const UpdateStaffResult._(false, UpdateStaffErrorType.duplicateStaffId);

  factory UpdateStaffResult.writeFailed(Object exception) =>
      UpdateStaffResult._(false, UpdateStaffErrorType.writeFailed, exception);
}

/// Wraps Firebase Auth sign-in/up/out and the Firestore `users/{uid}`
/// role lookup that determines whether a signed-in account is Admin,
/// Staff, or still role-less (routes to RoleSelectionScreen).
///
/// This is a distinct concern from [Participant]: a Participant is a
/// grooming assessee stored in the `participants` collection (staff ID,
/// trainer, photo, scores) and has no login identity at all. AppUser
/// models the *system login account* (in the `users` collection) that
/// signs in to this app. The two never overlap, so this stays a
/// separate, small model/service rather than bolting auth/role fields
/// onto Participant.
///
/// FirebaseService stays responsible for Firestore's participants/
/// assessments collections; this is the equivalent home for the users
/// collection and auth actions themselves.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  /// Creates a brand-new Firebase Auth account and its `users/{uid}`
  /// profile document -- with no `role` field yet -- and, unlike
  /// signIn, deliberately leaves the account signed in.
  /// `createUserWithEmailAndPassword` auto-signs the new account in on
  /// the Firebase side; SignUpScreen relies on that and continues
  /// straight into RoleSelectionScreen using this same session, rather
  /// than bouncing back through Login. selectAdminRole/selectStaffRole
  /// are what actually assign a role afterwards.
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

  /// Completes RoleSelectionScreen's Admin choice for the current
  /// session: writes `role: "admin"` onto `users/{uid}` and returns the
  /// resulting [AppUser]. This is the only place in the app that can
  /// produce an admin account short of a manual Firebase Console edit
  /// -- the public Sign Up form never assigns a role itself.
  ///
  /// Guarded by [_guardRoleChange]: this only ever assigns a role to an
  /// account that doesn't already have a *different* confirmed one --
  /// see that method's doc comment for why.
  Future<AppUser> selectAdminRole() async {
    final user = _requireCurrentUser();

    await _guardRoleChange(user.uid, 'admin');

    await _firestore.collection('users').doc(user.uid).update({
      'role': 'admin',
    });

    return (await _loadAppUser(user))!;
  }

  /// Completes RoleSelectionScreen's Staff choice for the current
  /// session: writes `role: "staff"` onto `users/{uid}`. Nothing else.
  ///
  /// Does NOT touch `staffId` and never invents one -- this app has
  /// exactly one real "Staff ID" concept: the identifier a person types
  /// into themselves, during Participant registration/Check-In
  /// (Participant.staffId, e.g. "BA2121"), which is also what every
  /// assessment record's `participantId` is saved as. An account's
  /// `users/{uid}.staffId` is kept in sync with that same real value by
  /// [linkCurrentStaffToParticipant], called from
  /// AssessmentService.saveAssessment every time a signed-in account
  /// completes an assessment -- not generated here, not invented, never
  /// a synthetic format of its own.
  ///
  /// Guarded by [_guardRoleChange]: this only ever assigns a role to an
  /// account that doesn't already have a *different* confirmed one --
  /// see that method's doc comment for why.
  Future<AppUser> selectStaffRole() async {
    final user = _requireCurrentUser();

    await _guardRoleChange(user.uid, 'staff');

    await _firestore.collection('users').doc(user.uid).update({
      'role': 'staff',
    });

    return (await _loadAppUser(user))!;
  }

  /// Refuses to let [selectAdminRole]/[selectStaffRole] silently
  /// overwrite an account's already-assigned role with a *different*
  /// one. Both of those methods exist for exactly one legitimate
  /// purpose: turning a brand-new, still-`pending` account into its
  /// first real role. They are never the right way to change an
  /// existing Admin into Staff or vice versa -- Admin's Edit Staff
  /// (see [updateStaffAccount]) is the only sanctioned way to do that,
  /// deliberately, with the reviewer seeing exactly which account and
  /// which change they're making.
  ///
  /// This was the actual bug behind a Staff account occasionally
  /// landing on Admin Dashboard after signing back in: RoleSelection's
  /// role picker could reappear for an account that already had a
  /// role (a transient Firestore read failure was, before this fix,
  /// treated identically to "this account has never chosen a role" --
  /// see PostAuthRoute.lookupFailed's doc comment), and selecting a
  /// role there called an unconditional `.update()` with nothing to
  /// stop it from clobbering whatever role already existed on the
  /// server. This closes that regardless of what causes the picker to
  /// reappear: even if it does, re-selecting a *different* role than
  /// what's already saved now fails loudly instead of silently
  /// succeeding.
  ///
  /// Read with `Source.server`, same reasoning as [_loadAppUser] --
  /// this check is worthless if it can be satisfied by a stale local
  /// cache that hasn't caught up with the server yet.
  ///
  /// Selecting the *same* role again (e.g. retrying after an earlier
  /// transient failure) is allowed -- only an actual change away from
  /// an already-confirmed different role is refused. An account with no
  /// role yet (`null`, or the literal absence of one -- "pending" is
  /// never actually written as a string anywhere in this codebase) is
  /// always allowed through.
  Future<void> _guardRoleChange(String uid, String targetRole) async {
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

  /// Keeps `users/{uid}.staffId` in sync with the real Staff ID a
  /// signed-in account most recently used to complete a grooming
  /// Check-In/assessment -- called from
  /// AssessmentService.saveAssessment, never from Role Selection. This
  /// is the *only* place `users/{uid}.staffId` is ever written from the
  /// Staff side of the app (Admin's EditStaffScreen can still set it
  /// manually via [updateStaffAccount]; this simply keeps it truthful
  /// going forward once the account actually uses a real ID).
  ///
  /// Silently does nothing if nobody is signed in -- the self-service,
  /// no-auth Cabin Crew Check-In flow (CheckInCard, reachable without
  /// ever signing in) must keep working exactly as before; there is no
  /// `users/{uid}` document to update in that case, and there's nothing
  /// wrong with that.
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

  /// Signs in, then looks up the account's role. If the account has no
  /// `users/{uid}` document at all (e.g. it was created directly in the
  /// Firebase Console, or a sign-up was interrupted before a profile
  /// was written), creates a minimal role-less one rather than
  /// rejecting the sign-in -- the caller (LoginScreen) routes a
  /// role-less [AppUser] to RoleSelectionScreen, never to a dashboard,
  /// so there's no unsafe state this can put the account in.
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

  /// Used on app start (SplashScreen) to resume an already-signed-in
  /// session and find out where to route it. Returns null only if
  /// nobody is signed in -- a signed-in account with a missing profile
  /// document gets one created on the spot (role-less), same as
  /// [signIn], rather than being signed back out.
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

  /// Matches the exact retired auto-generated Staff Login ID format this
  /// app used to write onto `users/{uid}.staffId` -- `STF` followed by
  /// digits, e.g. `"STF00001"`. That generator (`_generateStaffLoginId`)
  /// and the code that called it (`ensureStaffId`) have both been
  /// removed entirely; this pattern only exists so any account that
  /// still carries the old value gets it cleared for real, in
  /// Firestore, the next time that account's document is read -- not
  /// just hidden in the UI. A real Staff ID a person enters during
  /// Check-In/registration (e.g. `"BA2121"`) never matches this.
  static final RegExp _obsoleteStaffIdPattern = RegExp(r'^STF\d+$');

  /// Every read path in this class that returns a `staffId` funnels
  /// through here first. If [rawStaffId] is the retired auto-generated
  /// format, this deletes the `staffId` field from `users/{uid}` in
  /// Firestore (a real write, so it's gone for the *next* read too, not
  /// only hidden from the caller of *this* read) and returns null so
  /// the [AppUser] built from this read already reflects "Not
  /// registered". Any other value -- including null, meaning no
  /// `staffId` was ever set -- passes through unchanged.
  ///
  /// The Firestore write is wrapped in its own try/catch: a failed
  /// cleanup must never block sign-in or a Staff list from loading --
  /// worst case the obsolete value gets cleared on a later read
  /// instead of this one.
  Future<String?> _sanitizeStaffId(String uid, String? rawStaffId) async {
    if (rawStaffId == null || !_obsoleteStaffIdPattern.hasMatch(rawStaffId)) {
      return rawStaffId;
    }

    try {
      await _firestore.collection('users').doc(uid).update({
        'staffId': FieldValue.delete(),
      });
    } catch (_) {
      // Non-fatal -- see doc comment above.
    }

    return null;
  }

  /// Used by every routing decision in the app (via
  /// PostAuthRoute.resolvePostAuthRoute) -- forced to read from the
  /// server rather than the SDK's local cache. A role this
  /// security-relevant must never be decided from a value that might
  /// not have finished syncing from an earlier write yet; better to
  /// surface a real error (which the caller treats as "we don't know
  /// yet, let them retry" -- see PostAuthRoute.lookupFailed) than to
  /// silently trust a stale cached role.
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

  /// Admin's Staff Management list: every `users/{uid}` account with
  /// `role: "staff"`. Unlike [_loadAppUser] (which reads the *current*
  /// signed-in Firebase [User] for its email), this reads `email`
  /// straight out of the stored document -- `signUp`/
  /// `_loadOrCreateAppUser` both always write it there, and there is no
  /// [User] object available for any account other than the one
  /// currently signed in.
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

  /// Re-fetches a single Staff account by uid -- used by Staff Profile
  /// to refresh after Edit Staff saves, without re-querying the whole
  /// Staff list. Returns null if the account no longer exists.
  Future<AppUser?> getStaffByUid(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    if (!doc.exists) return null;

    final data = Map<String, dynamic>.from(doc.data()!);
    data['staffId'] = await _sanitizeStaffId(uid, data['staffId']?.toString());

    return AppUser.fromFirestore(
      uid: uid,
      email: data['email']?.toString() ?? '',
      data: data,
    );
  }

  /// Admin's Edit Staff save action -- the only place in the app that
  /// writes to a `users/{uid}` document belonging to an account other
  /// than the one currently signed in. Every other write method in this
  /// class (`selectAdminRole`, `selectStaffRole`) only ever touches
  /// `_auth.currentUser`'s own document; this is a deliberate, separate
  /// capability, not a generalization of those.
  ///
  /// [staffId], if non-empty, must be unique across the `users`
  /// collection (checked here, excluding [uid] itself) before the write
  /// happens -- mirrors the duplicate-Staff-ID protection already in
  /// place for Participant registration (FirebaseService.
  /// registerParticipant's Stage 1 read), applied to this entirely
  /// separate collection. An empty/null [staffId] clears the field
  /// rather than being treated as a value to deduplicate.
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

        final isDuplicate = duplicateCheck.docs.any((doc) => doc.id != uid);

        if (isDuplicate) {
          return UpdateStaffResult.duplicateStaffId();
        }
      }

      await _firestore.collection('users').doc(uid).update({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'staffId': trimmedStaffId.isEmpty ? null : trimmedStaffId,
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
      case UserRole.pending:
        return 'pending';
    }
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Signs out of Firebase Auth only. Deliberately does NOT touch
  /// remembered credentials -- Logout and "forget my saved
  /// email/password" are two different user actions, and the Sign In
  /// screen is expected to still show the remembered email/password
  /// after a logout (the user only typed them once; logging out isn't
  /// "I want to retype my password"). Credentials are cleared only when
  /// the user explicitly signs in with "Remember me" unchecked -- see
  /// [clearRememberedCredentials].
  Future<void> signOut() => _auth.signOut();

  /// Saves email + password for LoginScreen to pre-fill next time it's
  /// shown. The password goes to flutter_secure_storage (Android
  /// Keystore-backed), never to SharedPreferences in plaintext; the
  /// email alone (not sensitive on its own) goes to SharedPreferences.
  /// This does NOT sign anyone in and is never consulted for routing --
  /// it only ever populates two text fields the user still has to
  /// review and submit themselves.
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

  /// Returns the remembered email/password, or null if nothing (or
  /// only one of the two) is saved.
  Future<RememberedCredentials?> getRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_rememberedEmailKey);
    final password = await const FlutterSecureStorage().read(
      key: _rememberedPasswordKey,
    );

    if (email == null || password == null) return null;

    return RememberedCredentials(email: email, password: password);
  }

  /// Called when the user signs in with "Remember me" unchecked -- also
  /// wipes out anything saved from an earlier session where it *was*
  /// checked, matching "if Remember Me is unchecked ... clear
  /// previously remembered credentials".
  Future<void> clearRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberedEmailKey);
    await const FlutterSecureStorage().delete(key: _rememberedPasswordKey);
  }
}

/// Turns a [FirebaseAuthException] into a message a non-technical user
/// can act on. Shared by LoginScreen and SignUpScreen so the two forms
/// don't drift into inconsistent wording for the same underlying error.
String describeAuthError(FirebaseAuthException e) {
  // Checked before the code switch, not as one of its cases: this
  // specific failure -- the Firebase project's Authentication
  // configuration doesn't exist server-side (Auth was never
  // initialized, or the reCAPTCHA/App-Check protection layer in front
  // of it isn't set up) -- has been observed arriving with more than
  // one `e.code` value depending on which Auth call triggers it
  // (signInPassword vs signUpPassword), so matching on the message
  // text is the only reliable way to catch it regardless of code.
  if ((e.message ?? '').contains('CONFIGURATION_NOT_FOUND')) {
    return 'Sign-in is not enabled for this app yet. Please contact the administrator.';
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
      return e.message ?? 'Authentication failed. Please try again.';
  }
}
