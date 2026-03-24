import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_medicine_page.dart';
import '../core/navigation/route_observer.dart';
import '../features/secure/data/secure_store_service.dart';
import 'add_patient_page.dart';
import 'doctor_chat_page.dart';
import '../widgets/app_sidebar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final GlobalKey<_PatientDashboardState> _patientDashboardKey =
      GlobalKey<_PatientDashboardState>();
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
                  _PatientDashboard(
                    key: _patientDashboardKey,
                    onAddMedicine: () async {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const AddMedicinePage(),
                        ),
                      );
                      if (mounted && result == true) {
                        _patientDashboardKey.currentState?.reload();
                      }
                    },
                  ),
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

class _PatientDashboard extends StatefulWidget {
  const _PatientDashboard({Key? key, required this.onAddMedicine})
      : super(key: key);

  final Future<void> Function() onAddMedicine;

  @override
  State<_PatientDashboard> createState() => _PatientDashboardState();
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

class _PatientDashboardState extends State<_PatientDashboard>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _loading = true;
  bool _taking = false;
  String? _error;
  int _pendingCount = 0;
  List<Map<String, dynamic>> _items = [];
  final Set<String> _locallyTaken = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTodaySummary();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadTodaySummary(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void reload() {
    _loadTodaySummary();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTodaySummary();
    }
  }

  Future<void> _loadTodaySummary() async {
    try {
      // Use full medicines list to avoid backend summary cache issues.
      final response = await SecureStoreService.getMedicines();
      if (!mounted) return;
      if (response['error'] != null) {
        setState(() {
          _error = response['error'].toString();
          _loading = false;
        });
        return;
      }
      final items = (response['items'] as List?) ?? [];
      final now = DateTime.now();
      final todayDate =
          DateTime(now.year, now.month, now.day); // zeroed time for compare

      DateTime? _parseDate(dynamic value) {
        if (value == null) return null;
        final str = value.toString();
        if (str.isEmpty) return null;
        // Accept ISO or yyyy-MM-dd
        try {
          return DateTime.parse(str);
        } catch (_) {
          return null;
        }
      }

      List<Map<String, dynamic>> filtered = [];
      for (final e in items) {
        final map = Map<String, dynamic>.from(e as Map);
        final id = map['id']?.toString() ?? map['medicineId']?.toString() ?? '';
        final start = _parseDate(map['startDate']);
        final end = _parseDate(map['endDate']);
        final startDay = start != null
            ? DateTime(start.year, start.month, start.day)
            : todayDate;
        final endDay =
            end != null ? DateTime(end.year, end.month, end.day) : null;

        final isTodayInRange =
            !todayDate.isBefore(startDay) && (endDay == null || !todayDate.isAfter(endDay));
        if (!isTodayInRange) continue;

        // If user marked as taken locally, reflect immediately.
        if (id.isNotEmpty && _locallyTaken.contains(id)) {
          map['status'] = 'taken';
        }
        final statusRaw = (map['status'] ?? '').toString().toLowerCase().trim();
        // Simple "can take now": enable when current time is at/after scheduled time.
        final hour = int.tryParse(map['timeHour']?.toString() ?? '');
        final minute = int.tryParse(map['timeMinute']?.toString() ?? '');
        if (hour != null && minute != null) {
          final scheduled = DateTime(
            todayDate.year,
            todayDate.month,
            todayDate.day,
            hour,
            minute,
          );
          map['canTakeNow'] = !now.isBefore(scheduled);
        }

        filtered.add(map);
      }

      setState(() {
        _items = filtered;
        _pendingCount = filtered
            .where(
              (item) =>
                  (item['status']?.toString().toLowerCase().trim() ?? 'pending') ==
                  'pending',
            )
            .length;
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
      if (medicineId.isNotEmpty) {
        _locallyTaken.add(medicineId);
      }
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
              (item['status']?.toString().toLowerCase().trim() ?? 'pending') ==
              'pending',
        )
        .toList();
    final today = DateTime.now();
    final dateLabel = DateFormat.yMMMMd(context.locale.toString()).format(today);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Text(tr('pending_medicine_load_failed', args: [_error ?? '']));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SloganCard(),
        const SizedBox(height: 12),
        _SummaryCard(
          dateLabel: dateLabel,
          pendingCount: _pendingCount,
          onRefresh: _loadTodaySummary,
          loading: _loading,
        ),
        const SizedBox(height: 16),
        Text(
          tr('todays_schedule'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _ScheduleCard(
          pendingItems: pendingItems,
          taking: _taking,
          formatTime: (h, m) => _formatTime(context, h, m),
          onTaken: (id) => _markTaken(id),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _taking
                ? null
                : () async {
                    await widget.onAddMedicine();
                  },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: const Color(0xFF1E88E5),
            ),
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            label: Text(
              tr('add_medicine'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SloganCard extends StatelessWidget {
  const _SloganCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFEBF4FF), Color(0xFFDCEBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            tr('health_is_wealth'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('health_is_wealth_subtitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF3A4A67),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.dateLabel,
    required this.pendingCount,
    required this.onRefresh,
    required this.loading,
  });

  final String dateLabel;
  final int pendingCount;
  final VoidCallback onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_today, color: Color(0xFF0D47A1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('today_label'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  pendingCount.toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  tr('pending_label'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: tr('refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.pendingItems,
    required this.taking,
    required this.formatTime,
    required this.onTaken,
  });

  final List<Map<String, dynamic>> pendingItems;
  final bool taking;
  final String Function(dynamic, dynamic) formatTime;
  final Function(String) onTaken;

  @override
  Widget build(BuildContext context) {
    if (pendingItems.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
          child: Column(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 48, color: Colors.blue.shade300),
              const SizedBox(height: 10),
              Text(
                tr('no_pending_today'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr('no_pending_today_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: pendingItems
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SinglePendingCard(
                item: item,
                formatTime: formatTime,
                taking: taking,
                onTaken: () => onTaken(item['id']?.toString() ?? item['medicineId']?.toString() ?? ''),
              ),
            ),
          )
          .toList(),
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
    final canTakeNow = item['canTakeNow'] == true;
    final name = (item['medicineName'] ?? item['name'] ?? tr('medicine'))
        .toString();
    final dosage = (item['dosage'] ?? '').toString();
    final timeLabel =
        formatTime(item['timeHour'], item['timeMinute']).toString();

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
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${tr('time')}: $timeLabel'),
                  Text(
                    dosage.isEmpty
                        ? '${tr('dosage')}: -'
                        : '${tr('dosage')}: $dosage',
                  ),
                ],
              ),
            ),
            if (canTakeNow)
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

class _FeatureChips extends StatelessWidget {
  const _FeatureChips();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
