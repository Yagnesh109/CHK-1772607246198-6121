import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../features/medicine/view/medicine_screen.dart';
import '../features/secure/data/secure_store_service.dart';
import '../pages/add_medicine_page.dart';
import '../pages/login_page.dart';
import '../pages/medicine_history_page.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';

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
            accountName: Text(user?.displayName ?? 'MediMind User'),
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
            title: const Text('Medicine Search'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const MedicineScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_box_outlined),
            title: const Text('Add Medicine'),
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
              title: const Text('Medicine History'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MedicineHistoryPage(),
                  ),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
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
            title: const Text('Logout'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
