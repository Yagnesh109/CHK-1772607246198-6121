import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class VoiceAssistantService {
  VoiceAssistantService._();
  static final VoiceAssistantService instance = VoiceAssistantService._();

  static const _model =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  String get _apiKey => dotenv.env['VOICE_ASSISTENT']?.trim() ?? '';

  Future<String> ask({
    required String message,
    required String languageCode,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('VOICE_ASSISTENT key missing in .env');
    }

    final prompt = '''
Respond in $languageCode.
User message: $message
Keep it concise and helpful.
''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    });

    final uri = Uri.parse('$_model?key=$_apiKey');
    final res = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Assistant API ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Empty assistant response');
    }
    final text = candidates.first['content']?['parts']?[0]?['text']?.toString();
    if (text == null || text.trim().isEmpty) {
      throw Exception('Assistant returned no text');
    }
    return text.trim();
  }
}
