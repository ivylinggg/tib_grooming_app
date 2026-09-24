import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/training_history.dart';
import 'training_history_service.dart';

class TrainerTrainingHistoryService {
  TrainerTrainingHistoryService({TrainingHistoryService? historyService})
      : _historyService = historyService ?? TrainingHistoryService();

  final TrainingHistoryService _historyService;

  Future<List<TrainingHistory>> getAll() => _historyService.getAll();

  Future<String> createRecord(TrainingHistory record) =>
      _historyService.createRecord(record);

  Future<void> updateRecord(String id, Map<String, dynamic> data) =>
      _historyService.updateRecord(id, data);

  Future<void> updatePhotos(String id, List<String> photoUrls) =>
      _historyService.updatePhotos(id, photoUrls);

  static Map<String, dynamic> recordData(TrainingHistory record) {
    return {
      'participantName': record.participantName,
      'trainingDate': record.trainingDate,
      'crewType': record.crewType,
      'trainer': record.trainer,
      'photoUrls': record.photoUrls,
      'trainerReview': record.trainerReview,
      'specialRemarks': record.specialRemarks,
      'ccdRemarks': record.ccdRemarks,
      'sourceFile': record.sourceFile,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
