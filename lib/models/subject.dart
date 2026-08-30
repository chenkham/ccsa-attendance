class Subject {
  final String id;
  final String name; // e.g. "Data Structures & Algorithms"
  final String code; // e.g. "MCA-201"
  final String professorName;
  final String course; // "BCA", "MCA", "PGDCA"
  final int semester; // 1 to 8
  final String batchType; // "whole" | "batch_1" | "batch_2"
  final String teacherEmail;
  final List<String> enrolledStudentIds;
  final bool geofenceEnabled; // Layer 5 Geofencing toggle
  final double? latitude; // Classroom / Dept Latitude
  final double? longitude; // Classroom / Dept Longitude
  final double radiusMeters; // Geofence radius in meters (default 50.0)
  final bool isSynced;
  final DateTime createdAt;

  Subject({
    required this.id,
    required this.name,
    required this.code,
    required this.professorName,
    required this.course,
    required this.semester,
    this.batchType = 'whole',
    required this.teacherEmail,
    this.enrolledStudentIds = const [],
    this.geofenceEnabled = false,
    this.latitude,
    this.longitude,
    this.radiusMeters = 50.0,
    this.isSynced = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get batchTypeDisplay => batchLabel;

  String get batchLabel {
    switch (batchType.toLowerCase()) {
      case 'batch_1':
        return 'Batch 1 (Lab Group A)';
      case 'batch_2':
        return 'Batch 2 (Lab Group B)';
      case 'whole':
      default:
        return 'Whole Class';
    }
  }

  String get batchShortBadge {
    switch (batchType.toLowerCase()) {
      case 'batch_1':
        return 'Batch 1 (Group A)';
      case 'batch_2':
        return 'Batch 2 (Group B)';
      case 'whole':
      default:
        return 'Whole Class';
    }
  }

  String get semesterDisplay => '${_ordinal(semester)} Sem';
  String get fullBatchDisplay => '$course ${_ordinal(semester)} Sem';

  static String _ordinal(int n) {
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'professor_name': professorName,
      'course': course,
      'semester': semester,
      'batch_type': batchType,
      'teacher_email': teacherEmail,
      'geofence_enabled': geofenceEnabled ? 1 : 0,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map, {List<String>? studentIds}) {
    return Subject(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      professorName: map['professor_name'] ?? map['teacher_name'] ?? '',
      course: map['course'] ?? 'BCA',
      semester: map['semester'] is int ? map['semester'] : int.tryParse(map['semester'].toString()) ?? 1,
      batchType: map['batch_type'] ?? 'whole',
      teacherEmail: map['teacher_email'] ?? '',
      enrolledStudentIds: studentIds ?? [],
      geofenceEnabled: map['geofence_enabled'] == 1 || map['geofence_enabled'] == true,
      latitude: (map['latitude'] ?? map['geofence_lat']) != null ? (num.tryParse((map['latitude'] ?? map['geofence_lat']).toString()) ?? 0).toDouble() : null,
      longitude: (map['longitude'] ?? map['geofence_lng']) != null ? (num.tryParse((map['longitude'] ?? map['geofence_lng']).toString()) ?? 0).toDouble() : null,
      radiusMeters: (map['radius_meters'] ?? map['geofence_radius']) != null ? (num.tryParse((map['radius_meters'] ?? map['geofence_radius']).toString()) ?? 50).toDouble() : 50.0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) ?? DateTime.now() : DateTime.now(),
    );
  }
}
