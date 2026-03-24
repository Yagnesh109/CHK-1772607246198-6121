import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'gemini_medicine_fallback_service.dart';

class MedicineService {
  static const String _host =
      "backend-medicine-app-sveri-hackathon.onrender.com";

  static Future<Map<String, dynamic>> getMedicine(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return {"error": "Please enter a medicine name."};
    }

    final url = Uri.https(_host, "/medicine", {"name": trimmedName});
    final primary = await _getAsJson(url);
    return _withFallback(primary, query: trimmedName);
  }

  static Future<Map<String, dynamic>> getMedicineByBarcode(String code) async {
    final trimmedCode = code.trim();
    if (trimmedCode.isEmpty) {
      return {"error": "No barcode value found."};
    }

    final url = Uri.https(_host, "/medicine/barcode", {"code": trimmedCode});
    final primary = await _getAsJson(url);
    return _withFallback(primary, barcode: trimmedCode);
  }

  static Future<Map<String, dynamic>> _getAsJson(Uri url) async {
    final res = await http.get(url);

    if (res.statusCode != 200) {
      return {
        "error":
            "Backend error (${res.statusCode}): ${res.body.isEmpty ? "No details" : res.body}",
      };
    }

    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on FormatException {
      return {"error": "Invalid response from backend: ${res.body}"};
    }
  }

  static bool _hasMedicineFields(Map<String, dynamic> data) {
    return (data['brand'] ?? '').toString().trim().isNotEmpty ||
        (data['usage'] ?? '').toString().trim().isNotEmpty ||
        (data['dosage'] ?? '').toString().trim().isNotEmpty ||
        (data['side_effects'] ?? '').toString().trim().isNotEmpty;
  }

  static Future<Map<String, dynamic>> _withFallback(
    Map<String, dynamic> primary, {
    String? query,
    String? barcode,
  }) async {
    final hasError = primary['error'] != null;
    final hasData = _hasMedicineFields(primary);
    if (!hasError && hasData) {
      return {...primary, 'source': 'openfda'};
    }

    // Try Gemini fallback if API key is present.
    final apiKey = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
    if (apiKey.isEmpty) {
      return {
        ...primary,
        'warning':
            'OpenFDA could not find this medicine and GEMINI_API_KEY is not set.',
      };
    }

    final fallback = await GeminiMedicineFallbackService.fetch(
      query: query,
      barcode: barcode,
    );
    if (fallback['error'] != null) {
      return {
        ...primary,
        'warning':
            'OpenFDA lookup failed and Gemini fallback also returned an error.',
        'error': primary['error'] ?? fallback['error'],
      };
    }

    return {
      ...fallback,
      'source': 'gemini',
      if (primary['error'] != null) 'warning': primary['error'],
    };
  }
}
