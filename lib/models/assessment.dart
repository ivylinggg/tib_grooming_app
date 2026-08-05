class Assessment {
  final String id;

  /// Participant
  final String participantId;
  final String participantName;
  final String trainerName;

  /// Claude AI
  final int score;
  final String result;
  final String aiComment;

  /// Grooming Checklist
  final bool hair;
  final bool uniform;
  final bool tie;
  final bool shoes;
  final bool nameTag;

  /// Firebase Storage
  final String referencePhotoUrl;
  final String todayPhotoUrl;

  /// PDF
  final String pdfUrl;

  /// Admin Review
  final bool reviewed;
  final String reviewedBy;
  final String reviewComment;

  /// Date
  final DateTime createdAt;

  Assessment({
    required this.id,
    required this.participantId,
    required this.participantName,
    required this.trainerName,
    required this.score,
    required this.result,
    required this.aiComment,
    required this.hair,
    required this.uniform,
    required this.tie,
    required this.shoes,
    required this.nameTag,
    required this.referencePhotoUrl,
    required this.todayPhotoUrl,
    required this.pdfUrl,
    required this.reviewed,
    required this.reviewedBy,
    required this.reviewComment,
    required this.createdAt,
  });

  factory Assessment.fromJson(Map<String, dynamic> json) {
    return Assessment(
      id: json["id"] ?? "",
      participantId: json["participantId"] ?? "",
      participantName: json["participantName"] ?? "",
      trainerName: json["trainerName"] ?? "",
      score: json["score"] ?? 0,
      result: json["result"] ?? "",
      aiComment: json["aiComment"] ?? "",
      hair: json["hair"] ?? false,
      uniform: json["uniform"] ?? false,
      tie: json["tie"] ?? false,
      shoes: json["shoes"] ?? false,
      nameTag: json["nameTag"] ?? false,
      referencePhotoUrl: json["referencePhotoUrl"] ?? "",
      todayPhotoUrl: json["todayPhotoUrl"] ?? "",
      pdfUrl: json["pdfUrl"] ?? "",
      reviewed: json["reviewed"] ?? false,
      reviewedBy: json["reviewedBy"] ?? "",
      reviewComment: json["reviewComment"] ?? "",
      createdAt:
          DateTime.tryParse(json["createdAt"]?.toString() ?? "") ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "participantId": participantId,
      "participantName": participantName,
      "trainerName": trainerName,
      "score": score,
      "result": result,
      "aiComment": aiComment,
      "hair": hair,
      "uniform": uniform,
      "tie": tie,
      "shoes": shoes,
      "nameTag": nameTag,
      "referencePhotoUrl": referencePhotoUrl,
      "todayPhotoUrl": todayPhotoUrl,
      "pdfUrl": pdfUrl,
      "reviewed": reviewed,
      "reviewedBy": reviewedBy,
      "reviewComment": reviewComment,
      "createdAt": createdAt.toIso8601String(),
    };
  }
}
