import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ConsultDoctorPage extends StatefulWidget {
  const ConsultDoctorPage({super.key});

  @override
  State<ConsultDoctorPage> createState() => _ConsultDoctorPageState();
}

class _ConsultDoctorPageState extends State<ConsultDoctorPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  Map<String, dynamic>? _selectedDoctor;

  Future<void> _requestConsult(Map<String, dynamic> doctor) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('connection_requests').add({
      'patientEmail': user.email,
      'patientUid': user.uid,
      'doctorUid': doctor['id'],
      'doctorName': doctor['displayName'] ?? '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Consult request sent.')));
  }

  String _chatId(String patientId, String doctorId) =>
      'chat_${patientId}_$doctorId';

  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedDoctor == null) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('doctor_chats')
        .doc(_chatId(user.uid, _selectedDoctor!['id']))
        .collection('messages')
        .add({
          'sender': user.uid,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });

    if (!mounted) return;
    _messageController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message sent to doctor.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consult a Doctor'),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _searchBar(),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'Doctor')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final docs = snapshot.data?.docs ?? [];
                final doctors = docs
                    .map((d) => {'id': d.id, ...?d.data()})
                    .map((e) => Map<String, dynamic>.from(e))
                    .where((d) {
                      final q = _searchController.text.trim().toLowerCase();
                      if (q.isEmpty) return true;
                      return (d['displayName'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(q) ||
                          (d['email'] ?? '').toString().toLowerCase().contains(
                            q,
                          );
                    })
                    .toList();

                if (doctors.isEmpty) {
                  return const Text('No doctors found.');
                }
                return Column(
                  children: doctors
                      .map((doctor) => _doctorTile(doctor))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            if (_selectedDoctor != null) _messageCard(),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Search doctor by name',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
    );
  }

  Widget _doctorTile(Map<String, dynamic> doctor) {
    final name = doctor['displayName']?.toString() ?? 'Doctor';
    final email = doctor['email']?.toString() ?? '';
    final qualification =
        doctor['qualification']?.toString() ?? 'Qualification N/A';
    final isSelected = _selectedDoctor?['id'] == doctor['id'];
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0D47A1).withOpacity(0.15),
          child: const Icon(Icons.medical_services, color: Color(0xFF0D47A1)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$qualification\n$email'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Send request',
              icon: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF0D47A1),
              ),
              onPressed: () => _requestConsult(doctor),
            ),
            IconButton(
              tooltip: isSelected ? 'Selected' : 'Message',
              icon: Icon(
                Icons.chat_bubble_outline,
                color: isSelected ? const Color(0xFF0D47A1) : Colors.blueGrey,
              ),
              onPressed: () => setState(() => _selectedDoctor = doctor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageCard() {
    final doc = _selectedDoctor!;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Message ${doc['displayName'] ?? 'doctor'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 10),
            _messagesList(doc['id']),
            const SizedBox(height: 10),
            TextField(
              controller: _messageController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Describe the problem',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send),
              label: const Text('Send'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Note: Messages are saved to doctor chat. Doctors see them after accepting.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messagesList(String doctorId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    final stream = FirebaseFirestore.instance
        .collection('doctor_chats')
        .doc(_chatId(user.uid, doctorId))
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return SizedBox(
      height: 200,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No messages yet.'));
          }
          return ListView.builder(
            reverse: true,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final msg = docs[index].data();
              final isMe = msg['sender']?.toString() == user.uid;
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 6,
                  ),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFF0D47A1).withOpacity(0.12)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    msg['text']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13),
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
