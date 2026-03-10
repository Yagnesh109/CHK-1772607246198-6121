import 'dart:async';

import 'package:flutter/material.dart';
import '../features/secure/data/secure_store_service.dart';
import 'add_patient_page.dart';
import '../widgets/app_sidebar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<Map<String, dynamic>> _loadProfile() {
    return SecureStoreService.getUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF87CEEB),
        centerTitle: true,
        title: const Text(
          'MediMind',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
      ),
      drawer: const AppSidebar(),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadProfile(),
        builder: (context, snapshot) {
          final profile = snapshot.data ?? {};
          final role = profile['role']?.toString() ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Welcome to MediMind',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (role == 'Caregiver')
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddPatientPage(),
                        ),
                      );
                      if (mounted) {
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Add Patient'),
                  ),
                if (role == 'Caregiver') ...[
                  const SizedBox(height: 12),
                  const _CaregiverPatientsSection(),
                ],
                if (role == 'Patient') ...[
                  const SizedBox(height: 12),
                  const _PatientPendingMedicinesSection(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PatientPendingMedicinesSection extends StatefulWidget {
  const _PatientPendingMedicinesSection();

  @override
  State<_PatientPendingMedicinesSection> createState() =>
      _PatientPendingMedicinesSectionState();
}

class _CaregiverPatientsSection extends StatefulWidget {
  const _CaregiverPatientsSection();

  @override
  State<_CaregiverPatientsSection> createState() =>
      _CaregiverPatientsSectionState();
}

class _CaregiverPatientsSectionState extends State<_CaregiverPatientsSection> {
  bool _loading = true;
  bool _deleting = false;
  bool _deletingPatient = false;
  String? _error;
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _medicines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final patientsResponse = await SecureStoreService.getCaregiverPatients();
      if (patientsResponse['error'] != null) {
        throw Exception(patientsResponse['error'].toString());
      }
      final medicinesResponse = await SecureStoreService.getMedicines();
      if (medicinesResponse['error'] != null) {
        throw Exception(medicinesResponse['error'].toString());
      }

      if (!mounted) return;
      final patients = (patientsResponse['items'] as List?) ?? [];
      final medicines = (medicinesResponse['items'] as List?) ?? [];
      setState(() {
        _patients = patients
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _medicines = medicines
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatTime(dynamic hourValue, dynamic minuteValue) {
    final hour = int.tryParse(hourValue?.toString() ?? '');
    final minute = int.tryParse(minuteValue?.toString() ?? '');
    if (hour == null || minute == null) return '-';
    final isAm = hour < 12;
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:${minute.toString().padLeft(2, '0')} ${isAm ? 'AM' : 'PM'}';
  }

  Future<void> _deleteMedicine(String medicineId) async {
    if (medicineId.trim().isEmpty) return;
    setState(() => _deleting = true);
    try {
      final response = await SecureStoreService.deleteMedicine(medicineId);
      if (!mounted) return;
      if (response['error'] != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response['error'].toString())));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Medicine deleted.')));
      }
      await _load();
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _deletePatient(Map<String, dynamic> patient) async {
    final patientId = patient['userId']?.toString() ?? '';
    if (patientId.trim().isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Patient'),
        content: const Text(
          'This will remove this patient from your caregiver list. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingPatient = true);
    try {
      final response = await SecureStoreService.deleteCaregiverPatient(
        patientId,
      );
      if (!mounted) return;
      if (response['error'] != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response['error'].toString())));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Patient removed.')));
      }
      await _load();
    } finally {
      if (mounted) setState(() => _deletingPatient = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Text('Failed to load caregiver data: $_error');
    }
    if (_patients.isEmpty) {
      return const Text('No patients added yet.', textAlign: TextAlign.center);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Added Patients',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        for (final patient in _patients) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient['displayName']?.toString().trim().isNotEmpty == true
                        ? patient['displayName'].toString()
                        : patient['email']?.toString() ?? 'Patient',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _deletingPatient
                          ? null
                          : () => _deletePatient(patient),
                      child: const Text('Delete Patient'),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Relation: ${patient['relation']?.toString() ?? '-'}'),
                  Text('Phone: ${patient['phoneNumber']?.toString() ?? '-'}'),
                  const SizedBox(height: 8),
                  ..._medicines
                      .where(
                        (medicine) =>
                            medicine['patientUserId']?.toString() ==
                            patient['userId']?.toString(),
                      )
                      .map(
                        (medicine) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      medicine['medicineName']?.toString() ??
                                          'Medicine',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Time: ${_formatTime(medicine['timeHour'], medicine['timeMinute'])}',
                                    ),
                                    Text(
                                      'Dosage: ${medicine['dosage']?.toString() ?? '-'}',
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _deleting
                                    ? null
                                    : () => _deleteMedicine(
                                        medicine['id']?.toString() ?? '',
                                      ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (_medicines
                      .where(
                        (medicine) =>
                            medicine['patientUserId']?.toString() ==
                            patient['userId']?.toString(),
                      )
                      .isEmpty)
                    const Text('No medicines for this patient.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PatientPendingMedicinesSectionState
    extends State<_PatientPendingMedicinesSection> {
  Timer? _timer;
  bool _loading = true;
  bool _taking = false;
  String? _error;
  int _pendingCount = 0;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadTodaySummary();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadTodaySummary(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTodaySummary() async {
    try {
      final response = await SecureStoreService.getTodayMedicineSummary();
      if (!mounted) return;
      if (response['error'] != null) {
        setState(() {
          _error = response['error'].toString();
          _loading = false;
        });
        return;
      }
      final items = (response['items'] as List?) ?? [];
      setState(() {
        _pendingCount =
            int.tryParse(response['pendingCount']?.toString() ?? '0') ?? 0;
        _items = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatTime(dynamic hourValue, dynamic minuteValue) {
    final hour = int.tryParse(hourValue?.toString() ?? '');
    final minute = int.tryParse(minuteValue?.toString() ?? '');
    if (hour == null || minute == null) return '-';
    final isAm = hour < 12;
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:${minute.toString().padLeft(2, '0')} ${isAm ? 'AM' : 'PM'}';
  }

  Future<void> _markTaken(String medicineId) async {
    setState(() => _taking = true);
    try {
      final response = await SecureStoreService.markMedicineTaken(medicineId);
      if (!mounted) return;
      if (response['error'] != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response['error'].toString())));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicine marked as taken.')),
        );
      }
      await _loadTodaySummary();
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingItems = _items
        .where((item) => (item['status']?.toString().trim() ?? '') == 'Pending')
        .toList();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Text('Pending medicine load failed: $_error');
    }
    if (pendingItems.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Today Pending Medicines Count: $_pendingCount',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Text(
            'No pending medicines for today.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Today Pending Medicines Count: $_pendingCount',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pending medicines to take today',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        for (final item in pendingItems) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['medicineName']?.toString() ?? 'Medicine',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Time: ${_formatTime(item['timeHour'], item['timeMinute'])}',
                        ),
                        Text('Dosage: ${item['dosage']?.toString() ?? '-'}'),
                      ],
                    ),
                  ),
                  if (item['canTakeNow'] == true)
                    ElevatedButton(
                      onPressed: _taking
                          ? null
                          : () => _markTaken(
                              item['medicineId']?.toString() ?? '',
                            ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(64, 34),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: const Text('Taken'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
