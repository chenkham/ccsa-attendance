import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/user.dart';
import '../models/student.dart';
import '../models/subject.dart';
import '../models/attendance_session.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ccsa_smart_attendance_v4.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    DatabaseFactory dbFactory;
    String dbPath;

    if (kIsWeb) {
      dbFactory = createDatabaseFactoryFfiWeb(
        options: SqfliteFfiWebOptions(inMemory: true),
      );
      dbPath = inMemoryDatabasePath;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      dbFactory = databaseFactoryFfi;
      final appDocDir = await getApplicationSupportDirectory();
      if (!await appDocDir.exists()) {
        await appDocDir.create(recursive: true);
      }
      dbPath = join(appDocDir.path, filePath);
    } else {
      dbFactory = databaseFactory;
      final defaultPath = await getDatabasesPath();
      dbPath = join(defaultPath, filePath);
    }

    return await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
        onOpen: (db) async {
          await db.execute('CREATE INDEX IF NOT EXISTS idx_students_course_sem ON students(course, semester);');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_records_session ON attendance_records(session_id);');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_records_student ON attendance_records(student_id);');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_teacher ON attendance_sessions(teacher_email);');
        },
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Users Table (Faculty & Students)
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        phone TEXT,
        role TEXT NOT NULL, -- 'faculty' | 'student'
        designation TEXT,
        department TEXT,
        employee_id TEXT,
        qualification TEXT,
        student_roll_no TEXT,
        du_exam_roll_no TEXT,
        course TEXT,
        semester INTEGER,
        device_id TEXT,
        profile_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      );
    ''');

    // 2. Students Master Table
    await db.execute('''
      CREATE TABLE students (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        class_roll_no TEXT NOT NULL DEFAULT '',
        du_exam_roll_no TEXT NOT NULL DEFAULT '',
        course TEXT NOT NULL, -- 'BCA', 'MCA', 'PGDCA'
        semester INTEGER NOT NULL, -- 1 to 8
        phone TEXT,
        email TEXT,
        bound_device_id TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      );
    ''');

    // 3. Subjects Table
    await db.execute('''
      CREATE TABLE subjects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        professor_name TEXT NOT NULL,
        course TEXT NOT NULL,
        semester INTEGER NOT NULL,
        batch_type TEXT NOT NULL DEFAULT 'whole',
        teacher_email TEXT NOT NULL,
        geofence_enabled INTEGER NOT NULL DEFAULT 0,
        latitude REAL,
        longitude REAL,
        radius_meters REAL NOT NULL DEFAULT 50.0,
        is_synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      );
    ''');

    // 4. Subject-Students Junction Table (Many-to-Many)
    await db.execute('''
      CREATE TABLE subject_students (
        subject_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        PRIMARY KEY (subject_id, student_id),
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      );
    ''');

    // 5. Attendance Sessions Table
    await db.execute('''
      CREATE TABLE attendance_sessions (
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        subject_code TEXT NOT NULL,
        subject_name TEXT NOT NULL,
        session_date TEXT NOT NULL,
        is_lab INTEGER NOT NULL DEFAULT 0,
        duration_hours INTEGER NOT NULL DEFAULT 1,
        teacher_email TEXT NOT NULL,
        total_enrolled INTEGER NOT NULL,
        total_present INTEGER NOT NULL,
        geofence_enabled INTEGER NOT NULL DEFAULT 0,
        session_lat REAL,
        session_lng REAL,
        session_radius REAL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      );
    ''');

    // 6. Attendance Records Table
    await db.execute('''
      CREATE TABLE attendance_records (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        student_roll_no TEXT NOT NULL,
        student_name TEXT NOT NULL,
        status TEXT NOT NULL, -- 'present' | 'absent'
        marked_by TEXT NOT NULL DEFAULT 'dynamic_qr',
        confidence REAL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES attendance_sessions (id) ON DELETE CASCADE
      );
    ''');
  }

  // -------------------------------------------------------------
  // USER OPERATIONS
  // -------------------------------------------------------------

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserById(String id) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<void> insertUser(User user) async {
    final db = await database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateUserProfile(User user) async {
    final db = await database;
    await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<bool> changeUserPassword(String email, String newPassword) async {
    final db = await database;
    final count = await db.update(
      'users',
      {'password': newPassword, 'updated_at': DateTime.now().toIso8601String()},
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    return count > 0;
  }

  Future<bool> changeUserEmail(String userId, String newEmail) async {
    final db = await database;
    final cleanEmail = newEmail.trim().toLowerCase();
    final count = await db.update(
      'users',
      {'email': cleanEmail, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [userId],
    );
    await db.update(
      'students',
      {'email': cleanEmail},
      where: 'id = ?',
      whereArgs: [userId],
    );
    return count > 0;
  }

  // -------------------------------------------------------------
  // STUDENT ROSTER OPERATIONS
  // -------------------------------------------------------------

  Future<Student?> getStudentByRollNo(String rollNo) async {
    final db = await database;
    final maps = await db.query(
      'students',
      where: 'UPPER(class_roll_no) = ?',
      whereArgs: [rollNo.trim().toUpperCase()],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Student.fromMap(maps.first);
    }
    return null;
  }

  Future<Student?> getStudentById(String id) async {
    final db = await database;
    final maps = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Student.fromMap(maps.first);
    }
    return null;
  }

  Future<void> insertStudent(Student student) async {
    final db = await database;
    await db.insert(
      'students',
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateStudentProfile(Student student) async {
    final db = await database;
    await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<void> updateStudentDevice(String studentId, String deviceId) async {
    final db = await database;
    await db.update(
      'students',
      {'bound_device_id': deviceId},
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  Future<List<Student>> getAllStudents() async {
    final db = await database;
    final maps = await db.query('students', orderBy: 'class_roll_no ASC');
    return maps.map((m) => Student.fromMap(m)).toList();
  }

  Future<List<Student>> getStudentsByCourseAndSemester(String course, int semester) async {
    final db = await database;
    final maps = await db.query(
      'students',
      where: 'course = ? AND semester = ?',
      whereArgs: [course, semester],
      orderBy: 'class_roll_no ASC',
    );
    return maps.map((m) => Student.fromMap(m)).toList();
  }

  Future<List<Student>> getStudentsForSubject(String subjectId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT s.* FROM students s
      INNER JOIN subject_students ss ON s.id = ss.student_id
      WHERE ss.subject_id = ?
      ORDER BY s.class_roll_no ASC
    ''', [subjectId]);

    return maps.map((m) => Student.fromMap(m)).toList();
  }

  // -------------------------------------------------------------
  // SUBJECT OPERATIONS
  // -------------------------------------------------------------

  Future<void> insertSubject(Subject subject) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'subjects',
        subject.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        'subject_students',
        where: 'subject_id = ?',
        whereArgs: [subject.id],
      );

      for (var studentId in subject.enrolledStudentIds) {
        await txn.insert(
          'subject_students',
          {'subject_id': subject.id, 'student_id': studentId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<List<Subject>> getSubjectsByTeacher(String teacherEmail) async {
    final db = await database;
    final maps = await db.query(
      'subjects',
      where: 'LOWER(teacher_email) = ?',
      whereArgs: [teacherEmail.trim().toLowerCase()],
      orderBy: 'created_at DESC',
    );

    List<Subject> subjects = [];
    for (var m in maps) {
      final subjectId = m['id'] as String;
      final studentIdMaps = await db.query(
        'subject_students',
        columns: ['student_id'],
        where: 'subject_id = ?',
        whereArgs: [subjectId],
      );
      final studentIds = studentIdMaps.map((e) => e['student_id'] as String).toList();
      subjects.add(Subject.fromMap(m, studentIds: studentIds));
    }

    return subjects;
  }

  Future<Subject?> getSubjectById(String subjectId) async {
    final db = await database;
    final maps = await db.query(
      'subjects',
      where: 'id = ?',
      whereArgs: [subjectId],
      limit: 1,
    );
    if (maps.isEmpty) return null;

    final studentIdMaps = await db.query(
      'subject_students',
      columns: ['student_id'],
      where: 'subject_id = ?',
      whereArgs: [subjectId],
    );
    final studentIds = studentIdMaps.map((e) => e['student_id'] as String).toList();
    return Subject.fromMap(maps.first, studentIds: studentIds);
  }

  Future<void> deleteSubject(String subjectId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('subject_students', where: 'subject_id = ?', whereArgs: [subjectId]);
      await txn.delete('attendance_records', where: 'session_id IN (SELECT id FROM attendance_sessions WHERE subject_id = ?)', whereArgs: [subjectId]);
      await txn.delete('attendance_sessions', where: 'subject_id = ?', whereArgs: [subjectId]);
      await txn.delete('subjects', where: 'id = ?', whereArgs: [subjectId]);
    });
  }

  Future<List<Subject>> getSubjectsForStudent(String studentId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT s.* FROM subjects s
      INNER JOIN subject_students ss ON s.id = ss.subject_id
      WHERE ss.student_id = ?
      ORDER BY s.code ASC
    ''', [studentId]);

    return maps.map((m) => Subject.fromMap(m)).toList();
  }

  // -------------------------------------------------------------
  // ATTENDANCE SESSION & RECORD OPERATIONS
  // -------------------------------------------------------------

  Future<void> insertAttendanceSession(AttendanceSession session, List<AttendanceRecord> records) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'attendance_sessions',
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Remove existing records for this session before inserting final roster
      await txn.delete(
        'attendance_records',
        where: 'session_id = ?',
        whereArgs: [session.id],
      );

      for (var record in records) {
        await txn.insert(
          'attendance_records',
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<AttendanceRecord>> getRecordsForSession(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      'attendance_records',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return maps.map((m) => AttendanceRecord.fromMap(m)).toList();
  }

  Future<List<AttendanceSession>> getAllSessionsForTeacher(String teacherEmail) async {
    final db = await database;
    final maps = await db.query(
      'attendance_sessions',
      where: 'LOWER(teacher_email) = ?',
      whereArgs: [teacherEmail.trim().toLowerCase()],
      orderBy: 'session_date DESC',
    );
    return maps.map((m) => AttendanceSession.fromMap(m)).toList();
  }

  Future<List<AttendanceSession>> getSessionsForSubject(String subjectId) async {
    final db = await database;
    final maps = await db.query(
      'attendance_sessions',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'session_date DESC',
    );
    return maps.map((m) => AttendanceSession.fromMap(m)).toList();
  }

  Future<AttendanceSession?> getSessionById(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      'attendance_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AttendanceSession.fromMap(maps.first);
  }

  Future<void> recordSingleStudentAttendance({
    required String sessionId,
    required String studentId,
    required String studentRollNo,
    required String studentName,
  }) async {
    final db = await database;
    final record = AttendanceRecord(
      id: const Uuid().v4(),
      sessionId: sessionId,
      studentId: studentId,
      studentRollNo: studentRollNo,
      studentName: studentName,
      status: 'present',
      markedBy: 'dynamic_qr',
      createdAt: DateTime.now(),
    );
    await db.insert(
      'attendance_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.rawUpdate('''
      UPDATE attendance_sessions 
      SET total_present = (SELECT COUNT(*) FROM attendance_records WHERE session_id = ? AND status = 'present')
      WHERE id = ?
    ''', [sessionId, sessionId]);
  }

  // -------------------------------------------------------------
  // ATTENDANCE ANALYTICS (STUDENT & FACULTY)
  // -------------------------------------------------------------

  Future<Map<String, dynamic>> getStudentSubjectAttendanceStats(String studentId, String subjectId) async {
    final db = await database;

    final sessions = await db.rawQuery('''
      SELECT 
        s.id AS session_id,
        s.is_lab,
        s.session_date,
        COALESCE(MAX(r.status), 'absent') AS status
      FROM attendance_sessions s
      LEFT JOIN attendance_records r ON s.id = r.session_id AND r.student_id = ?
      WHERE s.subject_id = ?
      GROUP BY s.id, s.is_lab, s.session_date
      ORDER BY s.session_date DESC
    ''', [studentId, subjectId]);

    int totalClasses = sessions.length;
    int attendedClasses = sessions.where((s) => s['status'] == 'present').length;
    int missedClasses = totalClasses - attendedClasses;

    final double percentage = totalClasses > 0
        ? (attendedClasses / totalClasses) * 100
        : 100.0;

    return {
      'total': totalClasses,
      'attended': attendedClasses,
      'missed': missedClasses,
      'totalSessions': totalClasses,
      'attendedSessions': attendedClasses,
      'percentage': percentage,
      'history': sessions,
    };
  }

  Future<List<Map<String, dynamic>>> getStudentDetailedHistory(String studentId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        s.id AS session_id,
        s.subject_code,
        s.subject_name,
        s.session_date,
        s.is_lab,
        s.teacher_email,
        COALESCE(MAX(r.status), 'absent') AS status,
        MAX(r.marked_by) AS marked_by
      FROM attendance_sessions s
      INNER JOIN attendance_records r ON s.id = r.session_id
      WHERE r.student_id = ?
      GROUP BY s.id, s.subject_code, s.subject_name, s.session_date, s.is_lab, s.teacher_email
      ORDER BY s.session_date DESC
    ''', [studentId]);
  }
}
