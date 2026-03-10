import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiMedicineFallbackService {
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static String get _apiKey => dotenv.env['GEMINI_API_KEY_BAR_CODE']?.trim() ?? '';

  static Future<Map<String, dynamic>> fetch({
    String? query,
    String? barcode,
  }) async {
    if (_apiKey.isEmpty) {
      return {'error': 'GEMINI_API_KEY is missing.'};
    }
    final subject = (query ?? '').trim();
    final code = (barcode ?? '').trim();
    if (subject.isEmpty && code.isEmpty) {
      return {'error': 'No search text or barcode provided.'};
    }

    final prompt = _buildPrompt(subject: subject, barcode: code);
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    });

    final uri = Uri.parse('$_endpoint?key=$_apiKey');
    http.Response response;
    try {
      response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: body,
      );
    } catch (e) {
      return {'error': 'Gemini request failed: $e'};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {'error': 'Gemini API ${response.statusCode}: ${response.body}'};
    }

    Map<String, dynamic> root;
    try {
      root = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'error': 'Invalid Gemini response format.'};
    }

    final text = _extractText(root);
    if (text.isEmpty) {
      return {'error': 'Gemini returned empty content.'};
    }

    final parsed = _parseJsonFromText(text);
    if (parsed == null) {
      return {'error': 'Gemini response could not be parsed.'};
    }

    return {
      'brand': parsed['brand'] ?? parsed['name'] ?? subject,
      'usage': parsed['usage'] ?? parsed['indications'],
      'dosage': parsed['dosage'],
      'side_effects': parsed['side_effects'] ?? parsed['warnings'],
      'source_notes': 'Fallback via Gemini',
    };
  }

  static String _buildPrompt({
    required String subject,
    required String barcode,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        'You are a concise drug information assistant. Return JSON only using this schema:',
      )
      ..writeln('{')
      ..writeln('  "brand": "string",')
      ..writeln('  "usage": "string",')
      ..writeln('  "dosage": "string",')
      ..writeln('  "side_effects": "string"')
      ..writeln('}');
    if (subject.isNotEmpty) {
      buffer.writeln('Medicine name: "$subject".');
    }
    if (barcode.isNotEmpty) {
      buffer.writeln('Barcode/UPC/GTIN: "$barcode".');
    }
    buffer.writeln(
      'If unsure, give best guess but keep it safe and note if information is generic.',
    );
    return buffer.toString();
  }

  static String _extractText(Map<String, dynamic> root) {
    final candidates = root['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final first = candidates.first;
    if (first is! Map) return '';
    final content = first['content'];
    if (content is! Map) return '';
    final parts = content['parts'];
    if (parts is! List) return '';
    for (final part in parts) {
      if (part is Map && part['text'] is String) {
        final value = (part['text'] as String).trim();
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  static Map<String, dynamic>? _parseJsonFromText(String text) {
    var cleaned = text.trim();
    cleaned = cleaned.replaceAll('```json', '```').replaceAll('```JSON', '```');
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst('```', '');
      final end = cleaned.lastIndexOf('```');
      if (end >= 0) cleaned = cleaned.substring(0, end);
    }
    cleaned = cleaned.trim();
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      // ignore and attempt bracket extraction
    }
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final slice = cleaned.substring(start, end + 1);
      try {
        final decoded = jsonDecode(slice);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {}
    }
    return null;
  }
}
