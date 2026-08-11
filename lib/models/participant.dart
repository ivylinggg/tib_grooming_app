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

  /// Which Staff *login account* (a [Participant] has no login of its
  /// own -- see the class-level distinction in AuthService/AppUser)
  /// registered this record, if known. Additive: written by
  /// FirebaseService.registerParticipant() going forward, but never
  /// backfilled onto records created before this field existed --
  /// those stay null, which the UI shows as "Unknown / Not recorded"
  /// rather than guessing an owner. Never used to imply the current
  /// Staff account handled a record just because it's null; null means
  /// exactly "not recorded", nothing more specific than that.
  final String? createdByUid;

  /// The registering Staff account's own login Staff ID
  /// (AppUser.staffId) at the time of registration -- a different
  /// identifier from this Participant's own [staffId], and commonly
  /// null at registration time since AppUser.staffId is normally only
  /// set once that account completes its own first assessment. Same
  /// historical-null caveat as [createdByUid].
  final String? createdByStaffId;

  /// The registering Staff account's display name at the time of
  /// registration (a snapshot, not a live lookup -- if that Staff
  /// account is later renamed, this does not change). Same
  /// historical-null caveat as [createdByUid].
  final String? createdByName;

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
    this.createdByUid,
    this.createdByStaffId,
    this.createdByName,
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
      createdByUid: json["createdByUid"]?.toString(),
      createdByStaffId: json["createdByStaffId"]?.toString(),
      createdByName: json["createdByName"]?.toString(),
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
      "createdByUid": createdByUid,
      "createdByStaffId": createdByStaffId,
      "createdByName": createdByName,
    };
  }
}
