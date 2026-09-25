import 'package:flutter/material.dart';

import '../../models/training_history.dart';
import '../../services/training_history_service.dart';
import 'trainer_history_editor_screen.dart';

class TrainerTrainingHistoryScreen extends StatefulWidget {
  const TrainerTrainingHistoryScreen({super.key});

  @override
  State<TrainerTrainingHistoryScreen> createState() =>
      _TrainerTrainingHistoryScreenState();
}

class _TrainerTrainingHistoryScreenState
    extends State<TrainerTrainingHistoryScreen> {
  final TrainingHistoryService _service = TrainingHistoryService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<TrainingHistory> _allRecords = [];
  List<TrainingHistory> _visibleRecords = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadHistory();
  }

  void _onSearchChanged() {
    _applySearch();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final records = await _service.getAll();
      if (!mounted) return;

      setState(() {
        _allRecords = records;
        _visibleRecords = records;
        _loading = false;
      });
    } on TrainingHistoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load historical training records.';
      });
    }
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = query.isEmpty
        ? _allRecords
        : _allRecords.where((record) {
            return record.participantName.toLowerCase().contains(query) ||
                record.trainingDate.toLowerCase().contains(query) ||
                record.crewType.toLowerCase().contains(query) ||
                record.trainer.toLowerCase().contains(query) ||
                (record.sourceFile ?? '').toLowerCase().contains(query);
          }).toList();

    if (mounted) {
      setState(() {
        _visibleRecords = filtered;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
  }

  DateTime? _parseDate(String value) {
    final text = value.trim();

    final dash = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{2,4})$').firstMatch(text);
    if (dash != null) {
      final day = int.tryParse(dash.group(1)!);
      final month = int.tryParse(dash.group(2)!);
      final rawYear = int.tryParse(dash.group(3)!);
      if (day == null || month == null || rawYear == null) return null;
      final year = rawYear < 100 ? 2000 + rawYear : rawYear;
      return DateTime(year, month, day);
    }

    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(text);
    if (slash != null) {
      final day = int.tryParse(slash.group(1)!);
      final month = int.tryParse(slash.group(2)!);
      final rawYear = int.tryParse(slash.group(3)!);
      if (day == null || month == null || rawYear == null) return null;
      final year = rawYear < 100 ? 2000 + rawYear : rawYear;
      return DateTime(year, month, day);
    }

    return DateTime.tryParse(text);
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}'.toUpperCase();
  }

  List<_TrainingReportGroup> _buildGroups() {
    final groups = <String, _TrainingReportGroup>{};

    for (final record in _visibleRecords) {
      final reportName = (record.sourceFile ?? '').trim().isEmpty
          ? 'Training Report'
          : record.sourceFile!.trim();

      final date = _parseDate(record.trainingDate);

      final key = '${reportName.toLowerCase()}|${record.trainingDate}';

      groups.putIfAbsent(
        key,
        () => _TrainingReportGroup(
          reportName: reportName,
          date: date,
          trainingDate: record.trainingDate,
          crewType: record.crewType,
        ),
      );

      groups[key]!.records.add(record);
    }

    final result = groups.values.toList();

    result.sort((a, b) {
      final aDate = a.date;
      final bDate = b.date;
      if (aDate != null && bDate != null) {
        final comparison = bDate.compareTo(aDate);
        if (comparison != 0) return comparison;
      } else if (aDate != null) {
        return -1;
      } else if (bDate != null) {
        return 1;
      }

      return b.reportName.compareTo(a.reportName);
    });

    return result;
  }

  Map<String, List<_TrainingReportGroup>> _groupByMonth(
    List<_TrainingReportGroup> reports,
  ) {
    final grouped = <String, List<_TrainingReportGroup>>{};

    for (final report in reports) {
      final date = report.date;
      final key = date == null ? 'OTHER' : _monthLabel(date);
      grouped.putIfAbsent(key, () => []).add(report);
    }

    return grouped;
  }

  Future<void> _addRecord() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TrainerHistoryEditorScreen(),
      ),
    );
    if (saved == true) await _loadHistory();
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search participant, date, crew or report',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.black87),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.black87),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF1F3D73),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(_TrainingReportGroup report) {
    final date = report.trainingDate.isEmpty
        ? 'Date not recorded'
        : report.trainingDate;

    final crew = report.crewType.trim().isEmpty
        ? 'Crew Type not recorded'
        : report.crewType;

    final participantCount = report.records.length;
    final photoCount = report.records.fold<int>(
      0,
      (sum, record) => sum + record.photoUrls.length,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _TrainerTrainingReportDetailScreen(
                reportName: report.reportName,
                records: report.records,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F3D73).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF1F3D73),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.reportName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      date,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      crew,
                      style: const TextStyle(
                        color: Color(0xFF1F3D73),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoChip(
                          icon: Icons.people_outline,
                          label: '$participantCount participants',
                        ),
                        _InfoChip(
                          icon: Icons.photo_library_outlined,
                          label: '$photoCount photos',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Colors.black45,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reports = _buildGroups();
    final months = _groupByMonth(reports);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Training History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRecord,
        icon: const Icon(Icons.add),
        label: const Text('Add Report'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            color: const Color(0xFF1F3D73),
            child: _buildSearchField(),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadHistory,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : reports.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.folder_open_outlined,
                                    size: 64,
                                    color: Colors.black26,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchController.text.trim().isEmpty
                                        ? 'No Training Reports'
                                        : 'No Matching Training Reports',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Training reports will appear here by month.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                            children: [
                              for (final entry in months.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 12,
                                    top: 4,
                                  ),
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F3D73),
                                    ),
                                  ),
                                ),
                                ...entry.value.map(_buildReportCard),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

class _TrainingReportGroup {
  _TrainingReportGroup({
    required this.reportName,
    required this.date,
    required this.trainingDate,
    required this.crewType,
  });

  final String reportName;
  final DateTime? date;
  final String trainingDate;
  final String crewType;
  final List<TrainingHistory> records = [];
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(0xFF1F3D73),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerTrainingReportDetailScreen extends StatelessWidget {
  const _TrainerTrainingReportDetailScreen({
    required this.reportName,
    required this.records,
  });

  final String reportName;
  final List<TrainingHistory> records;

  Future<void> _edit(BuildContext context, TrainingHistory record) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrainerHistoryEditorScreen(record: record),
      ),
    );
  }

  Future<void> _delete(BuildContext context, TrainingHistory record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Training Record?'),
        content: Text(
          'Delete the training record for ${record.participantName.isEmpty ? 'this participant' : record.participantName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await TrainingHistoryService().deleteRecord(record.id);
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } on TrainingHistoryException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
        title: const Text(
          'Training Report',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            reportName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${records.length} participants',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          ...records.map(
            (record) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  backgroundColor:
                      const Color(0xFF1F3D73).withValues(alpha: 0.10),
                  child: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF1F3D73),
                  ),
                ),
                title: Text(
                  record.participantName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${record.trainingDate}  •  ${record.crewType}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _edit(context, record);
                    } else if (value == 'delete') {
                      _delete(context, record);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        title: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () => _edit(context, record),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
