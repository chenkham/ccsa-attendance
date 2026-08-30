import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../db/database_helper.dart';
import '../../models/attendance_session.dart';
import '../../models/student.dart';
import '../../models/subject.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/past_attendance_csv_service.dart';
import '../../services/student_directory_service.dart';
import '../../theme/app_theme.dart';

class CreateSubjectPage extends StatefulWidget {
  const CreateSubjectPage({super.key});

  @override
  State<CreateSubjectPage> createState() => _CreateSubjectPageState();
}

class _CreateSubjectPageState extends State<CreateSubjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _profController = TextEditingController();
  final _studentSearchController = TextEditingController();

  String _selectedCourse = 'BCA';
  int _selectedSemester = 1;
  final Set<String> _selectedStudentIds = {};
  String _studentSearchQuery = '';

  List<Student> _availableStudents = [];
  bool _isLoadingStudents = false;

  // Geofencing Controls
  bool _geofenceEnabled = false;
  double _targetLatitude = LocationService.defaultCcsaLatitude;
  double _targetLongitude = LocationService.defaultCcsaLongitude;
  double _radiusMeters = 80.0;
  bool _isAcquiringGps = false;

  // Past Physical Register Attendance Baseline (Item 2)
  bool _enablePastAttendance = false;
  PastAttendanceCsvResult? _importedCsvResult;
  String _rawImportedCsv = '';

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    _profController.text = user?.name ?? 'Dr. Rizwan Rehman';
    _loadStudentsForFilter();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _profController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentsForFilter() async {
    setState(() => _isLoadingStudents = true);

    List<Student> mergedStudents = [];
    final Map<String, Student> deduplicated = {};

    try {
      // 1. Fetch live registered students from Hostinger MySQL API
      final onlineStudents = await ApiService.instance.getRegisteredStudents(
        course: _selectedCourse,
        semester: _selectedSemester,
      );

      for (final std in onlineStudents) {
        deduplicated[std.id] = std;
        try {
          await DatabaseHelper.instance.insertStudent(std);
        } catch (_) {}
      }

      // 2. Fetch full DU Proxy Student Directory
      final directoryStudents = StudentDirectoryService.instance.searchStudents(
        '',
        course: _selectedCourse,
        semester: _selectedSemester,
      );

      for (int i = 0; i < directoryStudents.length; i++) {
        final dirStd = directoryStudents[i];
        final rollStr = (i + 1).toString();
        final stdId = 'du_${dirStd.course}_${dirStd.semester}_$rollStr'.toLowerCase();
        if (!deduplicated.containsKey(stdId) &&
            !deduplicated.values.any((s) => s.name.toLowerCase() == dirStd.name.toLowerCase())) {
          deduplicated[stdId] = Student(
            id: stdId,
            name: dirStd.name,
            classRollNo: rollStr,
            duExamRollNo: rollStr,
            course: dirStd.course,
            semester: dirStd.semester,
          );
        }
      }

      mergedStudents = deduplicated.values.toList();
      mergedStudents.sort((a, b) {
        final aNum = int.tryParse(a.classRollNo.replaceAll(RegExp(r'[^0-9]'), ''));
        final bNum = int.tryParse(b.classRollNo.replaceAll(RegExp(r'[^0-9]'), ''));
        if (aNum != null && bNum != null) return aNum.compareTo(bNum);
        return a.name.compareTo(b.name);
      });
    } catch (e) {
      debugPrint('Error loading students for filter: $e');
    } finally {
      if (mounted) {
        setState(() {
          _availableStudents = mergedStudents;
          _isLoadingStudents = false;
          _selectedStudentIds.clear();
          for (var s in mergedStudents) {
            _selectedStudentIds.add(s.id);
          }
        });
      }
    }
  }

  void _openCsvImportModal() {
    AppTheme.triggerLightHaptic();
    final textController = TextEditingController(text: _rawImportedCsv);
    PastAttendanceCsvResult? previewResult = _importedCsvResult;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.90,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.royalNavy.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.fileSpreadsheet, color: AppTheme.royalNavy, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Import Past Attendance CSV',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16.5, color: AppTheme.royalNavy),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(bCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Supported Column Names Guide
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.info, size: 14, color: AppTheme.royalNavy),
                          const SizedBox(width: 6),
                          Text(
                            'Accepted CSV Columns & Structure (Auto-Matched):',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppTheme.royalNavy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• Roll Number Column: Roll No, Roll, Class Roll, Roll Number, ID, Sl No\n'
                        '• Student Name Column: Student Name, Name, Full Name (optional)\n'
                        '• Attended Count: Classes Attended, Attended, Present, Total Attended\n'
                        '• Total Classes: Classes Held, Total Classes, Total Held (optional)\n'
                        '• Date Matrix: Columns with dates (01/08/2026, 05/08/2026...) with P / A',
                        style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textSecondary, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Template Fast-Paste Chips
                Row(
                  children: [
                    Text('Load Sample: ', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(width: 6),
                    ActionChip(
                      label: const Text('Summary Format', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        textController.text = PastAttendanceCsvService.sampleCsvSummary;
                        final res = PastAttendanceCsvService.instance.parseCsvContent(textController.text);
                        setModalState(() => previewResult = res);
                      },
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      label: const Text('Simple (Roll, Count)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        textController.text = PastAttendanceCsvService.sampleCsvSimple;
                        final res = PastAttendanceCsvService.instance.parseCsvContent(textController.text);
                        setModalState(() => previewResult = res);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // CSV Text Input Area
                Expanded(
                  child: TextField(
                    controller: textController,
                    maxLines: null,
                    expands: true,
                    style: GoogleFonts.sourceCodePro(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Paste CSV contents here...\n\nRoll No, Student Name, Classes Held, Classes Attended\n1, Abhigyan Konwar, 12, 11\n2, Abhipran Subadar, 12, 12',
                      filled: true,
                      fillColor: AppTheme.bgLight,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                    ),
                    onChanged: (val) {
                      final res = PastAttendanceCsvService.instance.parseCsvContent(val);
                      setModalState(() => previewResult = res);
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Parse Status Banner
                if (previewResult != null && previewResult!.success)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldGreenBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.checkCircle2, color: AppTheme.emeraldGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Parsed ${previewResult!.studentBaselines.length} students • Total ${previewResult!.totalClassesHeld} Classes Held',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF047857)),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (previewResult != null && !previewResult!.success && textController.text.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.crimsonRoseBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.crimsonRose.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.alertCircle, color: AppTheme.crimsonRose, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            previewResult!.errorMessage ?? 'Invalid CSV',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.crimsonRose),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Apply Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (previewResult != null && previewResult!.success && previewResult!.studentBaselines.isNotEmpty)
                        ? () {
                            setState(() {
                              _importedCsvResult = previewResult;
                              _rawImportedCsv = textController.text;
                            });
                            Navigator.pop(bCtx);
                            AppTheme.triggerSuccessHaptic();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Imported past attendance for ${previewResult!.studentBaselines.length} students across ${previewResult!.totalClassesHeld} classes!'),
                                backgroundColor: AppTheme.emeraldGreen,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.royalNavy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(LucideIcons.check, size: 18),
                    label: Text(
                      previewResult != null && previewResult!.success
                          ? 'Apply ${previewResult!.studentBaselines.length} Student Records'
                          : 'Paste or Upload CSV to Apply',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _captureCurrentLocation() async {
    setState(() => _isAcquiringGps = true);
    AppTheme.triggerLightHaptic();

    final pos = await LocationService.instance.getCurrentPosition();
    if (mounted) {
      setState(() {
        _isAcquiringGps = false;
        if (pos != null) {
          _targetLatitude = pos.latitude;
          _targetLongitude = pos.longitude;
          AppTheme.triggerSuccessHaptic();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GPS Set: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}'),
              backgroundColor: AppTheme.emeraldGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          _targetLatitude = LocationService.defaultCcsaLatitude;
          _targetLongitude = LocationService.defaultCcsaLongitude;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS fix unavailable. Using default CCSA Campus coordinates.'),
              backgroundColor: AppTheme.amberWarning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  Future<void> _handleCreateSubject() async {
    if (!_formKey.currentState!.validate()) {
      AppTheme.triggerErrorHaptic();
      return;
    }

    if (_selectedStudentIds.isEmpty) {
      AppTheme.triggerErrorHaptic();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 student to enroll in this subject.'),
          backgroundColor: AppTheme.crimsonRose,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = AuthService.instance.currentUser;
    final teacherEmail = user?.email ?? 'faculty@ccsa.du.ac.in';
    final subjectId = const Uuid().v4();

    final subject = Subject(
      id: subjectId,
      name: _nameController.text.trim(),
      code: _codeController.text.trim().toUpperCase(),
      professorName: _profController.text.trim(),
      course: _selectedCourse,
      semester: _selectedSemester,
      batchType: 'whole',
      teacherEmail: teacherEmail,
      enrolledStudentIds: _selectedStudentIds.toList(),
      geofenceEnabled: _geofenceEnabled,
      latitude: _targetLatitude,
      longitude: _targetLongitude,
      radiusMeters: _radiusMeters,
      createdAt: DateTime.now(),
    );

    // Save to local SQLite & Hostinger MySQL Cloud Database
    try {
      await DatabaseHelper.instance.insertSubject(subject);
    } catch (_) {}

    await ApiService.instance.syncSubject(subject);

    // Generate Past Baseline Attendance Sessions from pure CSV if imported
    int pastSessionsCreated = 0;
    if (_enablePastAttendance && _importedCsvResult != null && _importedCsvResult!.success) {
      final totalPastHeld = _importedCsvResult!.totalClassesHeld;
      final baselines = _importedCsvResult!.studentBaselines;
      final enrolledStudents = _availableStudents.where((s) => _selectedStudentIds.contains(s.id)).toList();

      if (totalPastHeld > 0) {
        for (int sessionIndex = 1; sessionIndex <= totalPastHeld; sessionIndex++) {
          final pastSessionId = const Uuid().v4();
          final sessionDate = DateTime.now().subtract(Duration(days: (totalPastHeld - sessionIndex + 1) * 2));

          int sessionPresentCount = 0;
          final List<AttendanceRecord> records = [];

          for (final student in enrolledStudents) {
            final match = baselines.firstWhere(
              (b) => b.rollNo.toLowerCase() == student.classRollNo.toLowerCase() ||
                     (b.name.isNotEmpty && student.name.toLowerCase().contains(b.name.toLowerCase())),
              orElse: () => ParsedStudentBaseline(rollNo: student.classRollNo, name: student.name, attendedClasses: totalPastHeld, totalClasses: totalPastHeld),
            );

            final bool isPresentThisSession = sessionIndex <= match.attendedClasses;
            if (isPresentThisSession) sessionPresentCount++;

            records.add(AttendanceRecord(
              id: const Uuid().v4(),
              sessionId: pastSessionId,
              studentId: student.id,
              studentRollNo: student.classRollNo,
              studentName: student.name,
              status: isPresentThisSession ? 'present' : 'absent',
              markedBy: 'csv_import',
            ));
          }

          final pastSession = AttendanceSession(
            id: pastSessionId,
            subjectId: subject.id,
            subjectCode: subject.code,
            subjectName: subject.name,
            teacherEmail: teacherEmail,
            sessionDate: sessionDate,
            totalPresent: sessionPresentCount,
            totalEnrolled: enrolledStudents.length,
            isLab: false,
          );

          try {
            await DatabaseHelper.instance.insertAttendanceSession(pastSession, records);
          } catch (_) {}

          await ApiService.instance.syncAttendanceSession(pastSession, records);
          pastSessionsCreated++;
        }
      }
    }

    AppTheme.triggerSuccessHaptic();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pastSessionsCreated > 0
                ? 'Subject "${subject.code}" created with $pastSessionsCreated historical attendance sessions recorded from CSV!'
                : 'Subject "${subject.code} - ${subject.name}" created successfully!',
          ),
          backgroundColor: AppTheme.emeraldGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _selectAllStudents() {
    AppTheme.triggerLightHaptic();
    setState(() {
      _selectedStudentIds.addAll(_availableStudents.map((s) => s.id));
    });
  }

  void _clearSelectedStudents() {
    AppTheme.triggerLightHaptic();
    setState(() {
      _selectedStudentIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _availableStudents.where((s) {
      if (_studentSearchQuery.isEmpty) return true;
      final q = _studentSearchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) || s.classRollNo.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(
          'Create Subject',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Basic Subject Details
                  _buildSectionHeader('Subject Details', LucideIcons.bookOpen),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.roundedRadius,
                      border: Border.all(color: AppTheme.borderLight, width: 1.2),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration(
                            label: 'Subject Name',
                            hint: 'e.g. Data Structures & Algorithms',
                            prefixIcon: LucideIcons.fileText,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Enter subject name' : null,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _codeController,
                                decoration: _inputDecoration(
                                  label: 'Subject Code',
                                  hint: 'e.g. BCA 301',
                                  prefixIcon: LucideIcons.hash,
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Enter code' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _profController,
                                decoration: _inputDecoration(
                                  label: 'Teacher Name',
                                  hint: 'Faculty in charge',
                                  prefixIcon: LucideIcons.user,
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Enter faculty name' : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Program & Semester
                  _buildSectionHeader('Academic Program & Semester', LucideIcons.layers),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.roundedRadius,
                      border: Border.all(color: AppTheme.borderLight, width: 1.2),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Program', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.royalNavy)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedCourse,
                                isExpanded: true,
                                decoration: _inputDecoration(prefixIcon: LucideIcons.bookOpen),
                                items: const [
                                  DropdownMenuItem(value: 'BCA', child: Text('BCA')),
                                  DropdownMenuItem(value: 'MCA', child: Text('MCA')),
                                  DropdownMenuItem(value: 'PGDCA', child: Text('PGDCA')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedCourse = val;
                                      _loadStudentsForFilter();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Semester', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.royalNavy)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                value: _selectedSemester,
                                isExpanded: true,
                                decoration: _inputDecoration(prefixIcon: LucideIcons.layers),
                                items: List.generate(6, (i) => i + 1).map((s) {
                                  return DropdownMenuItem(value: s, child: Text('Semester $s'));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedSemester = val;
                                      _loadStudentsForFilter();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Past Physical Register Attendance Import (Pure CSV based)
                  _buildSectionHeader('Past Register Attendance (Import CSV)', LucideIcons.fileSpreadsheet),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.roundedRadius,
                      border: Border.all(
                        color: _enablePastAttendance ? AppTheme.royalNavy : AppTheme.borderLight,
                        width: _enablePastAttendance ? 1.5 : 1.2,
                      ),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Import Past Offline Attendance from CSV',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.royalNavy),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Initialize classes already held in the physical register via CSV.',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _enablePastAttendance,
                              activeColor: AppTheme.royalNavy,
                              onChanged: (val) => setState(() => _enablePastAttendance = val),
                            ),
                          ],
                        ),
                        if (_enablePastAttendance) ...[
                          const Divider(height: 24, color: AppTheme.borderSubtle),

                          if (_importedCsvResult != null && _importedCsvResult!.success) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.emeraldGreenBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.checkCircle2, color: AppTheme.emeraldGreen, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'CSV Baseline Loaded Successfully',
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13.5, color: const Color(0xFF047857)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '• Total Historical Classes: ${_importedCsvResult!.totalClassesHeld}\n• Student Records Matched: ${_importedCsvResult!.studentBaselines.length}',
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF065F46), height: 1.4),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.royalNavy,
                                          side: const BorderSide(color: AppTheme.royalNavy),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(LucideIcons.edit3, size: 14),
                                        label: const Text('Edit / Re-import CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                        onPressed: _openCsvImportModal,
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        child: const Text('Clear', style: TextStyle(color: AppTheme.crimsonRose, fontSize: 12, fontWeight: FontWeight.w600)),
                                        onPressed: () => setState(() {
                                          _importedCsvResult = null;
                                          _rawImportedCsv = '';
                                        }),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.bgLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(LucideIcons.fileSpreadsheet, size: 36, color: AppTheme.royalNavy),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No CSV file or data imported yet',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.royalNavy),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Click below to paste or import your physical register CSV sheet.',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.royalNavy,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(LucideIcons.uploadCloud, size: 16),
                                    label: const Text('Paste / Import CSV Sheet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    onPressed: _openCsvImportModal,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Classroom GPS Geofencing (Optional)
                  _buildSectionHeader('Classroom GPS Geofencing (Optional)', LucideIcons.mapPin),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.roundedRadius,
                      border: Border.all(
                        color: _geofenceEnabled ? AppTheme.electricTeal : AppTheme.borderLight,
                        width: _geofenceEnabled ? 1.5 : 1.2,
                      ),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enforce GPS Geofence',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.royalNavy),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Require students to be physically near classroom.',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _geofenceEnabled,
                              activeColor: AppTheme.electricTeal,
                              onChanged: (val) => setState(() => _geofenceEnabled = val),
                            ),
                          ],
                        ),
                        if (_geofenceEnabled) ...[
                          const Divider(height: 24, color: AppTheme.borderSubtle),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Allowed Radius', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                                  Text('${_radiusMeters.toInt()} meters', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.electricTeal)),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _isAcquiringGps ? null : _captureCurrentLocation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.electricTealBg,
                                  foregroundColor: AppTheme.electricTeal,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: _isAcquiringGps
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.electricTeal))
                                    : const Icon(LucideIcons.locateFixed, size: 16),
                                label: Text(_isAcquiringGps ? 'Locating...' : 'Set GPS', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                              ),
                            ],
                          ),
                          Slider(
                            value: _radiusMeters,
                            min: 20.0,
                            max: 200.0,
                            divisions: 18,
                            activeColor: AppTheme.electricTeal,
                            label: '${_radiusMeters.toInt()}m',
                            onChanged: (v) => setState(() => _radiusMeters = v),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Student Enrollment Directory
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildSectionHeader('Enrolled Students (${_selectedStudentIds.length}/${_availableStudents.length})', LucideIcons.users),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: _selectAllStudents,
                            child: const Text('Select All', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.royalNavy)),
                          ),
                          TextButton(
                            onPressed: _clearSelectedStudents,
                            child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.crimsonRose)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.roundedRadius,
                      border: Border.all(color: AppTheme.borderLight, width: 1.2),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextField(
                            controller: _studentSearchController,
                            decoration: InputDecoration(
                              hintText: 'Search students by name or roll no...',
                              prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppTheme.textSecondary),
                              filled: true,
                              fillColor: AppTheme.bgLight,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                            onChanged: (v) => setState(() => _studentSearchQuery = v),
                          ),
                        ),
                        const Divider(height: 1, color: AppTheme.borderSubtle),

                        if (_isLoadingStudents)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator(color: AppTheme.royalNavy)),
                          )
                        else if (filteredList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No students found for $_selectedCourse Semester $_selectedSemester.',
                                style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
                            itemBuilder: (context, index) {
                              final s = filteredList[index];
                              final isSelected = _selectedStudentIds.contains(s.id);
                              final rollDisplay = s.classRollNo.isNotEmpty ? 'Roll ${s.classRollNo}' : 'Roll ${index + 1}';

                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: AppTheme.royalNavy,
                                controlAffinity: ListTileControlAffinity.trailing,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedStudentIds.add(s.id);
                                    } else {
                                      _selectedStudentIds.remove(s.id);
                                    }
                                  });
                                },
                                title: Text(
                                  '$rollDisplay • ${s.name}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 13.5,
                                    color: isSelected ? AppTheme.royalNavy : AppTheme.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${s.course} Semester ${s.semester}',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleCreateSubject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.royalNavy,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: Text(
                        'Create Subject (${_selectedStudentIds.length} Students)',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.royalNavy),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? label, String? hint, IconData? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 17, color: AppTheme.royalNavy) : null,
      filled: true,
      fillColor: AppTheme.bgLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.royalNavy, width: 1.5)),
    );
  }
}
