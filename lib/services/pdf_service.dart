import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/overall_result.dart';

/// What happened when [PdfService.exportAssessmentPdf] or
/// [PdfService.downloadAssessmentPdf] tried to save the generated PDF.
/// [cancelled] is deliberately distinct from a thrown exception -- the
/// user closing the native Save dialog without picking a location is a
/// normal, real outcome, not a failure, and must never be reported as
/// either a success or an error (see AssessmentDetailScreen._exportPdf/
/// _downloadPdf for how callers branch on this).
enum PdfExportOutcome { saved, cancelled }

class PdfExportResult {
  final PdfExportOutcome outcome;

  /// The path/identifier `file_picker` returned for the saved file, if
  /// available on this platform. Shown to the user so "where did it go"
  /// has a real, specific answer instead of a generic message.
  final String? savedPath;

  const PdfExportResult({required this.outcome, this.savedPath});
}

/// A generated PDF's raw bytes plus the filename both export paths use,
/// so [PdfService._buildPdfBytes] stays the single place that ever
/// builds the document -- Save PDF and Download PDF must always produce
/// byte-identical content, only the save mechanism differs.
class _BuiltPdf {
  final Uint8List bytes;
  final String filename;

  const _BuiltPdf({required this.bytes, required this.filename});
}

/// Builds a real, downloadable/shareable `.pdf` file for one grooming
/// assessment -- a proper generated document (text, tables, embedded
/// photos), never a screenshot of the screen.
///
/// Takes the exact same raw Firestore map AssessmentDetailScreen already
/// parses (from FirebaseService.getAssessmentById) rather than
/// AssessmentResult -- AssessmentResult.fromJson expects fields
/// (`staffId`, `assessmentDate`, `gender`, `submissionId`, `shareLink`)
/// that FirebaseService.saveAssessment never actually writes to
/// Firestore (that contract only matches the in-memory object built
/// right after an assessment completes, not what's read back later), so
/// building the PDF from the same raw map the screen already displays
/// keeps this in sync with what's genuinely on screen instead of
/// re-deriving a second, subtly different data shape.
///
/// Two separate, real save actions are exposed -- [exportAssessmentPdf]
/// ("Save PDF") and [downloadAssessmentPdf] ("Download PDF") -- both
/// write the actual generated PDF to a real, user-accessible location
/// via `file_picker`'s native Save dialog (`FilePicker.platform.
/// saveFile`), never merely a share-sheet invocation. On Android this
/// goes through the Storage Access Framework, so the bytes are
/// genuinely written to wherever the OS dialog resolves -- no runtime
/// storage permission needed, and nothing here depends on the user
/// later having to go hunt down a temporary cache file themselves.
///
/// Neither method reports success itself: callers must check
/// [PdfExportResult.outcome] before showing any "PDF saved" message --
/// the user closing the Save dialog without picking anywhere
/// ([PdfExportOutcome.cancelled]) is a normal outcome, not an error.
class PdfService {
  static const PdfColor _brandBlue = PdfColor.fromInt(0xFF1F3D73);

  /// "Save PDF" -- opens the native Save dialog wherever the OS/user
  /// last left it, letting the user pick any folder and filename for
  /// this export. This is the pre-existing Export PDF action; kept
  /// exactly as before, just backed by a real Save dialog instead of
  /// the OS share sheet.
  ///
  /// [trainerName] is looked up separately by the caller (from the
  /// linked Participant record -- see FirebaseService.getParticipant)
  /// since it is never stored on the assessment document itself; null
  /// or empty renders as "Not available", never invented.
  Future<PdfExportResult> exportAssessmentPdf({
    required Map<String, dynamic> assessmentData,
    String? trainerName,
  }) async {
    final built = await _buildPdfBytes(
      assessmentData: assessmentData,
      trainerName: trainerName,
    );

    final path = await FilePicker.platform.saveFile(
      dialogTitle: "Save Grooming Result PDF",
      fileName: built.filename,
      type: FileType.custom,
      allowedExtensions: ["pdf"],
      bytes: built.bytes,
    );

    if (path == null) {
      return const PdfExportResult(outcome: PdfExportOutcome.cancelled);
    }

    return PdfExportResult(outcome: PdfExportOutcome.saved, savedPath: path);
  }

  /// "Download PDF" -- a second, independent real-file action, distinct
  /// from [exportAssessmentPdf]. It is never `Printing.sharePdf()`
  /// relabeled: it goes through the same real `file_picker` Save-file
  /// write [exportAssessmentPdf] uses, so the downloaded file genuinely
  /// exists at the path the OS reports back.
  ///
  /// The functional difference from "Save PDF": on desktop platforms
  /// (Windows/macOS/Linux), this pre-navigates the Save dialog straight
  /// to the user's real Downloads folder (see
  /// [_tryDefaultDownloadDirectory]) -- a genuine one-tap "download"
  /// instead of wherever the dialog last happened to be left. On
  /// Android/iOS, `file_picker` does not expose a way to skip the
  /// Storage-Access-Framework/document-picker dialog entirely without
  /// either a runtime storage permission this app does not request or
  /// an additional native-code dependency this project does not have --
  /// so on those platforms the dialog still appears, defaulting (as SAF
  /// itself does) to the most recently used location, which is very
  /// often already Downloads once a user has picked it once. This is a
  /// real platform constraint, not a shortcut: it is documented here
  /// rather than silently pretending the two actions are identical
  /// everywhere.
  Future<PdfExportResult> downloadAssessmentPdf({
    required Map<String, dynamic> assessmentData,
    String? trainerName,
  }) async {
    final built = await _buildPdfBytes(
      assessmentData: assessmentData,
      trainerName: trainerName,
    );

    final path = await FilePicker.platform.saveFile(
      dialogTitle: "Download Grooming Result PDF",
      fileName: built.filename,
      type: FileType.custom,
      allowedExtensions: ["pdf"],
      bytes: built.bytes,
      initialDirectory: _tryDefaultDownloadDirectory(),
    );

    if (path == null) {
      return const PdfExportResult(outcome: PdfExportOutcome.cancelled);
    }

    return PdfExportResult(outcome: PdfExportOutcome.saved, savedPath: path);
  }

  /// Best-effort real Downloads folder path on desktop platforms only,
  /// built from `dart:io`'s `Platform.environment` -- no new dependency
  /// (`path_provider` is not in pubspec.yaml, and is not added just for
  /// this). Returns null on Android/iOS/web (where `file_picker` does
  /// not honor `initialDirectory` anyway) or if the relevant home-
  /// directory environment variable is not set, in which case
  /// `file_picker` simply falls back to its own default behavior.
  String? _tryDefaultDownloadDirectory() {
    try {
      if (Platform.isWindows) {
        final home = Platform.environment["USERPROFILE"];
        return (home == null || home.isEmpty) ? null : "$home\\Downloads";
      }

      if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment["HOME"];
        return (home == null || home.isEmpty) ? null : "$home/Downloads";
      }
    } catch (_) {
      // Platform.isWindows/etc. can throw on unsupported embedders --
      // fall through to "no hint" rather than failing the export.
    }

    return null;
  }

  Future<_BuiltPdf> _buildPdfBytes({
    required Map<String, dynamic> assessmentData,
    String? trainerName,
  }) async {
    final participantName =
        assessmentData["participantName"]?.toString() ?? "-";
    final staffId = assessmentData["participantId"]?.toString() ?? "-";
    final totalScore = (assessmentData["totalScore"] ?? 0).toString();
    final overall = assessmentData["overall"]?.toString() ?? "-";
    final summary = assessmentData["summary"]?.toString() ?? "";
    final suggestion = assessmentData["suggestion"]?.toString() ?? "";
    final createdAt = assessmentData["createdAt"];
    final referencePhotoUrl =
        assessmentData["referencePhotoUrl"]?.toString() ?? "";
    final todayPhotoUrl = assessmentData["todayPhotoUrl"]?.toString() ?? "";
    final criteria = (assessmentData["criteria"] as List<dynamic>? ?? [])
        .map((c) => c as Map<String, dynamic>)
        .toList();

    final referenceImage = await _tryFetchImage(referencePhotoUrl);
    final todayImage = await _tryFetchImage(todayPhotoUrl);

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(0, 0, 0, 32),
        header: (context) =>
            context.pageNumber == 1 ? _buildHeader() : pw.SizedBox.shrink(),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 32),
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            "Page ${context.pageNumber} of ${context.pagesCount}",
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(32, 20, 32, 0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildParticipantSection(
                  staffId: staffId,
                  name: participantName,
                  trainerName: (trainerName == null || trainerName.isEmpty)
                      ? "Not available"
                      : trainerName,
                  dateText: _formatDisplayDate(createdAt),
                ),
                pw.SizedBox(height: 18),
                _buildResultSection(totalScore: totalScore, overall: overall),
                if (criteria.isNotEmpty) ...[
                  pw.SizedBox(height: 18),
                  _buildCriteriaSection(criteria),
                ],
                if (summary.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  _buildTextSection("AI Summary", summary),
                ],
                if (suggestion.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  _buildTextSection("AI Recommendation", suggestion),
                ],
                if (referenceImage != null || todayImage != null) ...[
                  pw.SizedBox(height: 18),
                  _buildPhotosSection(referenceImage, todayImage),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await doc.save();

    final filenameStaffId = staffId == "-" || staffId.isEmpty
        ? "unknown"
        : staffId;
    final fileDate = _formatFileDate(createdAt);
    final filename = "TIB_Grooming_Result_${filenameStaffId}_$fileDate.pdf";

    return _BuiltPdf(bytes: bytes, filename: filename);
  }

  pw.Widget _buildHeader() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 18, horizontal: 32),
      decoration: const pw.BoxDecoration(color: _brandBlue),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "TIB GROOMING",
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 2.5,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            "Grooming Assessment Result",
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildParticipantSection({
    required String staffId,
    required String name,
    required String trainerName,
    required String dateText,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Participant Information",
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 13,
              color: _brandBlue,
            ),
          ),
          pw.SizedBox(height: 8),
          _kvRow("Staff ID", staffId),
          _kvRow("Full Name", name),
          _kvRow("Trainer Name", trainerName),
          _kvRow("Assessment Date", dateText),
        ],
      ),
    );
  }

  pw.Widget _kvRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildResultSection({
    required String totalScore,
    required String overall,
  }) {
    final color = _resultColor(overall);
    final backgroundTint = PdfColor(color.red, color.green, color.blue, 0.08);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: backgroundTint,
        border: pw.Border.all(color: color, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            overall,
            style: pw.TextStyle(
              color: color,
              fontWeight: pw.FontWeight.bold,
              fontSize: 22,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            "Overall Score: $totalScore/60",
            style: const pw.TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCriteriaSection(List<Map<String, dynamic>> criteria) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "Grooming Criteria",
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 13,
            color: _brandBlue,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ["Criterion", "Score", "Note"],
          data: criteria
              .map(
                (c) => [
                  c["label"]?.toString() ?? "-",
                  (c["score"] ?? 0).toString(),
                  c["tip"]?.toString() ?? "",
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 10,
          ),
          headerDecoration: const pw.BoxDecoration(color: _brandBlue),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellHeight: 24,
          cellAlignments: const {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.centerLeft,
          },
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(3),
          },
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
      ],
    );
  }

  pw.Widget _buildTextSection(String title, String text) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 13,
            color: _brandBlue,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(text, style: const pw.TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  pw.Widget _buildPhotosSection(
    pw.MemoryImage? reference,
    pw.MemoryImage? today,
  ) {
    final entries = <MapEntry<String, pw.MemoryImage>>[
      if (reference != null) MapEntry("Reference Photo", reference),
      if (today != null) MapEntry("Check-In Photo", today),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "Photos",
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 13,
            color: _brandBlue,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: entries
              .map(
                (entry) => pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          entry.key,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Container(
                          height: 160,
                          decoration: pw.BoxDecoration(
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 6,
                            verticalRadius: 6,
                            child: pw.Image(entry.value, fit: pw.BoxFit.cover),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  PdfColor _resultColor(String overall) {
    switch (OverallResult.classify(overall)) {
      case OverallResult.excellent:
        return PdfColors.green;
      case OverallResult.good:
        return PdfColors.blue;
      case OverallResult.needsWork:
        return PdfColors.orange;
      case OverallResult.insufficient:
        return PdfColors.red;
    }
  }

  /// Best-effort only -- a photo that can't be fetched (network error,
  /// expired link, empty URL) is simply left out of the PDF rather than
  /// failing the whole export. Uses the same photo URLs already shown
  /// successfully on screen via Image.network, so a working URL here
  /// should fetch the same bytes.
  Future<pw.MemoryImage?> _tryFetchImage(String url) async {
    if (url.isEmpty) return null;

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) return null;

      return pw.MemoryImage(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
  }

  String _formatDisplayDate(dynamic createdAt) {
    if (createdAt is! Timestamp) return "-";
    final date = createdAt.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  String _formatFileDate(dynamic createdAt) {
    if (createdAt is! Timestamp) return "unknown-date";
    final date = createdAt.toDate();
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return "${date.year}-$mm-$dd";
  }
}
