import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../db/database_helper.dart';
import '../models/attendance_session.dart';
import '../models/student.dart';
import '../models/subject.dart';
import '../theme/app_theme.dart';
import 'api_service.dart';
import 'export_helper.dart';

class CsvExportService {
  static final CsvExportService instance = CsvExportService._init();
  CsvExportService._init();

  /// Shows UI dialog to choose between CSV and Excel format
  Future<void> showExportDialog({
    required BuildContext context,
    required Subject subject,
  }) async {
    AppTheme.triggerLightHaptic();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Export Attendance Sheet',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: AppTheme.royalNavy,
              ),
            ),
            Text(
              '${subject.name} (${subject.code})',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            // Option 1: CSV (.csv)
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderLight),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.royalNavy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.fileText, color: AppTheme.royalNavy, size: 20),
              ),
              title: Text('Export as CSV (.csv)', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text('Universal comma-separated text format', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
              trailing: const Icon(LucideIcons.downloadCloud, size: 18, color: AppTheme.royalNavy),
              onTap: () async {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating CSV sheet...'), behavior: SnackBarBehavior.floating),
                );
                await exportSubjectCsv(subject);
              },
            ),
            const SizedBox(height: 12),

            // Option 2: Excel (.xls)
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderLight),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldGreenBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.fileSpreadsheet, color: Color(0xFF047857), size: 20),
              ),
              title: Text('Export as Excel (.xls)', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text('Formatted spreadsheet for MS Excel & Google Sheets', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
              trailing: const Icon(LucideIcons.downloadCloud, size: 18, color: Color(0xFF047857)),
              onTap: () async {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating Excel spreadsheet...'), behavior: SnackBarBehavior.floating),
                );
                await exportSubjectExcel(subject);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Exports Subject Attendance as standard CSV
  Future<bool> exportSubjectCsv(Subject subject) async {
    final data = await _fetchSubjectData(subject);
    final sessions = data['sessions'] as List<AttendanceSession>;
    final students = data['students'] as List<Student>;

    final DateFormat dateFmt = DateFormat('dd/MM/yy');
    final DateFormat fullDateFmt = DateFormat('yyyy-MM-dd HH:mm');

    int totalDeliveredHours = 0;
    for (var s in sessions) {
      totalDeliveredHours += s.durationHours;
    }

    List<List<dynamic>> rows = [];
    rows.add(['CENTRE FOR COMPUTER SCIENCE AND APPLICATIONS (CCSA)']);
    rows.add(['DIBRUGARH UNIVERSITY, ASSAM - 786004']);
    rows.add(['OFFICIAL ATTENDANCE FORENSIC RECORD']);
    rows.add(['Subject Code:', subject.code, 'Subject Name:', subject.name]);
    rows.add(['Course & Sem:', '${subject.course} ${subject.semesterDisplay}', 'Batch:', subject.batchLabel]);
    rows.add(['Faculty / In-Charge:', subject.professorName]);
    rows.add(['Report Generated:', fullDateFmt.format(DateTime.now())]);
    rows.add([]);

    List<dynamic> headerRow = ['Sl No', 'Class Roll No', 'DU Exam Roll No', 'Student Name'];
    for (var s in sessions) {
      headerRow.add('${dateFmt.format(s.sessionDate)} ${s.isLab ? "Lab(2h)" : "Th(1h)"}');
    }
    headerRow.addAll(['Total Classes', 'Delivered (Hrs)', 'Attended (Hrs)', 'Attendance %', 'Eligibility Status']);
    rows.add(headerRow);

    for (int i = 0; i < students.length; i++) {
      final student = students[i];
      int attendedHours = 0;
      List<dynamic> studentRow = [(i + 1).toString(), student.classRollNo, student.duExamRollNo, student.name];

      for (var s in sessions) {
        final isPresent = s.records.any((r) =>
            (r.studentId == student.id || r.studentRollNo == student.classRollNo) && r.isPresent);
        if (isPresent) {
          attendedHours += s.durationHours;
          studentRow.add('P');
        } else {
          studentRow.add('A');
        }
      }

      final double percentage = totalDeliveredHours > 0 ? (attendedHours / totalDeliveredHours) * 100.0 : 100.0;
      final String eligibility = percentage >= 75.0 ? 'ELIGIBLE' : 'SHORTAGE (<75%)';

      studentRow.addAll([
        sessions.length.toString(),
        totalDeliveredHours.toString(),
        attendedHours.toString(),
        '${percentage.toStringAsFixed(1)}%',
        eligibility,
      ]);
      rows.add(studentRow);
    }

    final String csvContent = const ListToCsvConverter().convert(rows);
    final cleanCode = subject.code.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'CCSA_Attendance_${cleanCode}_${DateFormat("yyyyMMdd").format(DateTime.now())}.csv';

    return await AppExportHelper.saveOrShareFile(
      fileName: fileName,
      fileContent: csvContent,
      mimeType: 'text/csv',
      shareSubject: 'Attendance Record - ${subject.code} (${subject.name})',
    );
  }

  /// Exports Subject Attendance as formatted HTML-based Excel (.xls) spreadsheet
  Future<bool> exportSubjectExcel(Subject subject) async {
    final data = await _fetchSubjectData(subject);
    final sessions = data['sessions'] as List<AttendanceSession>;
    final students = data['students'] as List<Student>;

    final DateFormat dateFmt = DateFormat('dd/MM/yy');
    final DateFormat fullDateFmt = DateFormat('yyyy-MM-dd HH:mm');

    int totalDeliveredHours = 0;
    for (var s in sessions) {
      totalDeliveredHours += s.durationHours;
    }

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">');
    buffer.writeln('<head><meta http-equiv="Content-Type" content="text/html; charset=utf-8" />');
    buffer.writeln('<style>');
    buffer.writeln('table { border-collapse: collapse; font-family: Arial, sans-serif; }');
    buffer.writeln('th, td { border: 1px solid #d1d5db; padding: 6px 10px; font-size: 11pt; text-align: left; }');
    buffer.writeln('th { background-color: #0f172a; color: #ffffff; font-weight: bold; }');
    buffer.writeln('.meta-title { font-size: 14pt; font-weight: bold; color: #0f172a; }');
    buffer.writeln('.eligible { background-color: #d1fae5; color: #047857; font-weight: bold; text-align: center; }');
    buffer.writeln('.shortage { background-color: #fee2e2; color: #b91c1c; font-weight: bold; text-align: center; }');
    buffer.writeln('.present { color: #047857; font-weight: bold; text-align: center; }');
    buffer.writeln('.absent { color: #b91c1c; font-weight: bold; text-align: center; }');
    buffer.writeln('</style></head><body>');

    buffer.writeln('<table>');
    buffer.writeln('<tr><td colspan="8" class="meta-title">CENTRE FOR COMPUTER SCIENCE AND APPLICATIONS (CCSA)</td></tr>');
    buffer.writeln('<tr><td colspan="8">DIBRUGARH UNIVERSITY, ASSAM - 786004</td></tr>');
    buffer.writeln('<tr><td colspan="8"><b>OFFICIAL ATTENDANCE FORENSIC RECORD</b></td></tr>');
    buffer.writeln('<tr><td><b>Subject:</b></td><td colspan="3">${subject.name} (${subject.code})</td><td><b>Course & Sem:</b></td><td colspan="3">${subject.course} ${subject.semesterDisplay}</td></tr>');
    buffer.writeln('<tr><td><b>Faculty:</b></td><td colspan="3">${subject.professorName}</td><td><b>Generated:</b></td><td colspan="3">${fullDateFmt.format(DateTime.now())}</td></tr>');
    buffer.writeln('<tr><td colspan="8"></td></tr>');

    buffer.writeln('<tr>');
    buffer.writeln('<th>Sl No</th><th>Class Roll No</th><th>DU Exam Roll No</th><th>Student Name</th>');
    for (var s in sessions) {
      buffer.writeln('<th>${dateFmt.format(s.sessionDate)}<br/><small>${s.isLab ? "Lab(2h)" : "Th(1h)"}</small></th>');
    }
    buffer.writeln('<th>Total Classes</th><th>Delivered (Hrs)</th><th>Attended (Hrs)</th><th>Attendance %</th><th>Eligibility</th>');
    buffer.writeln('</tr>');

    for (int i = 0; i < students.length; i++) {
      final student = students[i];
      int attendedHours = 0;
      buffer.writeln('<tr>');
      buffer.writeln('<td>${i + 1}</td><td>${student.classRollNo}</td><td>${student.duExamRollNo}</td><td>${student.name}</td>');

      for (var s in sessions) {
        final isPresent = s.records.any((r) =>
            (r.studentId == student.id || r.studentRollNo == student.classRollNo) && r.isPresent);
        if (isPresent) {
          attendedHours += s.durationHours;
          buffer.writeln('<td class="present">P</td>');
        } else {
          buffer.writeln('<td class="absent">A</td>');
        }
      }

      final double percentage = totalDeliveredHours > 0 ? (attendedHours / totalDeliveredHours) * 100.0 : 100.0;
      final bool isEligible = percentage >= 75.0;

      buffer.writeln('<td>${sessions.length}</td>');
      buffer.writeln('<td>${totalDeliveredHours}</td>');
      buffer.writeln('<td>${attendedHours}</td>');
      buffer.writeln('<td>${percentage.toStringAsFixed(1)}%</td>');
      buffer.writeln('<td class="${isEligible ? "eligible" : "shortage"}">${isEligible ? "ELIGIBLE" : "SHORTAGE"}</td>');
      buffer.writeln('</tr>');
    }

    buffer.writeln('</table></body></html>');

    final cleanCode = subject.code.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'CCSA_Attendance_${cleanCode}_${DateFormat("yyyyMMdd").format(DateTime.now())}.xls';

    return await AppExportHelper.saveOrShareFile(
      fileName: fileName,
      fileContent: buffer.toString(),
      mimeType: 'application/vnd.ms-excel',
      shareSubject: 'Attendance Spreadsheet - ${subject.code} (${subject.name})',
    );
  }

  Future<Map<String, dynamic>> _fetchSubjectData(Subject subject) async {
    List<AttendanceSession> sessions = [];
    List<Student> students = [];

    try {
      sessions = await DatabaseHelper.instance.getSessionsForSubject(subject.id);
      students = await DatabaseHelper.instance.getStudentsForSubject(subject.id);
    } catch (_) {}

    if (sessions.isEmpty || students.isEmpty) {
      final cloudSess = await ApiService.instance.getFacultySessions(subjectId: subject.id);
      if (cloudSess.isNotEmpty) sessions = cloudSess;

      final cloudStds = await ApiService.instance.getRegisteredStudents(
        course: subject.course,
        semester: subject.semester,
      );
      if (cloudStds.isNotEmpty) students = cloudStds;
    }

    sessions.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    return {'sessions': sessions, 'students': students};
  }
}
