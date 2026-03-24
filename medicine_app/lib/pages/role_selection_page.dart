import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
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

  Future<String?> _ensureDoctorCode(User user) async {
    // Reuse existing code if present; generate a short, mostly unique code otherwise.
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    String? code = data?['doctorCode']?.toString();
    if (code != null && code.isNotEmpty) return code;

    final rand = Random();
    for (var attempt = 0; attempt < 5; attempt++) {
      final suffix = (attempt == 0)
          ? user.uid.substring(0, min(6, user.uid.length)).toUpperCase()
          : '${rand.nextInt(900000) + 100000}';
      code = 'DOC-$suffix';

      final clash = await FirebaseFirestore.instance
          .collection('users')
          .where('doctorCode', isEqualTo: code)
          .limit(1)
          .get();
      if (clash.docs.isEmpty) return code;
    }
    return code; // Best-effort; even if duplicated, patient lookup will still work.
  }

  Future<void> _upsertFirestoreProfile(String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final existing = await docRef.get();
    final data = existing.data() ?? {};

    String? doctorCode;
    if (role == 'Doctor') {
      doctorCode = await _ensureDoctorCode(user);
    }

    await docRef.set(
      {
        'role': role,
        'displayName': user.displayName,
        'email': user.email,
        'phoneNumber': data['phoneNumber'], // preserve if already stored
        if (doctorCode != null) 'doctorCode': doctorCode,
        'updatedAt': FieldValue.serverTimestamp(),
        // Keep original createdAt so ordering stays stable.
        if (data['createdAt'] != null) 'createdAt': data['createdAt'],
        if (data['gender'] != null) 'gender': data['gender'],
        if (data['dob'] != null) 'dob': data['dob'],
        if (data['weightKg'] != null) 'weightKg': data['weightKg'],
        if (data['heightCm'] != null) 'heightCm': data['heightCm'],
        if (data['allergies'] != null) 'allergies': data['allergies'],
        if (data['qualification'] != null) 'qualification': data['qualification'],
      },
      SetOptions(merge: true),
    );
  }

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
      await _upsertFirestoreProfile(role);
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
      appBar: AppBar(title: Text(tr('select_role')), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(
              tr('select_role_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            for (final role in roles) ...[
              ElevatedButton(
                onPressed: _saving ? null : () => _saveRole(role),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(tr(role.toLowerCase())),
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
