import 'dart:convert';
import 'package:http/http.dart' as http;

class MedicineService {
  static const String _host = "backend-medicine-app-sveri-hackathon.onrender.com";

  static Future<Map<String, dynamic>> getMedicine(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return {"error": "Please enter a medicine name."};
    }

    final url = Uri.https(_host, "/medicine", {"name": trimmedName});
    return _getAsJson(url);
  }

  static Future<Map<String, dynamic>> getMedicineByBarcode(String code) async {
    final trimmedCode = code.trim();
    if (trimmedCode.isEmpty) {
      return {"error": "No barcode value found."};
    }

    final url = Uri.https(_host, "/medicine/barcode", {"code": trimmedCode});
    return _getAsJson(url);
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
}
