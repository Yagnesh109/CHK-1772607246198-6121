import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/secure/data/secure_store_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _qualificationController =
      TextEditingController();
  String _gender = '';
  DateTime? _dob;
  String _doctorCode = '';

  bool _isLoading = false;
  bool _isSaving = false;
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _allergiesController.dispose();
    _qualificationController.dispose();
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
      _qualificationController.text =
          profile['qualification']?.toString() ?? '';
      final rawDob = profile['dob']?.toString() ?? '';
      if (rawDob.isNotEmpty) {
        _dob = DateTime.tryParse(rawDob);
      }

      // Pull latest data from Firestore so the profile persists across devices.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = snap.data();
        if (data != null) {
          _phoneController.text =
              data['phoneNumber']?.toString() ?? _phoneController.text;
          _role = (data['role'] ?? _role).toString();
          _gender = data['gender']?.toString() ?? _gender;
          _doctorCode = data['doctorCode']?.toString() ?? _doctorCode;
          _weightController.text =
              data['weightKg']?.toString() ?? _weightController.text;
          _heightController.text =
              data['heightCm']?.toString() ?? _heightController.text;
          _allergiesController.text =
              data['allergies']?.toString() ?? _allergiesController.text;
          _qualificationController.text =
              data['qualification']?.toString() ??
              _qualificationController.text;
          final dobStr = data['dob']?.toString() ?? '';
          if (dobStr.isNotEmpty) {
            _dob = DateTime.tryParse(dobStr) ?? _dob;
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('please_enter_mobile'))));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('please_sign_in'))));
      return;
    }

    final weight = double.tryParse(_weightController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final allergies = _allergiesController.text.trim();
    final qualification = _qualificationController.text.trim();
    final resolvedRole = _role.isEmpty ? 'Patient' : _role;

    setState(() => _isSaving = true);
    try {
      // Persist to Firestore for cross-device retention.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phoneNumber': phone,
        'role': resolvedRole,
        'displayName': user.displayName,
        'email': user.email,
        'gender': _gender,
        'dob': _dob?.toIso8601String(),
        if (weight != null) 'weightKg': weight,
        if (height != null) 'heightCm': height,
        'allergies': allergies,
        'qualification': qualification,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Keep secure store in sync for backend calls that rely on it.
      await SecureStoreService.setUserPhone(phone);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('profile_saved'))));
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
                    Text(
                      tr('bmi'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bmi == null
                          ? tr('add_weight_height')
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
            Text(
              tr('health_details'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: tr('mobile_number'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone_android_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _gender.isEmpty ? null : _gender,
              decoration: InputDecoration(
                labelText: tr('gender'),
                border: const OutlineInputBorder(),
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
                decoration: InputDecoration(
                  labelText: tr('dob'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.cake_outlined),
                ),
                child: Text(
                  _dob == null
                      ? tr('tap_to_select')
                      : '${_dob!.day.toString().padLeft(2, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.year}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: tr('age'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                hintText: tr('not_set'),
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
              decoration: InputDecoration(
                labelText: tr('weight'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.monitor_weight_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr('height'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.height_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _allergiesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: tr('allergies'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.warning_amber_outlined),
                hintText: 'e.g. Penicillin, peanuts, dust',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _doctorCard() {
    final code = _doctorCode.isEmpty ? tr('not_set') : _doctorCode;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('doctor_details'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.qr_code_2_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${tr('doctor_code')}: $code',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: tr('copy'),
                  onPressed: _doctorCode.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: _doctorCode),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr('copied'))),
                          );
                        },
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qualificationController,
              decoration: InputDecoration(
                labelText: tr('qualification'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.school_outlined),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saveDoctorInfo,
              icon: const Icon(Icons.save),
              label: Text(tr('save_doctor_profile')),
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

  Future<void> _saveDoctorInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final existing = await docRef.get();
    final data = existing.data() ?? {};
    final code = (data['doctorCode']?.toString().trim().isNotEmpty ?? false)
        ? data['doctorCode'].toString()
        : (_doctorCode.isNotEmpty ? _doctorCode : null);

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'role': 'Doctor',
      'displayName': user.displayName,
      'email': user.email,
      'qualification': _qualificationController.text.trim(),
      if (code != null) 'doctorCode': code,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _doctorCode = code ?? _doctorCode;
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('doctor_profile_updated'))));
    }
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF87CEEB),
        centerTitle: true,
        title: Text(tr('profile')),
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
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? tr('saving') : tr('save')),
              ),
              const SizedBox(height: 24),
              if (_role == 'Doctor') ...[
                _doctorCard(),
                const SizedBox(height: 24),
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
