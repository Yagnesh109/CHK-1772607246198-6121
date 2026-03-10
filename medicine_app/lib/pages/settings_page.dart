import 'package:flutter/material.dart';
import '../features/secure/data/secure_store_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _switchRole(BuildContext context, String role) async {
    final res = await SecureStoreService.setUserRole(role);
    if (context.mounted) {
      final msg = res['error']?.toString() ?? 'Switched to $role';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        centerTitle: true,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Roles',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _switchRole(context, 'Patient'),
                  child: const Text('Switch to Patient'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _switchRole(context, 'Caregiver'),
                  child: const Text('Switch to Caregiver'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'About',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App Version'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}
