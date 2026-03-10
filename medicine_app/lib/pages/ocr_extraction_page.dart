import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../features/secure/data/secure_store_service.dart';

class OcrExtractionPage extends StatefulWidget {
  const OcrExtractionPage({super.key});

  @override
  State<OcrExtractionPage> createState() => _OcrExtractionPageState();
}

class _OcrExtractionPageState extends State<OcrExtractionPage> {
  static const String _host =
      "backend-medicine-app-sveri-hackathon.onrender.com";

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
    final raw = value.trim();
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
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

    setState(() => _isExtracting = true);
    try {
      final uri = Uri.https(_host, "/medicine/extract-ocr");
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('file', _selectedImage!.path),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      Map<String, dynamic> body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'OCR extraction failed (${response.statusCode}): Invalid response format.',
            ),
          ),
        );
        return;
      }

      if (response.statusCode != 200 || body['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              body['error']?.toString() ??
                  'OCR extraction failed (${response.statusCode}).',
            ),
          ),
        );
        return;
      }

      final items = (body['items'] as List?) ?? [];
      if (items.isNotEmpty) {
        _extractedItems = items
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _applyExtracted(_extractedItems.first);
      } else {
        _extractedItems = [];
        _applyExtracted(body);
      }

      setState(() {});

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
        backgroundColor: const Color(0xFF87CEEB),
        centerTitle: true,
        title: const Text('OCR Extraction'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _showImageSourceChooser,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Capture / Upload Image'),
                ),
                const SizedBox(height: 8),
                if (_selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_selectedImage!.path),
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _isExtracting ? null : _extractUsingGemini,
                  child: _isExtracting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Upload & Extract'),
                ),
                if (_extractedItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Extracted medicines (tap Apply to edit/save):',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _extractedItems.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _extractedItems[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            item['medicineName']?.toString().isNotEmpty == true
                                ? item['medicineName'].toString()
                                : 'Medicine ${index + 1}',
                          ),
                          subtitle: Text(
                            'Dosage: ${item['dosage']?.toString() ?? '-'}'
                            '\nTime: ${item['time']?.toString() ?? '-'}'
                            '\nDates: ${item['startDate'] ?? ''} - ${item['endDate'] ?? ''}',
                          ),
                          trailing: TextButton(
                            onPressed: () {
                              setState(() {
                                _applyExtracted(item);
                              });
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _medicineNameController,
                  decoration: const InputDecoration(
                    labelText: 'Medicine Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Dosage',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickStartDate,
                        child: Text('Start: ${_formatDate(_startDate)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickEndDate,
                        child: Text('End: ${_formatDate(_endDate)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _pickTime,
                  child: Text('Time: ${_formatTime(_time)}'),
                ),
                const SizedBox(height: 12),
                if (_isCaregiver)
                  Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedRelation,
                        decoration: const InputDecoration(
                          labelText: 'Select Relation',
                          border: OutlineInputBorder(),
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
                        ),
                        items: visiblePatients
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
                        onChanged: (value) {
                          setState(() => _selectedPatientId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                DropdownButtonFormField<String>(
                  value: _mealType,
                  decoration: const InputDecoration(
                    labelText: 'Meal Type',
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () => _saveMedicine(addAnother: false),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Medicine'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () => _saveMedicine(addAnother: true),
                  child: const Text('Save and Add Medicine'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
