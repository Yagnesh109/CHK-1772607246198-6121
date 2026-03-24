import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiPrescriptionService {
  GeminiPrescriptionService._();
  static final GeminiPrescriptionService instance =
      GeminiPrescriptionService._();

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  String get _apiKey => dotenv.env['GEMINI_API_KEY']?.trim() ?? '';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<PrescriptionExtraction> extractFromImagePath(String imagePath) async {
    if (!isConfigured) {
      throw Exception('GEMINI_API_KEY is missing in .env');
    }

    final file = File(imagePath);
    if (!file.existsSync()) {
      throw Exception('Prescription image not found.');
    }

    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = _guessMimeType(imagePath);

    final uri = Uri.parse('$_endpoint?key=$_apiKey');
    const prompt = '''
Extract medicine names, dosage, and schedule from this doctor prescription.
Return JSON only.
Use this schema:
{
  "medicines": [
    {
      "name": "string",
      "dosage": "string",
      "timing": ["string"]
    }
  ],
  "start_date": "YYYY-MM-DD or empty",
  "end_date": "YYYY-MM-DD or empty",
  "raw_text": "string"
}
''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {'mime_type': mimeType, 'data': base64Image},
            },
          ],
        },
      ],
    });

    http.Response response;
    try {
      response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: body,
      );
    } catch (e) {
      throw Exception('Gemini request failed: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini API ${response.statusCode}: ${response.body}');
    }

    Map<String, dynamic> root;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected Gemini response shape');
      }
      root = decoded;
    } catch (e) {
      throw Exception('Invalid Gemini JSON response: $e');
    }

    final text = _extractCandidateText(root);
    if (text.isEmpty) {
      throw Exception('Gemini returned empty content.');
    }

    final parsedJson = _extractJsonObject(text);
    final medicines = _parseMedicines(parsedJson);
    final startDate = (parsedJson['start_date'] ?? '').toString().trim();
    final endDate = (parsedJson['end_date'] ?? '').toString().trim();
    final rawText = (parsedJson['raw_text'] ?? '').toString().trim();

    return PrescriptionExtraction(
      medicines: medicines,
      startDateText: startDate,
      endDateText: endDate,
      rawText: rawText.isNotEmpty ? rawText : text,
      responseBody: root,
    );
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  String _extractCandidateText(Map<String, dynamic> root) {
    final candidates = root['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return '';
    }
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

  Map<String, dynamic> _extractJsonObject(String text) {
    var cleaned = text.trim();
    cleaned = cleaned.replaceAll('```json', '```').replaceAll('```JSON', '```');
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst('```', '');
      final endFence = cleaned.lastIndexOf('```');
      if (endFence >= 0) {
        cleaned = cleaned.substring(0, endFence);
      }
    }
    cleaned = cleaned.trim();

    Map<String, dynamic>? parsed = _tryParseMap(cleaned);
    if (parsed != null) return parsed;

    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final slice = cleaned.substring(start, end + 1).trim();
      parsed = _tryParseMap(slice);
      if (parsed != null) return parsed;
    }
    throw Exception('Gemini output was not valid JSON object.');
  }

  Map<String, dynamic>? _tryParseMap(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  List<PrescriptionMedicine> _parseMedicines(Map<String, dynamic> json) {
    final raw = json['medicines'];
    if (raw is! List) return const <PrescriptionMedicine>[];

    final items = <PrescriptionMedicine>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.map((k, v) => MapEntry(k.toString(), v));
      final name = (map['name'] ?? '').toString().trim();
      final dosage = (map['dosage'] ?? '').toString().trim();
      final timingRaw = map['timing'];

      final timing = <String>[];
      if (timingRaw is List) {
        for (final t in timingRaw) {
          final value = t.toString().trim();
          if (value.isNotEmpty) timing.add(value);
        }
      } else if (timingRaw is String && timingRaw.trim().isNotEmpty) {
        timing.add(timingRaw.trim());
      }

      if (name.isEmpty && dosage.isEmpty && timing.isEmpty) {
        continue;
      }

      items.add(
        PrescriptionMedicine(name: name, dosage: dosage, timing: timing),
      );
    }
    return items;
  }
}

class PrescriptionExtraction {
  const PrescriptionExtraction({
    required this.medicines,
    required this.startDateText,
    required this.endDateText,
    required this.rawText,
    required this.responseBody,
  });

  final List<PrescriptionMedicine> medicines;
  final String startDateText;
  final String endDateText;
  final String rawText;
  final Map<String, dynamic> responseBody;
}

class PrescriptionMedicine {
  const PrescriptionMedicine({
    required this.name,
    required this.dosage,
    required this.timing,
  });

  final String name;
  final String dosage;
  final List<String> timing;
}
