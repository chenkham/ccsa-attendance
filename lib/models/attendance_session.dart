class AttendanceRecord {
  final String id;
  final String sessionId;
  final String studentId;
  final String studentRollNo;
  final String studentName;
  final String status; // 'present' | 'absent'
  final String markedBy; // 'dynamic_qr' | 'manual'
  final double? confidence;
  final DateTime createdAt;

  AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.studentRollNo,
    required this.studentName,
    required this.status,
    this.markedBy = 'dynamic_qr',
    this.confidence,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPresent => status.toLowerCase() == 'present';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'student_id': studentId,
      'student_roll_no': studentRollNo,
      'student_name': studentName,
      'status': status,
      'marked_by': markedBy,
      'confidence': confidence,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] ?? '',
      sessionId: map['session_id'] ?? '',
      studentId: map['student_id'] ?? '',
      studentRollNo: map['student_roll_no'] ?? '',
      studentName: map['student_name'] ?? '',
      status: map['status'] ?? 'absent',
      markedBy: map['marked_by'] ?? 'dynamic_qr',
      confidence: map['confidence'] != null ? (num.tryParse(map['confidence'].toString()) ?? 0).toDouble() : null,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class AttendanceSession {
  final String id;
  final String subjectId;
  final String subjectCode;
  final String subjectName;
  final DateTime sessionDate;
  final bool isLab; // true = 2 Hours Credit, false = 1 Hour Theory
  final int durationHours; // 1 or 2
  final String teacherEmail;
  final int totalEnrolled;
  final int totalPresent;
  final bool geofenceEnabled;
  final double? sessionLat;
  final double? sessionLng;
  final double? sessionRadius;
  final bool isSynced;
  final List<AttendanceRecord> records;
  final DateTime createdAt;

  AttendanceSession({
    required this.id,
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    required this.sessionDate,
    required this.isLab,
    int? durationHours,
    required this.teacherEmail,
    required this.totalEnrolled,
    required this.totalPresent,
    this.geofenceEnabled = false,
    this.sessionLat,
    this.sessionLng,
    this.sessionRadius,
    this.isSynced = false,
    this.records = const [],
    DateTime? createdAt,
  })  : durationHours = durationHours ?? (isLab ? 2 : 1),
        createdAt = createdAt ?? DateTime.now();

  int get totalAbsent => (totalEnrolled - totalPresent).clamp(0, totalEnrolled);
  double get attendancePercentage => totalEnrolled > 0 ? (totalPresent / totalEnrolled) * 100 : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'session_date': sessionDate.toIso8601String(),
      'is_lab': isLab ? 1 : 0,
      'duration_hours': durationHours,
      'teacher_email': teacherEmail,
      'total_enrolled': totalEnrolled,
      'total_present': totalPresent,
      'geofence_enabled': geofenceEnabled ? 1 : 0,
      'session_lat': sessionLat,
      'session_lng': sessionLng,
      'session_radius': sessionRadius,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AttendanceSession.fromMap(Map<String, dynamic> map, {List<AttendanceRecord>? records}) {
    final isLab = map['is_lab'] == 1 || map['is_lab'] == true;
    return AttendanceSession(
      id: map['id'] ?? '',
      subjectId: map['subject_id'] ?? '',
      subjectCode: map['subject_code'] ?? '',
      subjectName: map['subject_name'] ?? '',
      sessionDate: map['session_date'] != null ? DateTime.tryParse(map['session_date']) ?? DateTime.now() : DateTime.now(),
      isLab: isLab,
      durationHours: map['duration_hours'] is int ? map['duration_hours'] : (int.tryParse(map['duration_hours']?.toString() ?? '') ?? (isLab ? 2 : 1)),
      teacherEmail: map['teacher_email'] ?? '',
      totalEnrolled: map['total_enrolled'] is int ? map['total_enrolled'] : (int.tryParse(map['total_enrolled']?.toString() ?? '') ?? 0),
      totalPresent: map['total_present'] is int ? map['total_present'] : (int.tryParse(map['total_present']?.toString() ?? '') ?? 0),
      geofenceEnabled: map['geofence_enabled'] == 1 || map['geofence_enabled'] == true,
      sessionLat: map['session_lat'] != null ? (num.tryParse(map['session_lat'].toString()) ?? 0).toDouble() : null,
      sessionLng: map['session_lng'] != null ? (num.tryParse(map['session_lng'].toString()) ?? 0).toDouble() : null,
      sessionRadius: map['session_radius'] != null ? (num.tryParse(map['session_radius'].toString()) ?? 0).toDouble() : null,
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
      records: records ?? [],
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) ?? DateTime.now() : DateTime.now(),
    );
  }
}
