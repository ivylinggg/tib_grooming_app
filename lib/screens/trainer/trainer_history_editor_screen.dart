import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/training_history.dart';
import '../../services/auth_service.dart';

class TrainerHistoryEditorScreen extends StatefulWidget {
  const TrainerHistoryEditorScreen({
    super.key,
    this.record,
  });

  final TrainingHistory? record;

  bool get isEditing => record != null;

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

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final record = widget.record;

    if (record != null) {
      _participantController.text = record.participantName;
      _dateController.text = record.trainingDate;
      _crewController.text = record.crewType;
      _trainerController.text = record.trainer;
      _reviewController.text = record.trainerReview;
      _specialRemarksController.text = record.specialRemarks;
      _ccdRemarksController.text = record.ccdRemarks;
      _sourceController.text = record.sourceFile ?? '';
    }
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

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
      'photoUrls': widget.record?.photoUrls ?? <String>[],
    };

    try {
      final firestore = FirebaseFirestore.instance;

      if (widget.isEditing) {
        await firestore
            .collection('training_history')
            .doc(widget.record!.id)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();

        await firestore
            .collection('training_history')
            .add(data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Training record updated.'
                : 'Training record created.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'permission-denied'
                ? 'You do not have permission to edit training history.'
                : 'Could not save the training record.',
          ),
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

  InputDecoration _decoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      alignLabelWithHint: true,
    );
  }

  Widget _multilineField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      minLines: 4,
      maxLines: 8,
      textCapitalization: TextCapitalization.sentences,
      decoration: _decoration(label, icon),
      validator: required
          ? (value) =>
              value == null || value.trim().isEmpty ? 'Required' : null
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.isEditing;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          editing ? 'Edit Training Record' : 'Add Training Report',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                editing
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
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
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
                        : editing
                            ? 'Save Changes'
                            : 'Create Training Record',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (editing)
                const Text(
                  'Training photos can be managed from the training record.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
