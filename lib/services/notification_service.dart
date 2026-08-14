import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_notification.dart';

/// Firestore-backed in-app notifications for Admin -- currently only
/// "a grooming assessment failed", created independently of (never
/// blocking, never blocked by) the existing Admin failure email; see
/// FirebaseService.saveAssessment, which fires both in parallel and
/// lets each fail on its own without affecting the other or the
/// already-saved assessment.
///
/// One document per failed assessment, not one per Admin account.
/// Fanning a notification out to every current Admin's own document
/// would need Flutter to first resolve the list of Admin UIDs --
/// which means querying `users` where `role == "admin"`, the exact
/// query this app's email notification was deliberately redesigned
/// away from (see FirebaseService._maybeNotifyAdminOfFailure's doc
/// comment/git history): that query returns whole `users/{uid}`
/// documents, `email` included, to whichever caller runs it --
/// possibly an anonymous Staff Check-In session. Firestore Rules can
/// only allow or deny a whole document, never a subset of its fields,
/// so there is no way to expose just `uid` from that collection
/// without also exposing `email` to the same caller.
///
/// Instead, each notification is visible to any account whose *own*
/// role is currently "admin", enforced by Firestore Rules reading the
/// *reader's* own `users/{request.auth.uid}.role` -- never a list this
/// client assembled. This can never drift out of sync with the real
/// Admin roster (an account promoted or demoted from Admin is
/// reflected immediately, with no separate roster to keep in sync),
/// and by construction it never touches -- or lets any caller read --
/// any Admin's email address. Per-Admin read state is still real: see
/// [readBy] / [markAsRead].
class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection("notifications");

  /// Creates the shared "Grooming Assessment Failed" notification for
  /// one assessment, if one doesn't already exist for it.
  ///
  /// Duplicate protection is two-layered, both required by the
  /// original request: the document ID is deterministic
  /// (`<assessmentId>_failed_assessment` -- baking in a type suffix so
  /// a future second notification type for the same assessment ID
  /// never collides with this one), AND the write itself only happens
  /// inside a transaction that first checks the document doesn't
  /// already exist. The deterministic ID alone would already make a
  /// same-content `.set()` idempotent, but a bare `.set()` would also
  /// silently reset an already-read notification's [readBy] map back
  /// to empty if this were ever invoked twice for the same assessment
  /// -- the transaction's existence check is what prevents that, not
  /// just the duplicate-row concern.
  ///
  /// Never throws -- every failure is caught and logged, exactly like
  /// FirebaseService._maybeNotifyAdminOfFailure, so a failure here can
  /// never affect the already-saved assessment or the independent
  /// email notification.
  Future<void> createFailedAssessmentNotification({
    required String assessmentId,
    required String participantId,
    required String participantName,
    String? trainerName,
    required int totalScore,
    required String overall,
    DateTime? assessmentDate,
  }) async {
    final docRef = _collection.doc("${assessmentId}_failed_assessment");

    final message =
        "$participantId - $participantName received a grooming score of "
        "$totalScore and is not qualified.";

    try {
      await _firestore.runTransaction((tx) async {
        final existing = await tx.get(docRef);
        if (existing.exists) return;

        tx.set(docRef, {
          "type": "failed_assessment",
          "title": "Grooming Assessment Failed",
          "message": message,
          "assessmentId": assessmentId,
          "participantId": participantId,
          "participantName": participantName,
          "trainerName": trainerName,
          "totalScore": totalScore,
          "overall": overall,
          "assessmentDate": assessmentDate == null
              ? null
              : Timestamp.fromDate(assessmentDate),
          "createdAt": FieldValue.serverTimestamp(),
          "readBy": <String, bool>{},
        });
      });
    } catch (e) {
      debugPrint("createFailedAssessmentNotification: $e");
    }
  }

  /// Every notification, newest first -- reachable only from a screen
  /// already gated to a confirmed Admin account (same pattern as every
  /// other Admin screen's `_checkAdminAccess`), and enforced again
  /// server-side by Firestore Rules regardless.
  Stream<List<AdminNotification>> streamNotifications() {
    return _collection
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AdminNotification.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Live unread count for exactly [adminUid], for DashboardScreen's
  /// bell badge -- derived client-side from [streamNotifications]
  /// (checking each notification's own [AdminNotification.isReadBy]
  /// rather than a separate query) since Firestore has no "map key is
  /// absent or false" query operator to filter this server-side. Fine
  /// at this app's real notification volume -- the same reasoning
  /// AssessmentService/FirebaseService already rely on elsewhere for
  /// small, unindexed, client-side filters.
  Stream<int> streamUnreadCount(String adminUid) {
    return streamNotifications().map(
      (notifications) =>
          notifications.where((n) => !n.isReadBy(adminUid)).length,
    );
  }

  /// Marks one notification read for exactly [adminUid] -- a targeted
  /// dotted-field update, so it can only ever change that one entry in
  /// [readBy] and nothing else on the document (mirrored by the
  /// Firestore Rule restricting `update` to the `readBy` field alone).
  Future<void> markAsRead({
    required String notificationId,
    required String adminUid,
  }) async {
    try {
      await _collection.doc(notificationId).update({"readBy.$adminUid": true});
    } catch (e) {
      debugPrint("markAsRead: $e");
    }
  }
}
