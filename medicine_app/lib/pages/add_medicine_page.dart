import 'package:flutter/material.dart';
import '../features/secure/data/secure_store_service.dart';
import 'manualentry.dart';
import 'ocr_extraction_page.dart';

class AddMedicinePage extends StatefulWidget {
  const AddMedicinePage({super.key});

  @override
  State<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends State<AddMedicinePage> {
  Future<void> _openIfAllowed(Widget page) async {
    final profile = await SecureStoreService.getUserProfile();
    if (!mounted) return;

    if (profile['error'] != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(profile['error'].toString())));
      return;
    }

    final role = profile['role']?.toString().trim();
    final phone = profile['phoneNumber']?.toString().trim() ?? '';
    if (role == 'Patient' && phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add mobile number first in Profile.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF87CEEB),
        centerTitle: true,
        title: const Text('Add Medicine'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.edit_note_outlined,
              title: 'Manual Entry',
              subtitle: 'Add medicine details manually.',
              onTap: () => _openIfAllowed(const ManualEntryPage()),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.document_scanner_outlined,
              title: 'OCR Extraction',
              subtitle: 'Capture or upload image and auto-fill fields.',
              onTap: () => _openIfAllowed(const OcrExtractionPage()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF87CEEB).withOpacity(0.28),
                child: Icon(icon, color: Colors.black87),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
