import 'package:cloud_firestore/cloud_firestore.dart';

/// One in-app notification for the Admin side of the app -- currently
/// only ever created for a failed (`totalScore < kFailingScoreThreshold`,
/// see FirebaseService) grooming assessment, but [type] exists so a
/// future second kind doesn't need a second collection.
///
/// Deliberately NOT one document per Admin account (no `adminUid`
/// field): see NotificationService's doc comment for the full
/// reasoning -- in short, resolving "every current Admin UID" client-
/// side would require the same `users` query this app's email
/// notification was explicitly redesigned to avoid (it would leak
/// `email` alongside `uid` to whichever caller runs it, including an
/// anonymous Staff Check-In session). One shared document per failed
/// assessment, visible to any account whose *own* role is currently
/// "admin" (enforced by Firestore Rules checking the reader's own
/// `users/{request.auth.uid}.role`, never a client-supplied list),
/// avoids that entirely and can never drift out of sync with the real
/// Admin roster the way a duplicated list would.
///
/// Per-Admin read state still exists -- [readBy] is a map of
/// `{adminUid: true}`, so each Admin's unread badge is their own, even
/// though the underlying notification is shared.
class AdminNotification {
  final String id;
  final String type;
  final String title;
  final String message;

  final String assessmentId;
  final String participantId;
  final String participantName;
  final String? trainerName;
  final int totalScore;
  final String overall;

  final DateTime? assessmentDate;
  final DateTime? createdAt;

  final Map<String, bool> readBy;

  const AdminNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.assessmentId,
    required this.participantId,
    required this.participantName,
    this.trainerName,
    required this.totalScore,
    required this.overall,
    this.assessmentDate,
    this.createdAt,
    this.readBy = const {},
  });

  bool isReadBy(String adminUid) => readBy[adminUid] == true;

  factory AdminNotification.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawAssessmentDate = data['assessmentDate'];
    final rawCreatedAt = data['createdAt'];
    final rawReadBy = data['readBy'];

    return AdminNotification(
      id: id,
      type: data['type']?.toString() ?? 'failed_assessment',
      title: data['title']?.toString() ?? 'Grooming Assessment Failed',
      message: data['message']?.toString() ?? '',
      assessmentId: data['assessmentId']?.toString() ?? '',
      participantId: data['participantId']?.toString() ?? '',
      participantName: data['participantName']?.toString() ?? '',
      trainerName: data['trainerName']?.toString(),
      totalScore: (data['totalScore'] ?? 0) as int,
      overall: data['overall']?.toString() ?? '',
      assessmentDate: rawAssessmentDate is Timestamp
          ? rawAssessmentDate.toDate()
          : null,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      readBy: rawReadBy is Map
          ? rawReadBy.map(
              (key, value) => MapEntry(key.toString(), value == true),
            )
          : const {},
    );
  }
}
