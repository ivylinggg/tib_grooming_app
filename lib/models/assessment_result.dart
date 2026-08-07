import 'assessment_criteria.dart';

class AssessmentResult {
  final String gender;

  /// PASS / FAIL
  final String overall;

  /// Claude AI summary
  final String summary;

  /// Claude AI improvement suggestion
  final String suggestion;

  /// Detail Criteria
  final List<AssessmentCriteria> criteria;

  /// Total Score
  final int totalScore;

  /// Firestore Document ID
  final String submissionId;

  /// PDF Share Link
  final String shareLink;

  /// Participant Information
  final String? staffId;
  final String? participantName;
  final String? trainerName;

  /// Assessment Date
  final String? assessmentDate;

  /// Firebase Storage URLs
  final String? referencePhotoUrl;
  final String? todayPhotoUrl;

  /// Future Admin Review
  final String? reviewedBy;
  final String? reviewerComment;
  final bool reviewed;

  const AssessmentResult({
    required this.gender,
    required this.overall,
    required this.summary,
    required this.suggestion,
    required this.criteria,
    required this.totalScore,
    required this.submissionId,
    required this.shareLink,
    this.staffId,
    this.participantName,
    this.trainerName,
    this.assessmentDate,
    this.referencePhotoUrl,
    this.todayPhotoUrl,
    this.reviewedBy,
    this.reviewerComment,
    this.reviewed = false,
  });

  factory AssessmentResult.fromJson(Map<String, dynamic> json) {
    return AssessmentResult(
      gender: json['gender']?.toString() ?? '',
      overall: json['overall']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      suggestion: json['suggestion']?.toString() ?? '',
      criteria:
          (json['criteria'] as List<dynamic>?)
              ?.map(
                (e) => AssessmentCriteria.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],

      totalScore: (json['totalScore'] as num?)?.toInt() ?? 0,

      submissionId: json['submissionId']?.toString() ?? '',

      shareLink: json['shareLink']?.toString() ?? '',

      staffId: json['staffId']?.toString(),

      participantName: json['participantName']?.toString(),

      trainerName: json['trainerName']?.toString(),

      assessmentDate: json['assessmentDate']?.toString(),

      referencePhotoUrl: json['referencePhotoUrl']?.toString(),

      todayPhotoUrl: json['todayPhotoUrl']?.toString(),

      reviewedBy: json['reviewedBy']?.toString(),

      reviewerComment: json['reviewerComment']?.toString(),

      reviewed: json['reviewed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "gender": gender,
      "overall": overall,
      "summary": summary,
      "suggestion": suggestion,
      "criteria": criteria.map((e) => e.toJson()).toList(),
      "totalScore": totalScore,
      "submissionId": submissionId,
      "shareLink": shareLink,
      "staffId": staffId,
      "participantName": participantName,
      "trainerName": trainerName,
      "assessmentDate": assessmentDate,
      "referencePhotoUrl": referencePhotoUrl,
      "todayPhotoUrl": todayPhotoUrl,
      "reviewedBy": reviewedBy,
      "reviewerComment": reviewerComment,
      "reviewed": reviewed,
    };
  }

  AssessmentResult copyWith({
    String? gender,
    String? overall,
    String? summary,
    String? suggestion,
    List<AssessmentCriteria>? criteria,
    int? totalScore,
    String? submissionId,
    String? shareLink,
    String? staffId,
    String? participantName,
    String? trainerName,
    String? assessmentDate,
    String? referencePhotoUrl,
    String? todayPhotoUrl,
    String? reviewedBy,
    String? reviewerComment,
    bool? reviewed,
  }) {
    return AssessmentResult(
      gender: gender ?? this.gender,
      overall: overall ?? this.overall,
      summary: summary ?? this.summary,
      suggestion: suggestion ?? this.suggestion,
      criteria: criteria ?? this.criteria,
      totalScore: totalScore ?? this.totalScore,
      submissionId: submissionId ?? this.submissionId,
      shareLink: shareLink ?? this.shareLink,
      staffId: staffId ?? this.staffId,
      participantName: participantName ?? this.participantName,
      trainerName: trainerName ?? this.trainerName,
      assessmentDate: assessmentDate ?? this.assessmentDate,
      referencePhotoUrl: referencePhotoUrl ?? this.referencePhotoUrl,
      todayPhotoUrl: todayPhotoUrl ?? this.todayPhotoUrl,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewerComment: reviewerComment ?? this.reviewerComment,
      reviewed: reviewed ?? this.reviewed,
    );
  }
}
