import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../features/secure/data/secure_store_service.dart';
import 'home_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _switchRole(BuildContext context, String role) async {
    final res = await SecureStoreService.setUserRole(role);
    if (context.mounted) {
      final msg =
          res['error']?.toString() ??
          tr('switched_role', namedArgs: {'role': role});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (res['error'] == null) {
        // Force UI refresh so HomePage and drawer rebuild with new role.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        centerTitle: true,
        title: Text(tr('settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            tr('roles'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _switchRole(context, 'Patient'),
                  child: Text(tr('switch_patient')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _switchRole(context, 'Caregiver'),
                  child: Text(tr('switch_caregiver')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _switchRole(context, 'Doctor'),
            child: Text(tr('switch_doctor')),
          ),
          const SizedBox(height: 20),
          Text(
            tr('language'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              RadioListTile<String>(
                value: 'en',
                groupValue: context.locale.languageCode,
                onChanged: (code) => context.setLocale(Locale(code ?? 'en')),
                title: Text(tr('english')),
              ),
              RadioListTile<String>(
                value: 'hi',
                groupValue: context.locale.languageCode,
                onChanged: (code) => context.setLocale(Locale(code ?? 'hi')),
                title: Text(tr('hindi')),
              ),
              RadioListTile<String>(
                value: 'mr',
                groupValue: context.locale.languageCode,
                onChanged: (code) => context.setLocale(Locale(code ?? 'mr')),
                title: Text(tr('marathi')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            tr('about'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(tr('app_version')),
            subtitle: const Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}
