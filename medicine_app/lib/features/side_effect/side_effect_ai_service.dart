import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SideEffectAnalysisRequest {
  SideEffectAnalysisRequest({
    required this.medicineName,
    required this.dose,
    required this.symptoms,
    this.patientAge,
    this.patientGender = '',
    this.knownConditions = const <String>[],
    this.extraNotes = '',
  });

  final String medicineName;
  final String dose;
  final List<String> symptoms;
  final int? patientAge;
  final String patientGender;
  final List<String> knownConditions;
  final String extraNotes;

  Map<String, dynamic> toMap() => {
    'medicineName': medicineName,
    'dose': dose,
    'symptoms': symptoms,
    'patientAge': patientAge,
    'patientGender': patientGender,
    'knownConditions': knownConditions,
    'extraNotes': extraNotes,
  };
}

class SideEffectAnalysisResult {
  SideEffectAnalysisResult({
    required this.severity,
    required this.urgency,
    required this.doctorConsultationNeeded,
    required this.recommendation,
    required this.possibleReasons,
    required this.immediateActions,
    required this.warningSigns,
    required this.confidence,
    required this.source,
  });

  final String severity;
  final String urgency;
  final bool doctorConsultationNeeded;
  final String recommendation;
  final List<String> possibleReasons;
  final List<String> immediateActions;
  final List<String> warningSigns;
  final double confidence;
  final String source;
}

class SideEffectAiService {
  SideEffectAiService._();
  static final SideEffectAiService instance = SideEffectAiService._();

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  String get _apiKey => dotenv.env['GEMINI_API_KEY']?.trim() ?? '';

  Future<SideEffectAnalysisResult> analyze(
    SideEffectAnalysisRequest request,
  ) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY missing in .env');
    }

    final prompt = _buildPrompt(request);

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
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini API ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    final text = _extractText(decoded);
    if (text.isEmpty) {
      throw Exception('Gemini returned empty response.');
    }
    final json = _parseJson(text);
    return SideEffectAnalysisResult(
      severity: (json['severity'] ?? 'unknown').toString(),
      urgency: (json['urgency'] ?? '').toString(),
      doctorConsultationNeeded: json['doctor_consultation_needed'] == true,
      recommendation: (json['recommendation'] ?? '').toString(),
      possibleReasons: _toList(json['possible_reasons']),
      immediateActions: _toList(json['immediate_actions']),
      warningSigns: _toList(json['warning_signs']),
      confidence: double.tryParse(json['confidence']?.toString() ?? '') ?? 0.0,
      source: 'gemini',
    );
  }

  String _buildPrompt(SideEffectAnalysisRequest r) {
    final map = r.toMap();
    return '''
You are a medical side‑effect checker. Return ONLY JSON in this schema:
{
  "severity": "low|medium|high|emergency",
  "urgency": "string",
  "doctor_consultation_needed": true/false,
  "recommendation": "string",
  "possible_reasons": ["string"],
  "immediate_actions": ["string"],
  "warning_signs": ["string"],
  "confidence": 0.0-1.0
}

Use the patient and medicine info:
${jsonEncode(map)}

Keep advice concise and safe.
''';
  }

  String _extractText(Map<String, dynamic> root) {
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
        final v = (part['text'] as String).trim();
        if (v.isNotEmpty) return v;
      }
    }
    return '';
  }

  Map<String, dynamic> _parseJson(String text) {
    var cleaned = text.trim();
    cleaned = cleaned.replaceAll('```json', '```').replaceAll('```JSON', '```');
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst('```', '');
      final end = cleaned.lastIndexOf('```');
      if (end >= 0) cleaned = cleaned.substring(0, end);
    }
    cleaned = cleaned.trim();
    Map<String, dynamic>? parsed;
    try {
      final d = jsonDecode(cleaned);
      if (d is Map<String, dynamic>) parsed = d;
      if (d is Map) parsed = d.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {}
    if (parsed != null) return parsed;
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final slice = cleaned.substring(start, end + 1);
      final d = jsonDecode(slice);
      if (d is Map<String, dynamic>) return d;
      if (d is Map) return d.map((k, v) => MapEntry(k.toString(), v));
    }
    throw Exception('Gemini response not valid JSON.');
  }

  List<String> _toList(dynamic v) {
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }
}
