import 'package:flutter/material.dart';
import '../features/secure/data/secure_store_service.dart';

class MedicineHistoryPage extends StatefulWidget {
  const MedicineHistoryPage({super.key});

  @override
  State<MedicineHistoryPage> createState() => _MedicineHistoryPageState();
}

class _MedicineHistoryPageState extends State<MedicineHistoryPage> {
  bool _loading = true;
  bool _clearing = false;
  String? _error;
  String _role = '';
  DateTime _lastLoaded = DateTime.now();
  _HistoryFilter _filter = _HistoryFilter.all;
  List<Map<String, dynamic>> _items = [];

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
      final profile = await SecureStoreService.getUserProfile();
      if (profile['error'] != null) {
        throw Exception(profile['error'].toString());
      }
      final role = profile['role']?.toString().trim() ?? '';
      if (role != 'Caregiver' && role != 'Patient') {
        setState(() {
          _role = role;
          _items = [];
          _loading = false;
        });
        return;
      }

      final resp = await SecureStoreService.getMedicines();
      if (resp['error'] != null) {
        throw Exception(resp['error'].toString());
      }
      final items = (resp['items'] as List?) ?? [];
      setState(() {
        _role = role;
        _items = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _lastLoaded = DateTime.now();
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

  String _statusOf(Map<String, dynamic> item) {
    final raw = (item['todayStatus'] ?? item['status'] ?? '')
        .toString()
        .toLowerCase();
    if (raw.contains('taken') || raw == 'done') return 'taken';
    if (raw.contains('miss')) return 'missed';
    if (raw.contains('pending')) return 'missed';
    return raw.isNotEmpty ? raw : 'unknown';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'taken':
        return const Color(0xFF2E7D32);
      case 'missed':
        return const Color(0xFFD32F2F);
      default:
        return Colors.blueGrey;
    }
  }

  int get _takenCount => _items.where((i) => _statusOf(i) == 'taken').length;
  int get _missedCount => _items.where((i) => _statusOf(i) == 'missed').length;

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History'),
        content: const Text(
          'This will permanently delete medicine history. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _clearing = true);
    try {
      final resp = await SecureStoreService.clearMedicineHistory();
      if (resp['error'] != null) {
        throw Exception(resp['error'].toString());
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  String _formatTime(dynamic hourValue, dynamic minuteValue) {
    final hour = int.tryParse(hourValue?.toString() ?? '');
    final minute = int.tryParse(minuteValue?.toString() ?? '');
    if (hour == null || minute == null) return '-';
    final isAm = hour < 12;
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final mm = minute.toString().padLeft(2, '0');
    return '$h12:$mm ${isAm ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final showClear = _role == 'Caregiver' || _role == 'Patient';
    final filtered = _items.where((item) {
      final status = _statusOf(item);
      if (_filter == _HistoryFilter.all) return true;
      if (_filter == _HistoryFilter.taken) return status == 'taken';
      if (_filter == _HistoryFilter.missed) return status == 'missed';
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        title: const Text('Adherence History'),
        actions: [
          if (showClear)
            TextButton(
              onPressed: _clearing ? null : _clearHistory,
              child: Text(
                _clearing ? 'Clearing...' : 'Clear All',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Failed: $_error'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) return _filterRow();
                  if (index == 1) return _summaryCards();
                  final item = filtered[index - 2];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _historyCard(item),
                  );
                },
              ),
            ),
    );
  }

  Widget _filterRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Color(0xFF0D47A1)),
          const SizedBox(width: 8),
          const Text(
            'All Dates',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          PopupMenuButton<_HistoryFilter>(
            initialValue: _filter,
            onSelected: (value) => setState(() => _filter = value),
            child: Row(
              children: [
                Text(
                  'Type: ${_filter.label}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _HistoryFilter.all, child: Text('All')),
              PopupMenuItem(value: _HistoryFilter.taken, child: Text('Taken')),
              PopupMenuItem(
                value: _HistoryFilter.missed,
                child: Text('Missed'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCards() {
    return Column(
      children: [
        _statusCard(
          color: const Color(0xFF2E7D32),
          bg: const Color(0xFFE8F5E9),
          label: 'Taken',
          count: _takenCount,
          icon: Icons.check_circle,
        ),
        const SizedBox(height: 10),
        _statusCard(
          color: const Color(0xFFD32F2F),
          bg: const Color(0xFFFFEBEE),
          label: 'Missed',
          count: _missedCount,
          icon: Icons.cancel,
        ),
        const SizedBox(height: 12),
        _sectionHeader(),
      ],
    );
  }

  Widget _statusCard({
    required Color color,
    required Color bg,
    required String label,
    required int count,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader() {
    return Row(
      children: [
        const Text(
          'Dose History',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: Colors.blueGrey.shade100)),
        if (_role == 'Caregiver' || _role == 'Patient') ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _clearing ? null : _clearHistory,
            icon: const Icon(Icons.delete_outline),
            label: Text(_clearing ? 'Clearing...' : 'Clear All History'),
          ),
        ],
      ],
    );
  }

  Widget _historyCard(Map<String, dynamic> item) {
    final name = item['medicineName']?.toString().trim();
    final dosage = item['dosage']?.toString().trim();
    final date = item['startDate']?.toString().trim();
    final relation = item['patientRelation']?.toString().trim();
    final status = _statusOf(item);
    final statusColor = _statusColor(status);
    final initials = (name?.isNotEmpty == true ? name! : 'M')
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0])
        .join()
        .toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name?.isNotEmpty == true ? name! : 'Medicine',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dosage: ${dosage?.isNotEmpty == true ? dosage : '-'}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _pill(
                      Icons.access_time,
                      _formatTime(item['timeHour'], item['timeMinute']),
                    ),
                    _pill(
                      Icons.calendar_today_outlined,
                      date != null && date.isNotEmpty ? date : '—',
                    ),
                    if (_role == 'Caregiver' &&
                        relation != null &&
                        relation.isNotEmpty)
                      _pill(Icons.group_outlined, relation),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                status == 'taken' ? Icons.check_circle : Icons.cancel,
                color: statusColor,
              ),
              const SizedBox(height: 4),
              Text(
                status == 'taken' ? 'Taken' : 'Missed',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

enum _HistoryFilter { all, taken, missed }

extension on _HistoryFilter {
  String get label {
    switch (this) {
      case _HistoryFilter.all:
        return 'All';
      case _HistoryFilter.taken:
        return 'Taken';
      case _HistoryFilter.missed:
        return 'Missed';
    }
  }
}
