/// Canonical classification of an [AssessmentResult.overall] value.
///
/// The canonical vocabulary is exactly: "Excellent", "Good", "Needs
/// Work", "Insufficient" -- Claude.gs's prompt instructs Claude to
/// return only these four and normalizes anything else server-side.
/// [classify] stays case-insensitive and falls back to [insufficient]
/// for anything unrecognized anyway, as a second line of defense --
/// Flutter shouldn't fully trust a network payload even when the
/// backend is expected to enforce the contract.
///
/// Firestore, [AssessmentResult], and the Apps Script/Claude contract
/// all keep storing and transmitting a plain String -- this enum exists
/// only for UI branching (color, pass/fail tallying), not as a storage
/// format.
enum OverallResult {
  excellent,
  good,
  needsWork,
  insufficient;

  static OverallResult classify(String raw) {
    switch (raw.trim().toLowerCase()) {
      case "excellent":
        return OverallResult.excellent;
      case "good":
        return OverallResult.good;
      case "needs work":
        return OverallResult.needsWork;
      default:
        return OverallResult.insufficient;
    }
  }

  /// Whether this tier counts toward a "pass" in aggregate statistics.
  /// Matches the color semantics already established by
  /// AssessmentHistoryScreen before this phase -- red (insufficient/
  /// unrecognized) is the only tier that ever meant "problem";
  /// excellent/good/needsWork were all shown as non-failure colors
  /// (green/blue/orange).
  bool get isPass => this != OverallResult.insufficient;
}
