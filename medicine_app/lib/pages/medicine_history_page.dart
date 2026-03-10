import 'package:flutter/material.dart';
import '../features/secure/data/secure_store_service.dart';

class MedicineHistoryPage extends StatefulWidget {
  const MedicineHistoryPage({super.key});

  @override
  State<MedicineHistoryPage> createState() => _MedicineHistoryPageState();
}

class _MedicineHistoryPageState extends State<MedicineHistoryPage> {
  bool _loading = true;
  String? _error;
  String _role = '';
  List<Map<String, dynamic>> _items = [];
  bool _clearing = false;

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
        if (!mounted) return;
        setState(() {
          _role = role;
          _items = [];
          _loading = false;
        });
        return;
      }

      final medicinesResponse = await SecureStoreService.getMedicines();
      if (medicinesResponse['error'] != null) {
        throw Exception(medicinesResponse['error'].toString());
      }

      final items = (medicinesResponse['items'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _role = role;
        _items = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    final mm = minute.toString().padLeft(2, '0');
    return '$h12:$mm ${isAm ? 'AM' : 'PM'}';
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'This will permanently delete medicine history from database. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _clearing = true);
    try {
      final response = await SecureStoreService.clearMedicineHistory();
      if (!mounted) return;
      if (response['error'] != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response['error'].toString())));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine history cleared.')),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Failed to load history: $_error'));
    }
    if (_role != 'Caregiver' && _role != 'Patient') {
      return const Center(
        child: Text('Medicine history is available for Patient or Caregiver.'),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No medicine history found.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _items[index];
          final medicineName = item['medicineName']?.toString().trim();
          final dosage = item['dosage']?.toString().trim();
          final date = item['startDate']?.toString().trim();
          final relation = item['patientRelation']?.toString().trim();
          final todayStatus = item['todayStatus']?.toString().trim();

          return Card(
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicineName != null && medicineName.isNotEmpty
                        ? medicineName
                        : 'Unnamed Medicine',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Date: ${date != null && date.isNotEmpty ? date : '-'}'),
                  Text(
                    'Time: ${_formatTime(item['timeHour'], item['timeMinute'])}',
                  ),
                  Text(
                    'Dosage: ${dosage != null && dosage.isNotEmpty ? dosage : '-'}',
                  ),
                  if (todayStatus != null && todayStatus.isNotEmpty)
                    Text('Today Status: $todayStatus'),
                  if (_role == 'Caregiver')
                    Text(
                      'Patient Relation: '
                      '${relation != null && relation.isNotEmpty ? relation : '-'}',
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showClear = _role == 'Caregiver' || _role == 'Patient';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF87CEEB),
        centerTitle: true,
        title: const Text('Medicine History'),
        actions: [
          if (showClear)
            TextButton(
              onPressed: _clearing ? null : _clearHistory,
              child: Text(
                _clearing ? 'Clearing...' : 'Clear History',
                style: const TextStyle(color: Colors.black87),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
