import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DoctorPage extends StatelessWidget {
  const DoctorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final doctorUid = user?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Signed in as: ${user?.email ?? 'Unknown'}'),
            const SizedBox(height: 12),
            Expanded(
              child: doctorUid == null
                  ? const Center(child: Text('Please sign in as a doctor.'))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('connection_requests')
                          .where('doctorUid', isEqualTo: doctorUid)
                          .where('status', isEqualTo: 'pending')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text('No pending requests.'),
                          );
                        }
                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, i) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final id = docs[index].id;
                            final email =
                                data['patientEmail']?.toString() ?? 'Unknown';
                            final created = (data['createdAt'] as Timestamp?);
                            final createdText = created != null
                                ? created.toDate().toLocal().toString()
                                : '';
                            return Card(
                              child: ListTile(
                                title: Text(email),
                                subtitle: Text('Requested at $createdText'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () => _updateStatus(
                                        id,
                                        'accepted',
                                        context,
                                      ),
                                      child: const Text('Accept'),
                                    ),
                                    TextButton(
                                      onPressed: () => _updateStatus(
                                        id,
                                        'rejected',
                                        context,
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    String requestId,
    String status,
    BuildContext context,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('connection_requests')
          .doc(requestId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request $status.')));
    }
  }
}
