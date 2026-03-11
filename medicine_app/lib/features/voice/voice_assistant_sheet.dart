import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'voice_assistant_service.dart';

class VoiceAssistantSheet extends StatefulWidget {
  const VoiceAssistantSheet({super.key, this.fullPage = false});

  /// When true, the layout stretches to fill available height (used in full page).
  final bool fullPage;

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<_Message> _messages = [];
  final FlutterTts _tts = FlutterTts();
  bool _sending = false;
  bool _ttsReady = false;

  @override
  void initState() {
    super.initState();
    _configureTts();
  }

  Future<void> _configureTts() async {
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _setTtsLanguage();
    _ttsReady = true;
  }

  Future<void> _setTtsLanguage() async {
    final code = context.locale.languageCode.toLowerCase();
    final lang = switch (code) {
      'hi' => 'hi-IN',
      'mr' => 'mr-IN',
      _ => 'en-US',
    };
    await _tts.setLanguage(lang);
  }

  @override
  void dispose() {
    _controller.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _messages.add(_Message(role: _Role.user, text: text));
    });
    _controller.clear();
    try {
      final reply = await VoiceAssistantService.instance.ask(
        message: text,
        languageCode: context.locale.languageCode,
      );
      setState(() {
        _messages.add(_Message(role: _Role.assistant, text: reply));
      });
      if (_ttsReady) {
        await _tts.stop();
        await _tts.speak(reply);
      }
    } catch (e) {
      setState(() {
        _messages.add(
          _Message(role: _Role.assistant, text: tr('generic_error_with_value', args: ['$e'])),
        );
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height *
        (widget.fullPage ? 0.8 : 0.35);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: widget.fullPage ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (!widget.fullPage)
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assistant, color: Color(0xFF0D47A1)),
                ),
                const SizedBox(width: 8),
                Text(
                  tr('assistant_title'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[_messages.length - 1 - index];
                      final isUser = msg.role == _Role.user;
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFF1E88E5) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: tr('assistant_hint'),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _sending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Role { user, assistant }

class _Message {
  _Message({required this.role, required this.text});
  final _Role role;
  final String text;
}
