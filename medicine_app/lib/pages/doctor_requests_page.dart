import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DoctorRequestsPage extends StatelessWidget {
  const DoctorRequestsPage({super.key});

  String _chatId(String patientId, String doctorId) =>
      'chat_${patientId}_$doctorId';

  Future<void> _updateStatus(
    BuildContext context,
    String docId,
    String patientUid,
    String doctorUid,
    String status,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('connection_requests')
          .doc(docId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (status == 'accepted') {
        final chatId = _chatId(patientUid, doctorUid);
        await FirebaseFirestore.instance
            .collection('doctor_chats')
            .doc(chatId)
            .set({
              'patientUid': patientUid,
              'doctorUid': doctorUid,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Request $status')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in as a doctor.')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('connection_requests')
        .where('doctorUid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Requests'),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No pending requests.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final patientEmail =
                  data['patientEmail']?.toString() ?? 'Patient';
              final createdAt = (data['createdAt'] as Timestamp?)
                  ?.toDate()
                  .toLocal();
              final patientUid = data['patientUid']?.toString() ?? '';
              final doctorUid = data['doctorUid']?.toString() ?? '';

              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientEmail,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Requested: ${createdAt != null ? createdAt.toString().split(".").first : "-"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _updateStatus(
                                context,
                                doc.id,
                                patientUid,
                                doctorUid,
                                'rejected',
                              ),
                              icon: const Icon(
                                Icons.cancel_outlined,
                                color: Colors.red,
                              ),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _updateStatus(
                                context,
                                doc.id,
                                patientUid,
                                doctorUid,
                                'accepted',
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
