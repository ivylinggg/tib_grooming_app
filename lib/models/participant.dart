class Participant {
  /// Firestore Document ID
  final String id;

  /// Staff Information
  final String fullName;
  final String staffId;
  final String trainerName;
  final String registrationDate;

  /// Firebase Storage
  final String photoUrl;

  /// Latest Assessment
  final int latestScore;
  final String latestResult;

  /// Total Assessments
  final int assessmentCount;

  /// Active / Inactive
  final bool isActive;

  /// Firestore Timestamp
  final DateTime? createdAt;

  const Participant({
    required this.id,
    required this.fullName,
    required this.staffId,
    required this.trainerName,
    required this.registrationDate,
    required this.photoUrl,
    this.latestScore = 0,
    this.latestResult = "",
    this.assessmentCount = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json["id"]?.toString() ?? "",
      fullName: json["name"]?.toString() ?? "",
      staffId: json["staff"]?.toString() ?? "",
      trainerName: json["trainer"]?.toString() ?? "",
      registrationDate: json["registrationDate"]?.toString() ?? "",
      photoUrl: json["photoUrl"]?.toString() ?? "",
      latestScore: (json["latestScore"] as num?)?.toInt() ?? 0,
      latestResult: json["latestResult"]?.toString() ?? "",
      assessmentCount: (json["assessmentCount"] as num?)?.toInt() ?? 0,
      isActive: json["isActive"] ?? true,
      createdAt: json["createdAt"] is DateTime ? json["createdAt"] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": fullName,
      "staff": staffId,
      "trainer": trainerName,
      "registrationDate": registrationDate,
      "photoUrl": photoUrl,
      "latestScore": latestScore,
      "latestResult": latestResult,
      "assessmentCount": assessmentCount,
      "isActive": isActive,
      "createdAt": createdAt,
    };
  }

  Participant copyWith({
    String? id,
    String? fullName,
    String? staffId,
    String? trainerName,
    String? registrationDate,
    String? photoUrl,
    int? latestScore,
    String? latestResult,
    int? assessmentCount,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Participant(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      staffId: staffId ?? this.staffId,
      trainerName: trainerName ?? this.trainerName,
      registrationDate: registrationDate ?? this.registrationDate,
      photoUrl: photoUrl ?? this.photoUrl,
      latestScore: latestScore ?? this.latestScore,
      latestResult: latestResult ?? this.latestResult,
      assessmentCount: assessmentCount ?? this.assessmentCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
