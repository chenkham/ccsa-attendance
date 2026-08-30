class User {
  final String id;
  final String name;
  final String email;
  final String? password;
  final String? phone;
  final String role; // 'faculty' | 'student'
  final String? designation; // e.g. 'Assistant Professor', 'Associate Professor'
  final String? department; // e.g. 'Centre for Computer Science and Applications'
  final String? employeeId; // e.g. 'DU-FAC-012'
  final String? qualification; // e.g. 'Ph.D., MCA'
  final String? studentRollNo;
  final String? duExamRollNo;
  final String? course; // 'BCA', 'MCA', 'PGDCA'
  final int? semester; // 1 to 8
  final String? deviceId;
  final bool profileCompleted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.password,
    this.phone,
    required this.role,
    this.designation,
    this.department,
    this.employeeId,
    this.qualification,
    this.studentRollNo,
    this.duExamRollNo,
    this.course,
    this.semester,
    this.deviceId,
    this.profileCompleted = false,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isFaculty => role == 'faculty';
  bool get isStudent => role == 'student';

  User copyWith({
    String? name,
    String? email,
    String? password,
    String? phone,
    String? role,
    String? designation,
    String? department,
    String? employeeId,
    String? qualification,
    String? studentRollNo,
    String? duExamRollNo,
    String? course,
    int? semester,
    String? deviceId,
    bool? profileCompleted,
    DateTime? updatedAt,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      employeeId: employeeId ?? this.employeeId,
      qualification: qualification ?? this.qualification,
      studentRollNo: studentRollNo ?? this.studentRollNo,
      duExamRollNo: duExamRollNo ?? this.duExamRollNo,
      course: course ?? this.course,
      semester: semester ?? this.semester,
      deviceId: deviceId ?? this.deviceId,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password ?? '',
      'phone': phone,
      'role': role,
      'designation': designation,
      'department': department,
      'employee_id': employeeId,
      'qualification': qualification,
      'student_roll_no': studentRollNo,
      'du_exam_roll_no': duExamRollNo,
      'course': course,
      'semester': semester,
      'device_id': deviceId,
      'profile_completed': profileCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'],
      phone: map['phone'],
      role: map['role'] ?? 'student',
      designation: map['designation'],
      department: map['department'],
      employeeId: map['employee_id'],
      qualification: map['qualification'],
      studentRollNo: map['student_roll_no'] ?? map['studentRollNo'] ?? map['class_roll_no'],
      duExamRollNo: map['du_exam_roll_no'] ?? map['duExamRollNo'],
      course: map['course'],
      semester: map['semester'] is int ? map['semester'] : int.tryParse(map['semester']?.toString() ?? ''),
      deviceId: map['device_id'] ?? map['deviceId'],
      profileCompleted: map['profile_completed'] == 1 || map['profile_completed'] == true || map['profileCompleted'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }
}
