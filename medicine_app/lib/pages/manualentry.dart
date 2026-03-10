import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select Date';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Select Time';
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    final p = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  Future<void> _saveMedicine({required bool addAnother}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in first.')));
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start date, end date and time.'),
        ),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date.')),
      );
      return;
    }

    if (_isCaregiver &&
        (_selectedRelation == null || _selectedRelation!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select relation.')));
      return;
    }

    if (_isCaregiver &&
        (_selectedPatientId == null || _selectedPatientId!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a patient.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final response = await SecureStoreService.saveMedicine({
        'medicineName': _medicineNameController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'startDate': _formatDate(_startDate),
        'endDate': _formatDate(_endDate),
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
      ).showSnackBar(const SnackBar(content: Text('Medicine saved.')));

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
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save medicine: $e')));
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
        title: const Text('Manual Entry'),
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
        children: const [
          Text(
            'Add a Medicine',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Enter details or assign to your patient. Reminder scheduling happens automatically.',
            style: TextStyle(color: Colors.white70, height: 1.4),
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
                decoration: const InputDecoration(
                  labelText: 'Medicine Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication_outlined),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.science_outlined),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.event),
                      label: Text('Start: ${_formatDate(_startDate)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEndDate,
                      icon: const Icon(Icons.event_available),
                      label: Text('End: ${_formatDate(_endDate)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.access_time),
                label: Text('Time: ${_formatTime(_time)}'),
              ),
              const SizedBox(height: 12),
              if (_isCaregiver) ...[
                DropdownButtonFormField<String>(
                  value: _selectedRelation,
                  decoration: const InputDecoration(
                    labelText: 'Select Relation',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.family_restroom_outlined),
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
                  decoration: const InputDecoration(
                    labelText: 'Select Patient',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: patients
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p['userId']?.toString(),
                          child: Text(
                            p['email']?.toString() ??
                                p['displayName']?.toString() ??
                                'Patient',
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
                decoration: const InputDecoration(
                  labelText: 'Meal Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.restaurant_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Breakfast',
                    child: Text('Breakfast'),
                  ),
                  DropdownMenuItem(value: 'Lunch', child: Text('Lunch')),
                  DropdownMenuItem(value: 'Dinner', child: Text('Dinner')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _mealType = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _mealRelation,
                decoration: const InputDecoration(
                  labelText: 'Meal Relation',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.accessibility_new_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Before Meal',
                    child: Text('Before Meal'),
                  ),
                  DropdownMenuItem(
                    value: 'After Meal',
                    child: Text('After Meal'),
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
                label: Text(_isSaving ? 'Saving...' : 'Save Medicine'),
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
                label: const Text('Save & Add Another'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
