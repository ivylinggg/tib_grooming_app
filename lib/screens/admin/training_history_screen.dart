import 'package:flutter/material.dart';

import '../../models/training_history.dart';
import '../../services/training_history_service.dart';
import 'training_history_detail_screen.dart';

class TrainingHistoryScreen extends StatefulWidget {
  const TrainingHistoryScreen({super.key});

  @override
  State<TrainingHistoryScreen> createState() => _TrainingHistoryScreenState();
}

class _TrainingHistoryScreenState extends State<TrainingHistoryScreen> {
  final TrainingHistoryService _service = TrainingHistoryService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = false;
  String? _error;
  List<TrainingHistory> results = [];
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        results = [];
        _error = null;
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _hasSearched = true;
    });

    try {
      final found = await _service.searchByName(query);
      if (!mounted) return;
      setState(() {
        results = found;
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
        _error = 'Unable to search training history.';
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      results = [];
      _error = null;
      _hasSearched = false;
    });
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _search(),
      decoration: InputDecoration(
        hintText: 'Search Staff / Participant Name',
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
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildRecordCard(TrainingHistory record) {
    final date = record.trainingDate.isEmpty ? '-' : record.trainingDate;
    final crew = record.crewType.isEmpty ? 'Crew Type not recorded' : record.crewType;
    final trainer = record.trainer.isEmpty ? 'Trainer not recorded' : record.trainer;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1F3D73).withValues(alpha: 0.10),
          child: const Icon(Icons.history_edu_outlined, color: Color(0xFF1F3D73)),
        ),
        title: Text(record.participantName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('$date  •  $crew\n$trainer'),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrainingHistoryDetailScreen(record: record),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          const Icon(Icons.manage_search, size: 64, color: Colors.black26),
          const SizedBox(height: 16),
          Text(
            _hasSearched ? 'No training history found' : 'Search a Staff / Participant Name',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _hasSearched
                ? 'Try another participant name.'
                : 'View previous training dates, photos, trainer reviews and remarks.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F3D73),
        foregroundColor: Colors.white,
        title: const Text('Training History', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              color: const Color(0xFF1F3D73),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historical Training Records',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Search by Staff / Participant Name',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  _buildSearchField(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading || _searchController.text.trim().isEmpty ? null : _search,
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1F3D73),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
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
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (results.isNotEmpty) ...[
                    Text(
                      '${results.length} matching ${results.length == 1 ? 'record' : 'records'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...results.map(_buildRecordCard),
                  ]
                  else
                    _buildEmptyState(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}