import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/captured_image.dart';
import '../../models/training_history.dart';
import '../../services/image_service.dart';
import '../../services/trainer_drive_service.dart';
import '../../services/training_history_service.dart';

class TrainerHistoryEditorScreen extends StatefulWidget {
  const TrainerHistoryEditorScreen({super.key, this.record});

  final TrainingHistory? record;

  @override
  State<TrainerHistoryEditorScreen> createState() =>
      _TrainerHistoryEditorScreenState();
}

class _TrainerHistoryEditorScreenState
    extends State<TrainerHistoryEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _participantController = TextEditingController();
  final _dateController = TextEditingController();
  final _crewController = TextEditingController();
  final _trainerController = TextEditingController();
  final _reviewController = TextEditingController();
  final _specialRemarksController = TextEditingController();
  final _ccdRemarksController = TextEditingController();
  final _sourceController = TextEditingController();

  final TrainingHistoryService _historyService = TrainingHistoryService();
  final TrainerDriveService _driveService = TrainerDriveService();
  final ImageService _imageService = ImageService();

  bool _saving = false;
  bool _uploadingPhoto = false;
  List<String> _photoUrls = [];

  bool get _editing => widget.record != null;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    if (record == null) return;

    _participantController.text = record.participantName;
    _dateController.text = record.trainingDate;
    _crewController.text = record.crewType;
    _trainerController.text = record.trainer;
    _reviewController.text = record.trainerReview;
    _specialRemarksController.text = record.specialRemarks;
    _ccdRemarksController.text = record.ccdRemarks;
    _sourceController.text = record.sourceFile ?? '';
    _photoUrls = [...record.photoUrls];
  }

  @override
  void dispose() {
    _participantController.dispose();
    _dateController.dispose();
    _crewController.dispose();
    _trainerController.dispose();
    _reviewController.dispose();
    _specialRemarksController.dispose();
    _ccdRemarksController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_uploadingPhoto) return;

    final participant = _participantController.text.trim();
    final date = _dateController.text.trim();

    if (participant.isEmpty || date.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter Participant Name and Training Date first.'),
        ),
      );
      return;
    }

    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Choose from Files'),
                onTap: () => Navigator.pop(context, 'files'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    CapturedImage? image;

    if (source == 'gallery') {
      image = await _imageService.pickFromGallery();
    } else if (source == 'files') {
      image = await _imageService.pickFromFiles();
    } else {
      final result = await _imageService.pickFromCamera();
      image = result.image;
    }

    if (image == null) return;

    setState(() {
      _uploadingPhoto = true;
    });

    try {
      final bytes = await image.readAsBytes();
      final fileName = image.name.trim().isEmpty
          ? 'training_photo.jpg'
          : image.name.trim();
      final url = await _driveService.uploadTrainingPhoto(
        bytes: bytes,
        fileName: fileName,
        trainingDate: date,
        participantName: participant,
      );

      if (!mounted) return;

      final updatedUrls = [..._photoUrls, url];
      setState(() {
        _photoUrls = updatedUrls;
        _uploadingPhoto = false;
      });

      if (_editing) {
        await _historyService.updatePhotos(widget.record!.id, updatedUrls);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Training photo uploaded successfully.')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _uploadingPhoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    try {
      final data = <String, dynamic>{
        'participantName': _participantController.text.trim(),
        'trainingDate': _dateController.text.trim(),
        'crewType': _crewController.text.trim(),
        'trainer': _trainerController.text.trim(),
        'trainerReview': _reviewController.text.trim(),
        'specialRemarks': _specialRemarksController.text.trim(),
        'ccdRemarks': _ccdRemarksController.text.trim(),
        'sourceFile': _sourceController.text.trim().isEmpty
            ? null
            : _sourceController.text.trim(),
        'photoUrls': _photoUrls,
      };

      if (_editing) {
        await _historyService.updateRecord(widget.record!.id, data);
      } else {
        final record = TrainingHistory(
          id: '',
          participantName: data['participantName'] as String,
          trainingDate: data['trainingDate'] as String,
          crewType: data['crewType'] as String,
          trainer: data['trainer'] as String,
          photoUrls: _photoUrls,
          trainerReview: data['trainerReview'] as String,
          specialRemarks: data['specialRemarks'] as String,
          ccdRemarks: data['ccdRemarks'] as String,
          sourceFile: data['sourceFile'] as String?,
        );
        await _historyService.createRecord(record);
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on TrainingHistoryException catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the training record.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      alignLabelWithHint: true,
    );
  }

  Widget _multilineField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      minLines: 4,
      maxLines: 8,
      textCapitalization: TextCapitalization.sentences,
      decoration: _decoration(label, icon),
    );
  }

  Widget _photoSection() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.photo_library_outlined),
                SizedBox(width: 10),
                Text(
                  'Training Photos',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_photoUrls.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No photos added yet.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              ..._photoUrls.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 0.75,
                      child: Image.network(
                        entry.value,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFFEDEDED),
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _uploadingPhoto ? null : _pickAndUploadPhoto,
                icon: _uploadingPhoto
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _uploadingPhoto ? 'Uploading photo...' : 'Add New Photo',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_editing ? 'Edit Training Record' : 'Add Training Report'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _editing
                    ? 'Update historical training information'
                    : 'Create a new historical training record',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _participantController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(
                  'Participant Name',
                  Icons.person_outline,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Participant name is required'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: _decoration(
                  'Training Date',
                  Icons.event_outlined,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Training date is required'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _crewController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(
                  'Crew Type',
                  Icons.groups_outlined,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Crew type is required'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _trainerController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(
                  'Trainer',
                  Icons.school_outlined,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Trainer is required'
                        : null,
              ),
              const SizedBox(height: 16),
              _multilineField(
                _reviewController,
                "Trainer's Review",
                Icons.rate_review_outlined,
              ),
              const SizedBox(height: 16),
              _multilineField(
                _specialRemarksController,
                'Special Remarks',
                Icons.warning_amber_outlined,
              ),
              const SizedBox(height: 16),
              _multilineField(
                _ccdRemarksController,
                'CCD Remarks',
                Icons.fact_check_outlined,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sourceController,
                minLines: 2,
                maxLines: 4,
                decoration: _decoration(
                  'Source',
                  Icons.description_outlined,
                ),
              ),
              const SizedBox(height: 20),
              _photoSection(),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving || _uploadingPhoto ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving
                        ? 'Saving...'
                        : _editing
                            ? 'Save Changes'
                            : 'Create Training Record',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
