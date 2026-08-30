class Student {
  final String id;
  final String name;
  final String classRollNo;
  final String duExamRollNo;
  final String course; // BCA, MCA, PGDCA
  final int semester; // 1 to 8
  final String? phone;
  final String? email;
  final String? boundDeviceId; // Hardware device ID locked to student
  final bool isSynced;
  final DateTime createdAt;

  Student({
    required this.id,
    required this.name,
    required this.classRollNo,
    required this.duExamRollNo,
    required this.course,
    required this.semester,
    this.phone,
    this.email,
    this.boundDeviceId,
    this.isSynced = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get semesterDisplay {
    if (semester == 1) return '1st Sem';
    if (semester == 2) return '2nd Sem';
    if (semester == 3) return '3rd Sem';
    return '${semester}th Sem';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'class_roll_no': classRollNo,
      'du_exam_roll_no': duExamRollNo,
      'course': course,
      'semester': semester,
      'phone': phone,
      'email': email,
      'bound_device_id': boundDeviceId,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      classRollNo: (map['class_roll_no'] ?? map['classRollNo'] ?? map['student_roll_no'] ?? map['studentRollNo'] ?? '').toString(),
      duExamRollNo: (map['du_exam_roll_no'] ?? map['duExamRollNo'] ?? '').toString(),
      course: map['course'] ?? 'BCA',
      semester: map['semester'] is int ? map['semester'] : int.tryParse(map['semester']?.toString() ?? '') ?? 1,
      phone: map['phone'],
      email: map['email'],
      boundDeviceId: map['bound_device_id'] ?? map['device_id'],
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
