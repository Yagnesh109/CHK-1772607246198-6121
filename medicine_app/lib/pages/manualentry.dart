import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../features/secure/data/secure_store_service.dart';

class ManualEntryPage extends StatefulWidget {
  const ManualEntryPage({super.key});

  @override
  State<ManualEntryPage> createState() => _ManualEntryPageState();
}

class _ManualEntryPageState extends State<ManualEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _medicineNameController = TextEditingController();
  final _dosageController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _time;
  String _mealType = 'Breakfast';
  String _mealRelation = 'Before Meal';
  bool _isSaving = false;
  bool _isCaregiver = false;
  List<Map<String, dynamic>> _patients = [];
  String? _selectedRelation;
  String? _selectedPatientId;

  @override
  void initState() {
    super.initState();
    _loadRoleAndPatients();
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  Future<void> _loadRoleAndPatients() async {
    final profile = await SecureStoreService.getUserProfile();
    final role = profile['role']?.toString().trim();
    if (role != 'Caregiver') return;

    final patientsResponse = await SecureStoreService.getCaregiverPatients();
    final items = (patientsResponse['items'] as List?) ?? [];
    if (!mounted) return;
    setState(() {
      _isCaregiver = true;
      _patients = items
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _syncCaregiverSelection();
    });
  }

  List<String> _caregiverRelations() {
    final values = <String>[];
    for (final patient in _patients) {
      final relation = patient['relation']?.toString().trim() ?? '';
      if (relation.isNotEmpty && !values.contains(relation)) {
        values.add(relation);
      }
    }
    return values;
  }

  List<Map<String, dynamic>> _patientsForSelectedRelation() {
    if (_selectedRelation == null || _selectedRelation!.isEmpty) {
      return _patients;
    }
    return _patients.where((patient) {
      final relation = patient['relation']?.toString().trim() ?? '';
      return relation == _selectedRelation;
    }).toList();
  }

  void _syncCaregiverSelection() {
    final relations = _caregiverRelations();
    if (relations.isEmpty) {
      _selectedRelation = null;
      _selectedPatientId = null;
      return;
    }

    if (_selectedRelation == null || !relations.contains(_selectedRelation)) {
      _selectedRelation = relations.first;
    }

    final visiblePatients = _patientsForSelectedRelation();
    if (visiblePatients.isEmpty) {
      _selectedPatientId = null;
      return;
    }

    final visibleIds = visiblePatients
        .map((patient) => patient['userId']?.toString())
        .whereType<String>()
        .toList();
    if (_selectedPatientId == null ||
        !visibleIds.contains(_selectedPatientId)) {
      _selectedPatientId = visibleIds.first;
    }
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;

    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initial = _endDate ?? _startDate ?? now;
    final first = _startDate ?? DateTime(now.year - 2);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;

    setState(() {
      _endDate = picked;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      _time = picked;
    });
  }

  String _formatDateIso(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatDateLabel(BuildContext context, DateTime? date) {
    if (date == null) return tr('select_date');
    return DateFormat.yMMMd(context.locale.toString()).format(date);
  }

  String _formatTime(BuildContext context, TimeOfDay? time) {
    if (time == null) return tr('select_time');
    final dateTime = DateTime(0, 1, 1, time.hour, time.minute);
    return DateFormat.jm(context.locale.toString()).format(dateTime);
  }

  Future<void> _saveMedicine({required bool addAnother}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('please_log_in_first'))));
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null || _time == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('select_start_end_time'))));
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('end_before_start'))));
      return;
    }

    if (_isCaregiver &&
        (_selectedRelation == null || _selectedRelation!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('select_relation'))));
      return;
    }

    if (_isCaregiver &&
        (_selectedPatientId == null || _selectedPatientId!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('select_patient'))));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final response = await SecureStoreService.saveMedicine({
        'medicineName': _medicineNameController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'startDate': _formatDateIso(_startDate),
        'endDate': _formatDateIso(_endDate),
        'timeHour': _time!.hour,
        'timeMinute': _time!.minute,
        'mealType': _mealType,
        'mealRelation': _mealRelation,
        'source': 'manual',
        'targetPatientId': _isCaregiver ? _selectedPatientId : null,
      });
      if (response['error'] != null) {
        throw Exception(response['error'].toString());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('medicine_saved'))));

      if (addAnother) {
        _formKey.currentState!.reset();
        setState(() {
          _medicineNameController.clear();
          _dosageController.clear();
          _startDate = null;
          _endDate = null;
          _time = null;
          _mealType = 'Breakfast';
          _mealRelation = 'Before Meal';
        });
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('failed_to_save_medicine', args: ['$e']))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final relations = _caregiverRelations();
    final visiblePatients = _patientsForSelectedRelation();
    final selectedPatientInView =
        visiblePatients.any(
          (patient) => patient['userId']?.toString() == _selectedPatientId,
        )
        ? _selectedPatientId
        : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        centerTitle: true,
        title: Text(tr('manual_entry')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _heroCard(),
              const SizedBox(height: 14),
              _formCard(relations, visiblePatients, selectedPatientInView),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('add_medicine_title'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('add_medicine_hint'),
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _formCard(
    List<String> relations,
    List<Map<String, dynamic>> patients,
    String? selectedPatientInView,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _medicineNameController,
                decoration: InputDecoration(
                  labelText: tr('medicine_name'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.medication_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? tr('required')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dosageController,
                decoration: InputDecoration(
                  labelText: tr('dosage'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.science_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? tr('required')
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.event),
                      label: Text(
                        '${tr('start')}: ${_formatDateLabel(context, _startDate)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEndDate,
                      icon: const Icon(Icons.event_available),
                      label: Text(
                        '${tr('end')}: ${_formatDateLabel(context, _endDate)}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.access_time),
                label: Text('${tr('time')}: ${_formatTime(context, _time)}'),
              ),
              const SizedBox(height: 12),
              if (_isCaregiver) ...[
                DropdownButtonFormField<String>(
                  value: _selectedRelation,
                  decoration: InputDecoration(
                    labelText: tr('select_relation'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.family_restroom_outlined),
                  ),
                  items: relations
                      .map(
                        (relation) => DropdownMenuItem<String>(
                          value: relation,
                          child: Text(relation),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRelation = value;
                      _selectedPatientId = null;
                      _syncCaregiverSelection();
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPatientInView,
                  decoration: InputDecoration(
                    labelText: tr('select_patient'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  items: patients
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p['userId']?.toString(),
                          child: Text(
                            p['email']?.toString() ??
                                p['displayName']?.toString() ??
                                tr('patient'),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedPatientId = value),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                value: _mealType,
                decoration: InputDecoration(
                  labelText: tr('meal_type'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.restaurant_outlined),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Breakfast',
                    child: Text(tr('breakfast')),
                  ),
                  DropdownMenuItem(value: 'Lunch', child: Text(tr('lunch'))),
                  DropdownMenuItem(value: 'Dinner', child: Text(tr('dinner'))),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _mealType = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _mealRelation,
                decoration: InputDecoration(
                  labelText: tr('meal_relation'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.accessibility_new_outlined),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Before Meal',
                    child: Text(tr('before_meal')),
                  ),
                  DropdownMenuItem(
                    value: 'After Meal',
                    child: Text(tr('after_meal')),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _mealRelation = value);
                },
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () => _saveMedicine(addAnother: false),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF0D47A1),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? tr('saving') : tr('save_medicine')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () => _saveMedicine(addAnother: true),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.playlist_add_outlined),
                label: Text(tr('save_and_add_another')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
