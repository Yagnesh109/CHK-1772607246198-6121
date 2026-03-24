import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class VoiceAssistantService {
  VoiceAssistantService._();
  static final VoiceAssistantService instance = VoiceAssistantService._();

  String get _modelName =>
      [
        dotenv.env['VOICE_ASSISTENT_MODEL'],
        dotenv.env['GEMINI_MODEL'],
      ].firstWhere(
        (v) => v != null && v.trim().isNotEmpty,
        orElse: () => 'gemini-1.5-flash-latest',
      )!
          .trim();

  // Use v1 endpoint per Google docs.
  String get _modelUrl =>
      'https://generativelanguage.googleapis.com/v1/models/$_modelName:generateContent';

  String get _apiKey {
    final primary = dotenv.env['VOICE_ASSISTENT']?.trim() ?? '';
    if (primary.isNotEmpty) return primary;
    // Fallback to main Gemini key so voice chat still works if the dedicated key
    // isn't set.
    return dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
  }

  Future<String> ask({
    required String message,
    required String languageCode,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Add VOICE_ASSISTENT or GEMINI_API_KEY to .env');
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

    try {
      final primary = await _callModel(_modelUrl, body);
      if (primary != null) return primary;
    } catch (e) {
      final msg = e.toString();
      final is404 = msg.contains('404') || msg.contains('NOT_FOUND');
      if (!is404) rethrow;
      // fall through to fallback
    }

    final fallbackUrl =
        'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent';
    final fallback = await _callModel(fallbackUrl, body, ignoreErrors: false);
    if (fallback != null) return fallback;
    throw Exception('Assistant returned no text');
  }

  Future<String?> _callModel(String url, String body,
      {bool ignoreErrors = false}) async {
    final uri = Uri.parse('$url?key=$_apiKey');
    final res = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (!ignoreErrors) {
        throw Exception('Assistant API ${res.statusCode}: ${res.body}');
      }
      return null;
    }

    final decoded = jsonDecode(res.body);
    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Empty assistant response');
    }
    // Gemini may return multiple parts; concatenate any text parts for safety.
    final parts = candidates.first['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Assistant returned no text');
    }
    final buffer = StringBuffer();
    for (final p in parts) {
      final text = p['text']?.toString() ?? '';
      if (text.isNotEmpty) buffer.write(text);
    }
    final out = buffer.toString().trim();
    return out.isEmpty ? null : out;
  }
}
