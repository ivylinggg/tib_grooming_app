import 'package:flutter/material.dart';

import '../../models/training_history.dart';

class TrainingHistoryDetailScreen extends StatelessWidget {
  const TrainingHistoryDetailScreen({
    super.key,
    required this.record,
  });

  final TrainingHistory record;

  String _valueOrFallback(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Not recorded' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(
        title: const Text('Training Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderCard(record: record),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Training Information',
              icon: Icons.event_note,
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Training Date',
                    value: _valueOrFallback(record.trainingDate),
                  ),
                  _InfoRow(
                    label: 'Crew Type',
                    value: _valueOrFallback(record.crewType),
                  ),
                  _InfoRow(
                    label: 'Trainer',
                    value: _valueOrFallback(record.trainer),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Training Photos',
              icon: Icons.photo_library_outlined,
              child: record.photoUrls.isEmpty
                  ? const _EmptyText(
                      'No historical photos have been imported for this record.',
                    )
                  : _PhotoGrid(photoUrls: record.photoUrls),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: "Trainer's Review",
              icon: Icons.rate_review_outlined,
              child: SelectableText(
                _valueOrFallback(record.trainerReview),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Special Remarks',
              icon: Icons.warning_amber_outlined,
              child: SelectableText(
                _valueOrFallback(record.specialRemarks),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'CCD Remarks',
              icon: Icons.fact_check_outlined,
              child: SelectableText(
                _valueOrFallback(record.ccdRemarks),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: Colors.black87,
                ),
              ),
            ),
            if (record.sourceFile != null &&
                record.sourceFile!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Source',
                icon: Icons.description_outlined,
                child: SelectableText(
                  record.sourceFile!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.record});

  final TrainingHistory record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1F3D73),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Participant',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  record.participantName.isEmpty
                      ? 'Unnamed Participant'
                      : record.participantName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  record.crewType.isEmpty
                      ? 'Training Record'
                      : record.crewType,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFF1F3D73),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photoUrls});

  final List<String> photoUrls;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: photoUrls
          .where((url) => url.trim().isNotEmpty)
          .map(
            (url) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PhotoTile(url: url.trim()),
            ),
          )
          .toList(),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenPhotoViewer(url: url),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 0.75,
          child: Image.network(
            url,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              color: Color(0xFFEDEDED),
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 30,
                  color: Colors.black45,
                ),
              ),
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;

              return const ColoredBox(
                color: Color(0xFFF3F3F3),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FullScreenPhotoViewer extends StatelessWidget {
  const _FullScreenPhotoViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Training Photo'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 48,
              ),
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;

              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black54,
        height: 1.5,
      ),
    );
  }
}