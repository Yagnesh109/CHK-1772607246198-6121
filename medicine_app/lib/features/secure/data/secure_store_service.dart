import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class SecureStoreService {
  static const String _host =
      "backend-medicine-app-sveri-hackathon.onrender.com";
  static String? _cachedRole;

  static String? getCachedRole() => _cachedRole;

  static Future<Map<String, dynamic>> _authorizedGet(String path) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {"error": "User not logged in."};
    }

    final token = await user.getIdToken();
    final uri = Uri.https(_host, path);
    final res = await http
        .get(uri, headers: {"Authorization": "Bearer $token"})
        .timeout(const Duration(seconds: 15));
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

    final token = await user.getIdToken();
    final uri = Uri.https(_host, path);
    final res = await http
        .post(
          uri,
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    return _decodeResponse(res);
  }

  static Future<Map<String, dynamic>> _authorizedDelete(String path) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {"error": "User not logged in."};
    }

    final token = await user.getIdToken();
    final uri = Uri.https(_host, path);
    final res = await http
        .delete(uri, headers: {"Authorization": "Bearer $token"})
        .timeout(const Duration(seconds: 15));
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

  static Future<Map<String, dynamic>> getUserProfile() async {
    final res = await _authorizedGet("/secure/user/profile");
    if (res['error'] == null) {
      _cachedRole = res['role']?.toString().trim();
    }
    return res;
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

  static Future<Map<String, dynamic>> addPatientForCaregiver({
    required String patientEmail,
    required String patientPhoneNumber,
    required String patientRelation,
  }) {
    return _authorizedPost("/secure/caregiver/patients", {
      "patientEmail": patientEmail,
      "patientPhoneNumber": patientPhoneNumber,
      "patientRelation": patientRelation,
    });
  }

  static Future<Map<String, dynamic>> getCaregiverPatients() {
    return _authorizedGet("/secure/caregiver/patients");
  }

  static Future<Map<String, dynamic>> getMedicines() {
    return _authorizedGet("/secure/medicines");
  }

  static Future<Map<String, dynamic>> getTodayPendingMedicines() {
    return _authorizedGet("/secure/medicines/pending-today");
  }

  static Future<Map<String, dynamic>> getTodayMedicineSummary() {
    return _authorizedGet("/secure/medicines/today-summary");
  }

  static Future<Map<String, dynamic>> markMedicineTaken(String medicineId) {
    return _authorizedPost("/secure/medicines/$medicineId/taken", {});
  }

  static Future<Map<String, dynamic>> deleteMedicine(String medicineId) {
    return _authorizedDelete("/secure/medicines/$medicineId");
  }

  static Future<Map<String, dynamic>> clearMedicineHistory() {
    return _authorizedDelete("/secure/medicines/history");
  }

  static Future<Map<String, dynamic>> deleteCaregiverPatient(String patientId) {
    return _authorizedDelete("/secure/caregiver/patients/$patientId");
  }
}
