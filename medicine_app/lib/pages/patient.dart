import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PatientPage extends StatefulWidget {
  const PatientPage({super.key});

  @override
  State<PatientPage> createState() => _PatientPageState();
}

class _PatientPageState extends State<PatientPage> {
  final TextEditingController _doctorCodeController = TextEditingController();
  String _status = 'No request sent yet.';
  bool _sending = false;

  @override
  void dispose() {
    _doctorCodeController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    final doctorCode = _doctorCodeController.text.trim();
    if (doctorCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the doctor code.')),
      );
      return;
    }

    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
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
        setState(() => _status = 'Doctor code not found.');
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

      setState(() => _status = 'Request sent to doctor.');
    } catch (e) {
      setState(() => _status = 'Failed to send request: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Request')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter your doctor’s code and send a request.'),
            const SizedBox(height: 12),
            TextField(
              controller: _doctorCodeController,
              decoration: const InputDecoration(
                labelText: 'Doctor code (DOC-123)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending ? null : _sendRequest,
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Request'),
            ),
            const SizedBox(height: 16),
            Text(_status, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
