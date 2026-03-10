import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../features/secure/data/secure_store_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _doctorCodeController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  String _gender = '';
  DateTime? _dob;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _sending = false;
  String _role = '';
  String _requestStatus = 'No request sent yet.';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _doctorCodeController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await SecureStoreService.getUserProfile();
      if (!mounted) return;
      _phoneController.text = profile['phoneNumber']?.toString() ?? '';
      _role = profile['role']?.toString().trim() ?? '';
      _gender = profile['gender']?.toString().trim() ?? '';
      _weightController.text = profile['weightKg']?.toString() ?? '';
      _heightController.text = profile['heightCm']?.toString() ?? '';
      _allergiesController.text = profile['allergies']?.toString() ?? '';
      final rawDob = profile['dob']?.toString() ?? '';
      if (rawDob.isNotEmpty) {
        _dob = DateTime.tryParse(rawDob);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter mobile number.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final response = await SecureStoreService.setUserPhone(phone);
      if (!mounted) return;
      if (response['error'] != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response['error'].toString())));
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mobile number saved.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _bmiCard() {
    final bmi = _calculateBmi();
    final color = bmi == null ? Colors.blueGrey : _bmiColor(bmi);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BMI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bmi == null
                          ? 'Add weight & height'
                          : '${bmi.toStringAsFixed(1)} (${_bmiCategory(bmi)})',
                      style: TextStyle(
                        fontSize: 14,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.favorite, color: color, size: 28),
              ],
            ),
            const SizedBox(height: 12),
            if (bmi != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: _bmiProgress(bmi),
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Text(
                'Enter weight (kg) and height (cm) to see BMI.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
          ],
        ),
      ),
    );
  }

  Widget _profileForm() {
    final age = _age();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Health Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_android_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _gender.isEmpty ? null : _gender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) => setState(() => _gender = value ?? ''),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDob,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                child: Text(
                  _dob == null
                      ? 'Tap to select'
                      : '${_dob!.day.toString().padLeft(2, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.year}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Age',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                hintText: 'Not set',
                suffixText: age == null ? '' : 'years',
              ),
              controller: TextEditingController(
                text: age == null ? '' : age.toString(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monitor_weight_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.height_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _allergiesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Allergies',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning_amber_outlined),
                hintText: 'e.g. Penicillin, peanuts, dust',
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _calculateBmi() {
    final weight = double.tryParse(_weightController.text.trim());
    final heightCm = double.tryParse(_heightController.text.trim());
    if (weight == null || heightCm == null || weight <= 0 || heightCm <= 0) {
      return null;
    }
    final heightM = heightCm / 100;
    return weight / (heightM * heightM);
  }

  String _bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return const Color(0xFF42A5F5);
    if (bmi < 25) return const Color(0xFF43A047);
    if (bmi < 30) return const Color(0xFFF9A825);
    return const Color(0xFFE53935);
  }

  double _bmiProgress(double bmi) {
    final normalized = (bmi - 12) / 28;
    return normalized.clamp(0.0, 1.0);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
    );
    if (selected == null) return;
    setState(() => _dob = selected);
  }

  int? _age() {
    if (_dob == null) return null;
    final now = DateTime.now();
    var years = now.year - _dob!.year;
    if (DateTime(now.year, _dob!.month, _dob!.day).isAfter(now)) {
      years--;
    }
    return years < 0 ? null : years;
  }

  Future<void> _sendRequestToDoctor() async {
    final doctorCode = _doctorCodeController.text.trim();
    if (doctorCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the doctor code.')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final uid = user?.uid ?? '';
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send a request.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final doctors = await FirebaseFirestore.instance
          .collection('users')
          .where('doctorCode', isEqualTo: doctorCode)
          .where('role', isEqualTo: 'Doctor')
          .limit(1)
          .get();

      if (doctors.docs.isEmpty) {
        setState(() => _requestStatus = 'Doctor code not found.');
        return;
      }

      final doctorUid = doctors.docs.first.id;
      await FirebaseFirestore.instance.collection('connection_requests').add({
        'patientEmail': email,
        'patientUid': uid,
        'doctorCode': doctorCode,
        'doctorUid': doctorUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _requestStatus = 'Request sent to doctor.');
    } catch (e) {
      setState(() => _requestStatus = 'Failed to send request: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF87CEEB),
        centerTitle: true,
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: const Color(0xFF87CEEB),
                  child: user?.photoURL != null
                      ? ClipOval(
                          child: Image.network(
                            user!.photoURL!,
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.person, size: 48, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user?.displayName ?? 'User',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                user?.email ?? '-',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              _bmiCard(),
              const SizedBox(height: 16),
              _profileForm(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _savePhone,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Save'),
              ),
              const SizedBox(height: 24),
              if (_role == 'Patient') ...[
                TextField(
                  controller: _doctorCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Doctor code (e.g., DOC-123)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _sending ? null : _sendRequestToDoctor,
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Request'),
                ),
                const SizedBox(height: 8),
                Text(_requestStatus, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 20),
              ],
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
