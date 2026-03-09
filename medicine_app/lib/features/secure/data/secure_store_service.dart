import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class SecureStoreService {
  static const String _host =
      "backend-medicine-app-sveri-hackathon.onrender.com";

  static Future<Map<String, dynamic>> _authorizedGet(String path) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {"error": "User not logged in."};
    }

    final token = await user.getIdToken(true);
    final uri = Uri.https(_host, path);
    final res = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );
    return _decodeResponse(res);
  }

  static Future<Map<String, dynamic>> _authorizedPost(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {"error": "User not logged in."};
    }

    final token = await user.getIdToken(true);
    final uri = Uri.https(_host, path);
    final res = await http.post(
      uri,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(payload),
    );
    return _decodeResponse(res);
  }

  static Map<String, dynamic> _decodeResponse(http.Response res) {
    try {
      final parsed = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return parsed;
      }
      return {"error": parsed["detail"] ?? parsed["error"] ?? res.body};
    } catch (_) {
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {"ok": true};
      }
      return {"error": "Backend error (${res.statusCode}): ${res.body}"};
    }
  }

  static Future<Map<String, dynamic>> getUserProfile() {
    return _authorizedGet("/secure/user/profile");
  }

  static Future<Map<String, dynamic>> setUserRole(String role) {
    return _authorizedPost("/secure/user/role", {"role": role});
  }

  static Future<Map<String, dynamic>> setUserPhone(String phoneNumber) {
    return _authorizedPost("/secure/user/phone", {"phoneNumber": phoneNumber});
  }

  static Future<Map<String, dynamic>> saveMedicine(
    Map<String, dynamic> payload,
  ) {
    return _authorizedPost("/secure/medicine", payload);
  }
}
