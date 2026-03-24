import 'package:flutter/material.dart';
import '../features/secure/data/secure_store_service.dart';

class AddPatientPage extends StatefulWidget {
  const AddPatientPage({super.key});

  @override
  State<AddPatientPage> createState() => _AddPatientPageState();
}

class _AddPatientPageState extends State<AddPatientPage> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final relation = _relationController.text.trim();
    if (email.isEmpty || phone.isEmpty || relation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter patient email, phone and relation.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final response = await SecureStoreService.addPatientForCaregiver(
        patientEmail: email,
        patientPhoneNumber: phone,
        patientRelation: relation,
      );
      if (!mounted) return;

      if (response['error'] != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response['error'].toString())));
        return;
      }

      final autoCreated = response['wasAutoCreatedInAuth'] == true;
      final message = autoCreated
          ? 'Patient added and created in Firebase successfully.'
          : 'Patient added successfully.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Add Patient')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Patient Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Patient Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _relationController,
              decoration: const InputDecoration(
                labelText: 'Relation (e.g. Father, Mother, Spouse)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Patient'),
            ),
          ],
        ),
      ),
    );
  }
}
