import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../features/secure/data/secure_store_service.dart';
import 'add_patient_page.dart';
import 'doctor_chat_page.dart';
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

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return tr('good_morning');
    if (hour >= 12 && hour < 16) return tr('good_afternoon');
    if (hour >= 16 && hour < 21) return tr('good_evening');
    return tr('good_night');
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
                Text(
                  _greetingText(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
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
                    label: Text(tr('add_patient')),
                  ),
                if (role == 'Caregiver') ...[
                  const SizedBox(height: 12),
                  const _CaregiverPatientsSection(),
                ],
                if (role == 'Patient') ...[
                  const SizedBox(height: 12),
                  const _PatientPendingMedicinesSection(),
                ],
                if (role == 'Doctor') ...[
                  const SizedBox(height: 12),
                  const _DoctorAcceptedSection(),
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

  String _formatTime(
    BuildContext context,
    dynamic hourValue,
    dynamic minuteValue,
  ) {
    final hour = int.tryParse(hourValue?.toString() ?? '');
    final minute = int.tryParse(minuteValue?.toString() ?? '');
    if (hour == null || minute == null) return '-';
    final dateTime = DateTime(0, 1, 1, hour, minute);
    return DateFormat.jm(context.locale.toString()).format(dateTime);
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
        ).showSnackBar(SnackBar(content: Text(tr('medicine_deleted'))));
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
        title: Text(tr('delete_patient')),
        content: Text(tr('delete_patient_warning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('delete')),
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
        ).showSnackBar(SnackBar(content: Text(tr('patient_removed'))));
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
      return Text(tr('caregiver_load_failed', args: [_error ?? '']));
    }
    if (_patients.isEmpty) {
      return Text(tr('no_patients'), textAlign: TextAlign.center);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('added_patients'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                        : patient['email']?.toString() ?? tr('patient'),
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
                      child: Text(tr('delete_patient')),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('${tr('relation')}: ${patient['relation']?.toString() ?? '-'}'),
                  Text('${tr('phone')}: ${patient['phoneNumber']?.toString() ?? '-'}'),
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
                                          tr('medicine'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${tr('time')}: ${_formatTime(context, medicine['timeHour'], medicine['timeMinute'])}',
                                    ),
                                    Text('${tr('dosage')}: ${medicine['dosage']?.toString() ?? '-'}'),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _deleting
                                    ? null
                                    : () => _deleteMedicine(
                                        medicine['id']?.toString() ?? '',
                                      ),
                                child: Text(tr('delete')),
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
                    Text(tr('no_medicines_patient')),
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

class _DoctorAcceptedSection extends StatelessWidget {
  const _DoctorAcceptedSection();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final stream = FirebaseFirestore.instance
        .collection('connection_requests')
        .where('doctorUid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'accepted')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('accepted_patients'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    tr('generic_error_with_value', args: ['${snapshot.error}']),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Text(tr('no_accepted_requests'));
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final email =
                        data['patientEmail']?.toString() ?? tr('patient');
                    final patientUid = data['patientUid']?.toString() ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(
                          0xFF0D47A1,
                        ).withOpacity(0.15),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      title: Text(
                        email,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(tr('accepted')),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DoctorChatPage(
                                patientUid: patientUid,
                                patientEmail: email,
                                doctorUid: user.uid,
                              ),
                            ),
                          );
                        },
                        child: Text(tr('open_chat')),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientPendingMedicinesSectionState
    extends State<_PatientPendingMedicinesSection> with WidgetsBindingObserver {
  Timer? _timer;
  bool _loading = true;
  bool _taking = false;
  String? _error;
  int _pendingCount = 0;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTodaySummary();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadTodaySummary(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTodaySummary();
    }
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

  String _formatTime(
    BuildContext context,
    dynamic hourValue,
    dynamic minuteValue,
  ) {
    final hour = int.tryParse(hourValue?.toString() ?? '');
    final minute = int.tryParse(minuteValue?.toString() ?? '');
    if (hour == null || minute == null) return '-';
    final dateTime = DateTime(0, 1, 1, hour, minute);
    return DateFormat.jm(context.locale.toString()).format(dateTime);
  }

  Future<void> _markTaken(String medicineId) async {
    setState(() {
      _taking = true;
      _items = _items
          .where((item) => item['medicineId']?.toString() != medicineId)
          .toList();
      _pendingCount = _items
          .where(
            (item) =>
                (item['status']?.toString().toLowerCase().trim() ?? '') ==
                'pending',
          )
          .length;
    });
    try {
      final response = await SecureStoreService.markMedicineTaken(medicineId);
      if (!mounted) return;
      if (response['error'] != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response['error'].toString())));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('marked_taken'))));
      }
    } finally {
      await _loadTodaySummary();
      if (mounted) setState(() => _taking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingItems = _items
        .where(
          (item) =>
              (item['status']?.toString().toLowerCase().trim() ?? '') ==
              'pending',
        )
        .toList();
    final today = DateTime.now();
    final weekday =
        DateFormat.EEEE(context.locale.toString()).format(today);
    final dateLabel =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Text(tr('pending_medicine_load_failed', args: [_error ?? '']));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: tr('todays_medicines'),
                subtitle: '$weekday, $dateLabel',
                value: pendingItems.length.toString(),
                accent: Colors.blue.shade700,
                accentLight: Colors.blue.shade50,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: tr('refresh'),
              onPressed: _loading ? null : _loadTodaySummary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pendingItems.isEmpty)
          Text(tr('no_pending_today'), textAlign: TextAlign.center)
        else
          ...pendingItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SinglePendingCard(
                item: item,
                formatTime: (h, m) => _formatTime(context, h, m),
                taking: _taking,
                onTaken: () => _markTaken(item['medicineId']?.toString() ?? ''),
              ),
            ),
          ),
      ],
    );
  }
}

class _SinglePendingCard extends StatelessWidget {
  const _SinglePendingCard({
    required this.item,
    required this.formatTime,
    required this.taking,
    required this.onTaken,
  });

  final Map<String, dynamic> item;
  final String Function(dynamic, dynamic) formatTime;
  final bool taking;
  final VoidCallback onTaken;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['medicineName']?.toString() ?? tr('medicine'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${tr('time')}: ${formatTime(item['timeHour'], item['timeMinute'])}'),
                  Text('${tr('dosage')}: ${item['dosage']?.toString() ?? '-'}'),
                ],
              ),
            ),
            if (item['canTakeNow'] == true)
              ElevatedButton(
                onPressed: taking ? null : onTaken,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(72, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: Text(tr('taken')),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    this.subtitle,
    required this.value,
    required this.accent,
    required this.accentLight,
  });

  final String title;
  final String? subtitle;
  final String value;
  final Color accent;
  final Color accentLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                color: accent.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChips extends StatelessWidget {
  const _FeatureChips();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
