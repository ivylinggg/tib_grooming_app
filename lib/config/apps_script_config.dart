/// Apps Script Web App deployment that serves apps_script/Code.gs and
/// Claude.gs -- photo upload, full-body detection, and AI grooming
/// analysis all live behind this one URL (dispatched by the "action"
/// field in each request body; see Code.gs's doPost).
///
/// This is the same deployment as GoogleDriveConfig.uploadUrl. The two
/// are kept as separate config files for this phase rather than
/// consolidated, since merging them would mean editing GoogleDriveApi,
/// which is out of scope for the AssessmentApi rewrite this file was
/// introduced for.
class AppsScriptConfig {
  AppsScriptConfig._();

  static const String execUrl =
      "https://script.google.com/macros/s/AKfycbyY0BD9jUibD1pvIZmtIxaB38gAurDMQRcBCDffqoeVB_fReRcbEgcb_Tx7BEaDlmyFNg/exec";
}
