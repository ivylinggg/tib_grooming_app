class AssessmentCriteria {
  final String label;
  final int score;
  final String tip;

  const AssessmentCriteria({
    required this.label,
    required this.score,
    required this.tip,
  });

  factory AssessmentCriteria.fromJson(Map<String, dynamic> json) {
    return AssessmentCriteria(
      label: json['label']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      tip: json['tip']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'label': label, 'score': score, 'tip': tip};
  }
}
