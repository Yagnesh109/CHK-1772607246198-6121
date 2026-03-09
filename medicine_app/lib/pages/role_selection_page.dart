import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../features/secure/data/secure_store_service.dart';
import 'home_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key, required this.user});

  final User user;

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  bool _saving = false;

  Future<void> _saveRole(String role) async {
    setState(() => _saving = true);
    try {
      final response = await SecureStoreService.setUserRole(role);
      if (response['error'] != null) {
        throw FirebaseException(
          plugin: 'secure-store',
          code: 'backend-error',
          message: response['error'].toString(),
        );
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'null';
      final projectId = Firebase.app().options.projectId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Role save failed (${e.code}) uid=$uid project=$projectId: '
            '${e.message ?? "Unknown error"}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const roles = ['Patient', 'Caregiver', 'Doctor'];

    return Scaffold(
      appBar: AppBar(title: const Text('Select Role'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Please select your role to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            for (final role in roles) ...[
              ElevatedButton(
                onPressed: _saving ? null : () => _saveRole(role),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(role),
              ),
              const SizedBox(height: 12),
            ],
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
