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
  List<TrainingHistory> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final records = await _service.getAll();
      if (!mounted) return;

      setState(() {
        _records = records;
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
        _error = 'Unable to load training history.';
      });
    }
  }

  List<TrainingHistory> get _filteredRecords {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _records;

    return _records
        .where((record) =>
            record.participantName.toLowerCase().contains(query) ||
            record.crewType.toLowerCase().contains(query) ||
            record.trainingDate.toLowerCase().contains(query) ||
            (record.sourceFile ?? '').toLowerCase().contains(query))
        .toList();
  }

  Future<void> _addRecord() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TrainerHistoryEditorScreen(),
      ),
    );

    if (saved == true) await _load();
  }

  Future<void> _editRecord(TrainingHistory record) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TrainerHistoryEditorScreen(record: record),
      ),
    );

    if (saved == true) await _load();
  }

  Widget _recordCard(TrainingHistory record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF1F3D73).withValues(alpha: 0.10),
          child: const Icon(
            Icons.person_outline,
            color: Color(0xFF1F3D73),
          ),
        ),
        title: Text(
          record.participantName.isEmpty
              ? 'Unnamed Participant'
              : record.participantName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${record.trainingDate.isEmpty ? '-' : record.trainingDate}\n'
            '${record.crewType.isEmpty ? 'Crew Type not recorded' : record.crewType}',
          ),
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Edit',
          onPressed: () => _editRecord(record),
          icon: const Icon(Icons.edit_outlined),
        ),
        onTap: () => _editRecord(record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _filteredRecords;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
        title: const Text(
          'Manage Training History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            color: const Color(0xFF1F3D73),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search participant, date, crew or source',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 64,
                            color: Colors.black26,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No Training Records',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add a training report to start managing history.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Text(
                      '${records.length} record${records.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    ...records.map(_recordCard),
                    const SizedBox(height: 80),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
