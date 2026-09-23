import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/training_history.dart';

/// Firestore access for legacy training-history records.
///
/// The service does not modify the existing participants/assessments
/// collections. It reads and writes only `training_history`.
class TrainingHistoryService {
  TrainingHistoryService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collectionName = 'training_history';

  /// Search history by participant name.
  ///
  /// Firestore does not provide a native "contains" query for arbitrary
  /// substrings, so the service fetches the relevant historical records and
  /// performs case-insensitive partial matching in Dart. The result is
  /// grouped by normalized participant name at the UI layer.
  Future<List<TrainingHistory>> searchByName(String query) async {
    try {
      final snapshot = await _firestore.collection(collectionName).get();

      final normalizedQuery = query.trim().toLowerCase();

      final records = snapshot.docs
          .map(TrainingHistory.fromFirestore)
          .where(
            (record) =>
                normalizedQuery.isEmpty ||
                record.participantName.toLowerCase().contains(normalizedQuery),
          )
          .toList();

      records.sort(_compareTrainingDatesDescending);
      return records;
    } catch (e) {
      throw TrainingHistoryException(
        'Unable to search historical training records.',
        e,
      );
    }
  }

  /// Get all historical training records for one exact participant name.
  Future<List<TrainingHistory>> getByParticipantName(
    String participantName,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .where('participantName', isEqualTo: participantName)
          .get();

      final records = snapshot.docs.map(TrainingHistory.fromFirestore).toList();
      records.sort(_compareTrainingDatesDescending);
      return records;
    } catch (e) {
      throw TrainingHistoryException(
        'Unable to load this participant\'s training history.',
        e,
      );
    }
  }

  /// Get all historical training records.
  ///
  /// Kept for the initial Admin overview and migration verification.
  Future<List<TrainingHistory>> getAll() async {
    try {
      final snapshot = await _firestore.collection(collectionName).get();

      final records = snapshot.docs.map(TrainingHistory.fromFirestore).toList();
      records.sort(_compareTrainingDatesDescending);
      return records;
    } catch (e) {
      throw TrainingHistoryException(
        'Unable to load historical training records.',
        e,
      );
    }
  }

  int _compareTrainingDatesDescending(
    TrainingHistory a,
    TrainingHistory b,
  ) {
    final aDate = _parseTrainingDate(a.trainingDate);
    final bDate = _parseTrainingDate(b.trainingDate);

    if (aDate == null && bDate == null) return b.id.compareTo(a.id);
    if (aDate == null) return 1;
    if (bDate == null) return -1;

    final byDate = bDate.compareTo(aDate);
    if (byDate != 0) return byDate;

    return b.id.compareTo(a.id);
  }

  DateTime? _parseTrainingDate(String value) {
    final text = value.trim();

    // dd-MM-yyyy / dd-MM-yy
    final dash = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{2,4})$').firstMatch(text);
    if (dash != null) {
      final day = int.tryParse(dash.group(1)!);
      final month = int.tryParse(dash.group(2)!);
      final rawYear = int.tryParse(dash.group(3)!);

      if (day == null || month == null || rawYear == null) return null;

      final year = rawYear < 100 ? 2000 + rawYear : rawYear;
      return DateTime.tryParse(
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
      );
    }

    // dd/MM/yyyy / dd/MM/yy
    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(text);
    if (slash != null) {
      final day = int.tryParse(slash.group(1)!);
      final month = int.tryParse(slash.group(2)!);
      final rawYear = int.tryParse(slash.group(3)!);

      if (day == null || month == null || rawYear == null) return null;

      final year = rawYear < 100 ? 2000 + rawYear : rawYear;
      return DateTime.tryParse(
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
      );
    }

    // yyyy-MM-dd or another DateTime-compatible representation.
    return DateTime.tryParse(text);
  }
}

class TrainingHistoryException implements Exception {
  const TrainingHistoryException(this.message, this.cause);

  final String message;
  final Object cause;

  @override
  String toString() => '$message ($cause)';
}
