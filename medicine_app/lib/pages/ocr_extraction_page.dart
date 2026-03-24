import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../features/ocr/gemini_prescription_service.dart';
import '../features/secure/data/secure_store_service.dart';

class OcrExtractionPage extends StatefulWidget {
  const OcrExtractionPage({super.key});

  @override
  State<OcrExtractionPage> createState() => _OcrExtractionPageState();
}

class _OcrExtractionPageState extends State<OcrExtractionPage> {
  final _formKey = GlobalKey<FormState>();
  final _medicineNameController = TextEditingController();
  final _dosageController = TextEditingController();

  XFile? _selectedImage;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _time;
  String _mealType = 'Breakfast';
  String _mealRelation = 'Before Meal';
  bool _isExtracting = false;
  bool _isSaving = false;
  bool _isCaregiver = false;
  List<Map<String, dynamic>> _extractedItems = [];
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

  Future<void> _pickImage(ImageSource source) async {
    final image = await ImagePicker().pickImage(source: source);
    if (image == null) return;
    setState(() {
      _selectedImage = image;
    });
  }

  Future<void> _showImageSourceChooser() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Capture from Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Upload from Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    await _pickImage(source);
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final input = value.trim().toUpperCase();
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$',
    ).firstMatch(input);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final meridiem = match.group(3);
    if (hour == null || minute == null) return null;
    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _extractUsingGemini() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose an image first.')),
      );
      return;
    }

    if (!GeminiPrescriptionService.instance.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add GEMINI_API_KEY to .env before running OCR.'),
        ),
      );
      return;
    }

    setState(() => _isExtracting = true);
    try {
      final extraction = await GeminiPrescriptionService.instance
          .extractFromImagePath(_selectedImage!.path);
      final items = _mapExtractionToItems(extraction);
      if (items.isEmpty) {
        throw Exception('No medicines detected in the image.');
      }
      if (!mounted) return;
      setState(() {
        _extractedItems = items;
        _applyExtracted(items.first);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extraction complete. Please verify fields.'),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Firebase error (${e.code}): ${e.message ?? "Unknown error"}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to extract data: $e')));
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  List<Map<String, dynamic>> _mapExtractionToItems(
    PrescriptionExtraction extraction,
  ) {
    final items = <Map<String, dynamic>>[];
    for (final med in extraction.medicines) {
      items.add(_toUiItem(med, extraction));
    }
    if (items.isEmpty) {
      items.add(_fallbackFromRawText(extraction.rawText));
    }
    return items;
  }

  Map<String, dynamic> _toUiItem(
    PrescriptionMedicine medicine,
    PrescriptionExtraction extraction,
  ) {
    final timingText = medicine.timing.isNotEmpty ? medicine.timing.first : '';
    return {
      'medicineName': medicine.name,
      'dosage': medicine.dosage,
      'time': timingText,
      'startDate': extraction.startDateText,
      'endDate': extraction.endDateText,
      'mealType': _mealType,
      'mealRelation': _mealRelation,
    };
  }

  Map<String, dynamic> _fallbackFromRawText(String text) {
    final normalized = text.replaceAll('\r', '');
    final lines = normalized
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final dosageMatch = RegExp(
      r'\b\d+(?:\.\d+)?\s*(?:mg|mcg|g|ml|iu|units?|tablet|tab|capsule|cap|drops?)\b',
      caseSensitive: false,
    ).firstMatch(normalized);
    final timeMatch = RegExp(
      r'\b\d{1,2}:\d{2}\s*(?:AM|PM)?\b',
      caseSensitive: false,
    ).firstMatch(normalized);

    String name = '';
    for (final line in lines) {
      if (line.toLowerCase().startsWith('rx')) continue;
      if (line.toLowerCase().contains('patient')) continue;
      if (line.toLowerCase().contains('doctor')) continue;
      final cleaned = line
          .replaceAll(RegExp(r'[^A-Za-z0-9\s\-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.length >= 3) {
        name = cleaned;
        break;
      }
    }

    return {
      'medicineName': name.isNotEmpty ? name : 'Medicine',
      'dosage': dosageMatch?.group(0)?.trim() ?? '',
      'time': timeMatch?.group(0)?.trim() ?? '',
      'startDate': '',
      'endDate': '',
      'mealType': _mealType,
      'mealRelation': _mealRelation,
    };
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? now,
      firstDate: _startDate ?? DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => _time = picked);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select Date';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateLabel(DateTime? date) {
    if (date == null) return 'Select Date';
    return DateFormat.yMMMd().format(date);
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Select Time';
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    final p = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  void _applyExtracted(Map<String, dynamic> item) {
    _medicineNameController.text = item['medicineName']?.toString() ?? '';
    _dosageController.text = item['dosage']?.toString() ?? '';
    _startDate = _parseDate(item['startDate']?.toString());
    _endDate = _parseDate(item['endDate']?.toString());
    _time = _parseTime(item['time']?.toString());

    final mealType = item['mealType']?.toString().trim() ?? '';
    if (['Breakfast', 'Lunch', 'Dinner'].contains(mealType)) {
      _mealType = mealType;
    }

    final mealRelation = item['mealRelation']?.toString().trim() ?? '';
    if (['Before Meal', 'After Meal'].contains(mealRelation)) {
      _mealRelation = mealRelation;
    }
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
        'source': 'ocr',
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
          _selectedImage = null;
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
      if (mounted) setState(() => _isSaving = false);
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
        title: const Text('OCR Extraction'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _heroCard(),
              const SizedBox(height: 12),
              _captureCard(),
              const SizedBox(height: 12),
              _extractedList(),
              const SizedBox(height: 12),
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
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Scan or Upload Prescription',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'We will auto-fill medicine details. Review and save.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _captureCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _showImageSourceChooser,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D47A1),
                side: const BorderSide(color: Color(0xFF0D47A1)),
              ),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Capture / Upload Image'),
            ),
            const SizedBox(height: 8),
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_selectedImage!.path),
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isExtracting ? null : _extractUsingGemini,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
              ),
              icon: _isExtracting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              label: Text(_isExtracting ? 'Reading...' : 'Upload & Extract'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _extractedList() {
    if (_extractedItems.isEmpty) return const SizedBox.shrink();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Extracted medicines (tap Apply):',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _extractedItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _extractedItems[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['medicineName']?.toString().isNotEmpty ==
                                      true
                                  ? item['medicineName'].toString()
                                  : 'Medicine ${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dosage: ${item['dosage'] ?? '-'} • Time: ${item['time'] ?? '-'}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            Text(
                              'Dates: ${item['startDate'] ?? '-'} - ${item['endDate'] ?? '-'}',
                              style: const TextStyle(color: Colors.black45),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _applyExtracted(item));
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _formCard(
    List<String> relations,
    List<Map<String, dynamic>> patients,
    String? selectedPatientInView,
  ) {
    final relationsWidget = !_isCaregiver
        ? const SizedBox.shrink()
        : Column(
            children: [
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
          );

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
                      label: Text('Start: ${_formatDateLabel(_startDate)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEndDate,
                      icon: const Icon(Icons.event_available),
                      label: Text('End: ${_formatDateLabel(_endDate)}'),
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
              relationsWidget,
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
                  if (value != null) setState(() => _mealType = value);
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
                  if (value != null) setState(() => _mealRelation = value);
                },
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () => _saveMedicine(addAnother: false),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
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
                icon: const Icon(Icons.playlist_add_outlined),
                label: const Text('Save and Add Medicine'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: const Color(0xFF0D47A1),
                  side: const BorderSide(color: Color(0xFF0D47A1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
