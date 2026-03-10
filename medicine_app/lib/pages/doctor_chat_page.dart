import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DoctorChatPage extends StatefulWidget {
  const DoctorChatPage({
    super.key,
    required this.patientUid,
    required this.patientEmail,
    required this.doctorUid,
  });

  final String patientUid;
  final String doctorUid;
  final String patientEmail;

  @override
  State<DoctorChatPage> createState() => _DoctorChatPageState();
}

class _DoctorChatPageState extends State<DoctorChatPage> {
  final TextEditingController _messageController = TextEditingController();

  String get _chatId => 'chat_${widget.patientUid}_${widget.doctorUid}';

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('doctor_chats')
        .doc(_chatId)
        .collection('messages')
        .add({
          'sender': user.uid,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages = FirebaseFirestore.instance
        .collection('doctor_chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        title: Text('Chat with ${widget.patientEmail}'),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _clearChat,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messages,
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
                    final isMe =
                        msg['sender']?.toString() ==
                        FirebaseAuth.instance.currentUser?.uid;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF0D47A1).withOpacity(0.1)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          msg['text']?.toString() ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text(
          'This will delete all messages in this chat for both doctor and patient.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final chatRef = FirebaseFirestore.instance
        .collection('doctor_chats')
        .doc(_chatId);
    // Delete messages
    final msgs = await chatRef
        .collection('messages')
        .get(); // small volumes expected
    for (final doc in msgs.docs) {
      await doc.reference.delete();
    }
    // Delete uploads if any (placeholder storage)
    final uploads = await chatRef.collection('uploads').get();
    for (final doc in uploads.docs) {
      await doc.reference.delete();
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat cleared.')));
    }
  }
}
