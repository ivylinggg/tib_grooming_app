/// Every way `FirebaseService.registerParticipant()` can conclude.
///
/// `none` is not an error -- it is the success case, so that `error` can
/// stay non-nullable and every branch is a real, named value instead of
/// null standing in for "no problem."
enum RegisterErrorType {
  none,
  duplicateStaffId,
  firestoreReadFailed,
  uploadFailed,
  firestoreWriteFailed,
}

/// Result of a registration attempt.
///
/// Carries no user-facing text -- `FirebaseService` reports *what*
/// happened (`error`) and, when relevant, the *underlying cause*
/// (`exception`/`stackTrace`) for logging. Deciding *what to say* about
/// it is the caller's job, kept out of this class on purpose.
class RegisterResult {
  final RegisterErrorType error;
  final Object? exception;
  final StackTrace? stackTrace;

  const RegisterResult._(this.error, [this.exception, this.stackTrace]);

  bool get success => error == RegisterErrorType.none;

  factory RegisterResult.success() =>
      const RegisterResult._(RegisterErrorType.none);

  factory RegisterResult.duplicate() =>
      const RegisterResult._(RegisterErrorType.duplicateStaffId);

  factory RegisterResult.firestoreReadFailed(
    Object exception, [
    StackTrace? stackTrace,
  ]) => RegisterResult._(
    RegisterErrorType.firestoreReadFailed,
    exception,
    stackTrace,
  );

  /// [exception] is a [DriveUploadException] (see
  /// lib/api/google_drive_api.dart) carrying a specific, safe-to-show
  /// message -- distinguishing a bad HTTP status, an Apps Script
  /// `success: false` response, a malformed response, and a thrown
  /// exception, rather than collapsing all of them into one generic
  /// "upload failed".
  factory RegisterResult.uploadFailed([
    Object? exception,
    StackTrace? stackTrace,
  ]) => RegisterResult._(RegisterErrorType.uploadFailed, exception, stackTrace);

  factory RegisterResult.firestoreWriteFailed(
    Object exception, [
    StackTrace? stackTrace,
  ]) => RegisterResult._(
    RegisterErrorType.firestoreWriteFailed,
    exception,
    stackTrace,
  );
}
