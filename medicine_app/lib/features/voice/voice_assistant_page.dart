import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'voice_assistant_sheet.dart';

class VoiceAssistantPage extends StatelessWidget {
  const VoiceAssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        title: Text(tr('assistant_title')),
      ),
      backgroundColor: const Color(0xFFF4F7FB),
      body: const VoiceAssistantSheet(fullPage: true),
    );
  }
}
