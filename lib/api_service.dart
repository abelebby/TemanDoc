import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
  static final ValueNotifier<int> appointmentRefreshTrigger = ValueNotifier(0);
  // ─── AUTHENTICATION ───

  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/doctors/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['access_token']);
        await prefs.setString('doctor_id', data['doctor_id'] ?? '');
        await prefs.setString('doctor_name', data['doctor_name'] ?? '');
        await prefs.setString('preferred_name', data['preferred_name'] ?? '');
        return {'success': true};
      } else {
        final decoded = jsonDecode(response.body);
        return {'success': false, 'message': decoded['detail'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server. Please check your internet.'};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('doctor_id');
    await prefs.remove('doctor_name');
    await prefs.remove('preferred_name');
  }

  static Future<bool> hasValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return false;

    // Quick validation: try hitting /doctors/me
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/doctors/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // ─── PROFILE ───

  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/doctors/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        return {'error': 'session_expired'};
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('$_baseUrl/doctors/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── PATIENTS ───

  static Future<List<Map<String, dynamic>>> getPatients() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/care-team/doctor/patients'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPatientMetrics(int userId) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/care-team/doctor/patients/$userId/metrics'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPatientActivity(int userId) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/care-team/doctor/patients/$userId/activity'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPatientMedications(int userId) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/care-team/doctor/patients/$userId/medications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ─── APPOINTMENTS ───

  static Future<List<Map<String, dynamic>>> getAppointments() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/care-team/doctor/appointments'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> updateAppointmentStatus(int id, String status) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.patch(
        Uri.parse('$_baseUrl/care-team/doctor/appointments/$id/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── MEDICAL RECORDS ───

  static Future<List<Map<String, dynamic>>> getRecords({int? userId}) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      String url = '$_baseUrl/care-team/doctor/records';
      if (userId != null) url += '?user_id=$userId';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> saveRecord({
  required String doctorId,
  required int userId,
  required String fileName,
  required String recordType,
  required String fileUrl,
  String? description,
}) async {
  try {
    final token = await _getToken();
    if (token == null) return false;

    final response = await http.post(
      Uri.parse('$_baseUrl/care-team/doctor/records'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'user_id': userId,        // this was missing so i added it
        'doctor_id': doctorId,
        'file_name': fileName,
        'record_type': recordType,
        'file_url': fileUrl,
        'description': description,
      }),
    );

    return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // AWS S3 SECURE FILE UPLOAD & DOWNLOAD
  // ==========================================

  /// Get a secure Pre-signed URL to upload a file to AWS S3 for a specific patient
  static Future<Map<String, dynamic>?> getUploadUrl({
    required int patientId,
    required String fileName,
    required String fileType,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      // Encode parameters to safely handle spaces and special characters in filenames
      final encodedName = Uri.encodeComponent(fileName);
      final encodedType = Uri.encodeComponent(fileType);
      
      final url = Uri.parse(
        '$_baseUrl/care-team/doctor/records/upload-url?patient_id=$patientId&file_name=$encodedName&file_type=$encodedType'
      );
      
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Failed to get upload URL: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error getting upload URL: $e");
      return null;
    }
  }

  /// Get a secure Pre-signed URL to view/download a private file from AWS S3
  static Future<Map<String, dynamic>?> getDownloadUrl(int recordId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final url = Uri.parse('$_baseUrl/care-team/doctor/records/$recordId/download-url');
      
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Failed to get download URL: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error getting download URL: $e");
      return null;
    }
  }
  
  // ─── PATIENT MANAGEMENT ───

  static Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/care-team/doctor/search-patient?query=${Uri.encodeComponent(query)}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> addPatient(int userId) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Not authenticated'};

      final response = await http.post(
        Uri.parse('$_baseUrl/care-team/doctor/add-patient/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message'] ?? 'Patient added'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['detail'] ?? 'Failed to add patient'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/care-team/doctor/pending-requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> removePatient(int userId) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/care-team/doctor/remove-patient/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> withdrawRequest(int requestId) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/care-team/doctor/pending-requests/$requestId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── ACCOUNT DELETION ───

  static Future<bool> deleteAccount() async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/doctors/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── APPOINTMENT BOOKING ───

  static Future<Map<String, dynamic>> bookAppointmentForPatient({
      required int userId,
      required String appointmentTime,
      required String purpose,
    }) async {
      try {
        final token = await _getToken();
        if (token == null) return {'success': false};

        final response = await http.post(
          Uri.parse('$_baseUrl/care-team/doctor/appointments'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'user_id': userId,
            'appointment_time': appointmentTime, // <-- Just pass the raw string
            'purpose': purpose,
          }),
        );

      if (response.statusCode == 200) return {'success': true};
      final decoded = jsonDecode(response.body);
      return {'success': false, 'message': decoded['detail'] ?? 'Failed to book appointment'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server.'};
    }
  }
}
