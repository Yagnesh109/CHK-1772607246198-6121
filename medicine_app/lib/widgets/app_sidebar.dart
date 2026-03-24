import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../features/medicine/view/medicine_screen.dart';
import '../features/secure/data/secure_store_service.dart';
import '../pages/add_medicine_page.dart';
import '../pages/consult_doctor_page.dart';
import '../pages/login_page.dart';
import '../pages/doctor_requests_page.dart';
import '../pages/medicine_history_page.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';
import '../pages/side_effect_checker_page.dart';
import '../features/voice/voice_assistant_page.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  Future<void> _logout(BuildContext context) async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user?.displayName ?? tr('default_user_name')),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: user?.photoURL != null
                  ? ClipOval(
                      child: Image.network(
                        user!.photoURL!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.person, size: 36),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.medication_outlined),
            title: Text(tr('medicine_search')),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const MedicineScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(tr('profile')),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_box_outlined),
            title: Text(tr('add_medicine')),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddMedicinePage()),
              );
            },
          ),
          if ((SecureStoreService.getCachedRole() == null) ||
              (SecureStoreService.getCachedRole() == 'Caregiver') ||
              (SecureStoreService.getCachedRole() == 'Patient'))
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: Text(tr('medicine_history')),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MedicineHistoryPage(),
                  ),
                );
              },
            ),
          if (SecureStoreService.getCachedRole() == 'Doctor')
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(tr('patient_requests')),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DoctorRequestsPage()),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.warning_amber_outlined),
            title: Text(tr('side_effect_analyzer')),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SideEffectCheckerPage()),
              );
            },
          ),
          if (SecureStoreService.getCachedRole() == 'Patient')
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: Text(tr('consult_doctor')),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConsultDoctorPage()),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.assistant),
            title: Text(tr('assistant_title')),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const VoiceAssistantPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(tr('settings')),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(tr('logout')),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
