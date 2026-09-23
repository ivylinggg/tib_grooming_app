import 'package:cloud_firestore/cloud_firestore.dart';

/// A historical grooming/training record imported from the team's legacy
/// training reports.
///
/// Historical records are intentionally independent from the current
/// `participants/{staffId}` and `assessments` collections. The legacy
/// reports identify people by name, so [participantName] is the primary
/// lookup field for this feature.
class TrainingHistory {
  final String id;
  final String participantName;
  final String trainingDate;
  final String crewType;
  final String trainer;
  final List<String> photoUrls;
  final String trainerReview;
  final String specialRemarks;
  final String ccdRemarks;
  final String? sourceFile;
  final DateTime? createdAt;

  const TrainingHistory({
    required this.id,
    required this.participantName,
    required this.trainingDate,
    required this.crewType,
    required this.trainer,
    this.photoUrls = const [],
    this.trainerReview = '',
    this.specialRemarks = '',
    this.ccdRemarks = '',
    this.sourceFile,
    this.createdAt,
  });

  factory TrainingHistory.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    final rawPhotos = data['photoUrls'];
    final photos = rawPhotos is Iterable
        ? rawPhotos.map((value) => value.toString()).toList()
        : <String>[];

    DateTime? createdAt;
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    }

    return TrainingHistory(
      id: doc.id,
      participantName: data['participantName']?.toString() ?? '',
      trainingDate: data['trainingDate']?.toString() ?? '',
      crewType: data['crewType']?.toString() ?? '',
      trainer: data['trainer']?.toString() ?? '',
      photoUrls: photos,
      trainerReview: data['trainerReview']?.toString() ?? '',
      specialRemarks: data['specialRemarks']?.toString() ?? '',
      ccdRemarks: data['ccdRemarks']?.toString() ?? '',
      sourceFile: data['sourceFile']?.toString(),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participantName': participantName,
      'trainingDate': trainingDate,
      'crewType': crewType,
      'trainer': trainer,
      'photoUrls': photoUrls,
      'trainerReview': trainerReview,
      'specialRemarks': specialRemarks,
      'ccdRemarks': ccdRemarks,
      'sourceFile': sourceFile,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }
}
