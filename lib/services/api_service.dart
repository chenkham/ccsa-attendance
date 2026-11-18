import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/attendance_session.dart';
import '../models/student.dart';
import '../models/subject.dart';
import '../models/user.dart';
import 'device_security_service.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // Hostinger backend API base URL
  // VERIFIED LIVE (curl 200 + real DB responses): /endpoints
  // /src/endpoints and /api both return 404 on the live server.
  static const List<String> _baseUrls = [
    'https://ccsdu.in/endpoints',
  ];

  static const Duration _timeout = Duration(seconds: 20);

  Future<void> initialize() async {}

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      };

  Future<http.Response?> _postToCloud(String scriptName, Map<String, dynamic> body) async {
    for (final base in _baseUrls) {
      try {
        final uri = Uri.parse('$base/$scriptName');
        final response = await http
            .post(
              uri,
              headers: _headers,
              body: jsonEncode(body),
            )
            .timeout(_timeout);

        final text = response.body.trim();
        if (text.startsWith('{') && text.endsWith('}')) {
          return response;
        }
      } catch (e) {
        debugPrint('ApiService cloud request to $base/$scriptName failed: $e');
      }
    }
    return null;
  }

  Future<http.Response?> _getFromCloud(String scriptName, String queryParams) async {
    for (final base in _baseUrls) {
      try {
        final uri = Uri.parse('$base/$scriptName?$queryParams');
        final response = await http.get(uri, headers: _headers).timeout(_timeout);

        final text = response.body.trim();
        if (text.startsWith('{') && text.endsWith('}')) {
          return response;
        }
      } catch (e) {
        debugPrint('ApiService cloud GET to $base/$scriptName failed: $e');
      }
    }
    return null;
  }

  /// 1. Check if an account already exists with the given email or student name
  Future<Map<String, dynamic>> checkUserExists({
    required String email,
    required String name,
    required String role,
  }) async {
    final response = await _postToCloud('check_user_exists.php', {
      'email': email.trim(),
      'name': name.trim(),
      'role': role.trim(),
    });

    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } catch (_) {}
    }

    return {'success': true, 'exists': false};
  }

  /// 2. Send 6-digit verification OTP to user's real email via Hostinger SMTP
  Future<Map<String, dynamic>> sendOtp({
    required String email,
    required String name,
    String type = 'signup',
  }) async {
    final response = await _postToCloud('send_otp.php', {
      'email': email.trim(),
      'name': name.trim(),
      'type': type,
    });

    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } catch (_) {}
    }

    return {
      'success': false,
      'message': 'Failed to connect to email server. Please check your internet connection or server setup.',
    };
  }

  /// 3. Verify OTP and complete user registration in Hostinger database
  Future<Map<String, dynamic>> verifySignup({
    required String email,
    required String otp,
    required String name,
    required String password,
    required String role,
    String course = 'BCA',
    int semester = 1,
    String classRollNo = '',
    String duExamRollNo = '',
    String deviceId = '',
    String designation = 'Assistant Professor',
    String department = 'CCSA, Dibrugarh University',
  }) async {
    final response = await _postToCloud('verify_signup.php', {
      'email': email.trim(),
      'otp': otp.trim(),
      'name': name.trim(),
      'password': password,
      'role': role,
      'course': course,
      'semester': semester,
      'class_roll_no': classRollNo.trim(),
      'du_exam_roll_no': duExamRollNo.trim(),
      'device_id': deviceId,
      'designation': designation,
      'department': department,
    });

    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } catch (_) {}
    }

    return {
      'success': false,
      'message': 'Server verification failed. Please try again.',
    };
  }

  /// 4. Online login verification against Hostinger MySQL database
  Future<Map<String, dynamic>> loginOnline({
    required String email,
    required String password,
    String? deviceId,
  }) async {
    final devId = deviceId ?? await DeviceSecurityService.instance.getHardwareDeviceId();
    final response = await _postToCloud('login.php', {
      'email': email.trim(),
      'password': password,
      'device_id': devId,
    });

    if (response != null) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['user'] != null) {
          final uMap = data['user'] as Map<String, dynamic>;
          return {
            'success': true,
            'user': User.fromMap(uMap),
            'message': data['message'] ?? 'Login successful!',
          };
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Incorrect password or account not found.',
        };
      } catch (_) {}
    }
    return {
      'success': false,
      'is_network_error': true,
      'message': 'Unable to connect to authentication server.',
    };
  }

  /// 5. Fetch ONLY registered students from Hostinger MySQL for Course & Semester
  Future<List<Student>> getRegisteredStudents({
    required String course,
    required int semester,
  }) async {
    final response = await _getFromCloud(
      'get_registered_students.php',
      'course=${Uri.encodeComponent(course)}&semester=$semester',
    );

    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['students'] is List) {
          final list = (data['students'] as List).map((s) {
            return Student.fromMap(s as Map<String, dynamic>);
          }).toList();
          return list;
        }
      } catch (_) {}
    }
    return [];
  }

  /// 6. Sync Subject & enrolled student IDs to Hostinger MySQL
  Future<bool> syncSubject(Subject subject) async {
    final response = await _postToCloud('sync_subject.php', {
      'id': subject.id,
      'code': subject.code,
      'name': subject.name,
      'course': subject.course,
      'semester': subject.semester,
      'teacher_name': subject.professorName,
      'teacher_email': subject.teacherEmail,
      'geofence_lat': subject.latitude,
      'geofence_lng': subject.longitude,
      'geofence_radius': subject.radiusMeters,
      'geofence_enabled': subject.geofenceEnabled ? 1 : 0,
      'enrolled_student_ids': subject.enrolledStudentIds,
    });

    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      } catch (_) {}
    }
    return false;
  }

  /// 7. Sync completed Attendance Session & Records to Hostinger MySQL
  Future<bool> syncAttendanceSession(
    AttendanceSession session,
    List<AttendanceRecord> records,
  ) async {
    final response = await _postToCloud('sync_attendance.php', {
      'session': session.toMap(),
      'records': records.map((r) => r.toMap()).toList(),
    });

    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      } catch (_) {}
    }
    return false;
  }

  /// 8. Update profile details and roll numbers in Hostinger MySQL
  Future<bool> updateProfileInCloud(User user) async {
    final response = await _postToCloud('update_profile.php', {
      'id': user.id,
      'email': user.email,
      'name': user.name,
      'class_roll_no': user.studentRollNo ?? '',
      'du_exam_roll_no': user.duExamRollNo ?? '',
      'course': user.course ?? 'BCA',
      'semester': user.semester ?? 1,
      'designation': user.designation ?? '',
      'department': user.department ?? '',
      'role': user.role,
    });

    if (response != null) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      } catch (_) {}
    }
    return false;
  }

  /// 9. Verify Reset OTP in Hostinger MySQL (Step 2 of Forgot Password)
  Future<Map<String, dynamic>> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _postToCloud('verify_reset_otp.php', {
      'email': email.trim(),
      'otp': otp.trim(),
    });

    if (response != null) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } catch (_) {}
    }

    return {
      'success': false,
      'message': 'Failed to connect to verification server. Please check your connection.',
    };
  }

  /// 10. Update Password in Hostinger MySQL (Step 3 of Forgot Password)
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await _postToCloud('reset_password.php', {
      'email': email.trim(),
      'otp': otp.trim(),
      'new_password': newPassword,
    });

    if (response != null) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } catch (_) {}
    }

    return {
      'success': false,
      'message': 'Failed to connect to server. Please try again.',
    };
  }

  /// 11a. Fetch Student's Enrolled Subjects from Hostinger MySQL Cloud
  Future<List<Subject>> getStudentSubjectsFromCloud({
    required String email,
    required String studentId,
  }) async {
    final response = await _getFromCloud(
      'get_student_subjects.php',
      'email=${Uri.encodeComponent(email.trim())}&student_id=${Uri.encodeComponent(studentId.trim())}',
    );

    if (response != null) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['subjects'] is List) {
          final list = (data['subjects'] as List).map((s) {
            final map = s as Map<String, dynamic>;
            final enrolledIds = (map['enrolled_student_ids'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            return Subject.fromMap(map, studentIds: enrolledIds);
          }).toList();
          return list;
        }
      } catch (_) {}
    }
    return [];
  }

  /// 11b. Fetch Student Attendance & Statistics strictly from Hostinger MySQL Cloud
  Future<Map<String, dynamic>?> getStudentAttendanceFromCloud({
    required String email,
    required String studentId,
  }) async {
    final response = await _getFromCloud(
      'get_student_attendance.php',
      'email=${Uri.encodeComponent(email.trim())}&student_id=${Uri.encodeComponent(studentId.trim())}',
    );

    if (response != null) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        }
      } catch (_) {}
    }
    return null;
  }

  /// 12. Fetch Faculty Subjects from Hostinger MySQL
  Future<List<Subject>> getFacultySubjects(String teacherEmail) async {
    final response = await _getFromCloud(
      'get_faculty_subjects.php',
      'email=${Uri.encodeComponent(teacherEmail.trim())}',
    );

    if (response != null) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['subjects'] is List) {
          final list = (data['subjects'] as List).map((s) {
            final map = s as Map<String, dynamic>;
            final enrolledIds = (map['enrolled_student_ids'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            return Subject.fromMap(map, studentIds: enrolledIds);
          }).toList();
          return list;
        }
      } catch (_) {}
    }
    return [];
  }

  /// 13. Fetch Faculty Sessions from Hostinger MySQL
  Future<List<AttendanceSession>> getFacultySessions({
    String? teacherEmail,
    String? subjectId,
  }) async {
    String q = '';
    if (subjectId != null && subjectId.isNotEmpty) {
      q = 'subject_id=${Uri.encodeComponent(subjectId)}';
    } else if (teacherEmail != null && teacherEmail.isNotEmpty) {
      q = 'email=${Uri.encodeComponent(teacherEmail)}';
    }

    final response = await _getFromCloud('get_faculty_sessions.php', q);

    if (response != null) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['sessions'] is List) {
          final list = (data['sessions'] as List).map((s) {
            final map = s as Map<String, dynamic>;
            // Records enable per-student roster computation on Subject Details
            final records = (map['records'] as List?)
                    ?.map((r) => AttendanceRecord.fromMap(Map<String, dynamic>.from(r as Map)))
                    .toList() ??
                const <AttendanceRecord>[];
            return AttendanceSession.fromMap(map, records: records);
          }).toList();
          return list;
        }
      } catch (_) {}
    }
    return [];
  }

  /// 14. Delete Subject in Hostinger MySQL
  Future<bool> deleteSubject(String subjectId) async {
    final response = await _postToCloud('delete_subject.php', {
      'subject_id': subjectId,
    });

    if (response != null) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      } catch (_) {}
    }
    return false;
  }

  /// 14b. Delete attendance sessions for a subject matching an id prefix.
  /// Used by the physical-register baseline import so a re-import REPLACES
  /// the previous baseline instead of duplicating historical sessions.
  Future<bool> deleteSubjectSessions(String subjectId, String idPrefix) async {
    final response = await _postToCloud('delete_subject_sessions.php', {
      'subject_id': subjectId,
      'id_prefix': idPrefix,
    });

    if (response != null) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      } catch (_) {}
    }
    return false;
  }

  /// 15. Real-time Student QR Attendance Scan to Hostinger MySQL
  Future<bool> recordStudentAttendanceLive({
    required String sessionId,
    required String studentId,
    required String email,
    required String name,
    required String rollNo,
    String? subjectId,
    String? subjectCode,
    String? subjectName,
    String? teacherEmail,
    String markedBy = 'totp_qr',
  }) async {
    final response = await _postToCloud('record_student_attendance.php', {
      'session_id': sessionId,
      'student_id': studentId,
      'email': email,
      'name': name,
      'roll_no': rollNo,
      'subject_id': subjectId ?? '',
      'subject_code': subjectCode ?? '',
      'subject_name': subjectName ?? '',
      'teacher_email': teacherEmail ?? '',
      'marked_by': markedBy,
    });

    if (response != null && response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      } catch (_) {}
    }
    return false;
  }

  /// 16. Get Live Turnout for Active QR Session in Hostinger MySQL
  /// Returns one row per UNIQUE student marked present (NOT aggregated
  /// identifiers — counting those inflated turnout like 3/2 for one scan).
  Future<List<Map<String, dynamic>>> getSessionTurnoutLive(String sessionId) async {
    final response = await _getFromCloud(
      'get_session_turnout.php',
      'session_id=${Uri.encodeComponent(sessionId)}',
    );

    if (response != null) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          if (data['present_students'] is List) {
            return (data['present_students'] as List)
                .map((st) => Map<String, dynamic>.from(st as Map))
                .toList();
          }
          if (data['present_student_ids'] is List) {
            return (data['present_student_ids'] as List)
                .map((id) => {'student_id': id.toString()})
                .toList();
          }
        }
      } catch (_) {}
    }
    return [];
  }

  /// 17. Change Password in Hostinger MySQL (with current password verification)
  Future<Map<String, dynamic>> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _postToCloud('change_password.php', {
      'email': email.trim(),
      'current_password': currentPassword,
      'new_password': newPassword,
    });

    if (response != null) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } catch (_) {}
    }

    return {
      'success': false,
      'message': 'Failed to connect to server. Please check your internet connection.',
    };
  }

  /// 18. Fetch Session Details & Student Attendance Records from Hostinger MySQL
  Future<Map<String, dynamic>?> getSessionDetails(String sessionId) async {
    final response = await _getFromCloud(
      'get_session_details.php',
      'session_id=${Uri.encodeComponent(sessionId.trim())}',
    );

    if (response != null) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        }
      } catch (_) {}
    }
    return null;
  }
}
