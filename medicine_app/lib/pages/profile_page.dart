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
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await SecureStoreService.getUserProfile();
      if (!mounted) return;
      _phoneController.text = profile['phoneNumber']?.toString() ?? '';
      _role = profile['role']?.toString().trim() ?? '';
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
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isSaving ? null : _savePhone,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Mobile Number'),
              ),
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
