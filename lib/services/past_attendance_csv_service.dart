import 'package:csv/csv.dart';
import '../models/student.dart';

class ParsedStudentBaseline {
  final String rollNo;
  final String name;
  final int attendedClasses;
  final int totalClasses;

  const ParsedStudentBaseline({
    required this.rollNo,
    required this.name,
    required this.attendedClasses,
    required this.totalClasses,
  });

  double get percentage => totalClasses > 0 ? (attendedClasses / totalClasses) * 100.0 : 100.0;
}

class PastAttendanceCsvResult {
  final bool success;
  final String? errorMessage;
  final int totalClassesHeld;
  final List<ParsedStudentBaseline> studentBaselines;
  final List<String> detectedColumns;
  final String detectedFormatDescription;

  const PastAttendanceCsvResult({
    required this.success,
    this.errorMessage,
    this.totalClassesHeld = 0,
    this.studentBaselines = const [],
    this.detectedColumns = const [],
    this.detectedFormatDescription = '',
  });
}

class PastAttendanceCsvService {
  static final PastAttendanceCsvService instance = PastAttendanceCsvService._init();
  PastAttendanceCsvService._init();

  static const String sampleCsvSummary = "Roll No, Student Name, Classes Held, Classes Attended\n1, Abhigyan Konwar, 12, 11\n2, Abhipran Subadar, 12, 12\n3, Abinash Khatowal, 12, 10";

  static const String sampleCsvSimple = "Roll No, Attended\n1, 10\n2, 12\n3, 8\n4, 11";

  static const String sampleCsvMatrix = "Roll No, Name, 01/08/2026, 05/08/2026, 08/08/2026\n1, Abhigyan Konwar, P, P, P\n2, Abhipran Subadar, P, P, A";

  /// Robust parser for past register attendance CSV with flexible column matching
  PastAttendanceCsvResult parseCsvContent(String rawCsv, {List<Student> enrolledStudents = const []}) {
    if (rawCsv.trim().isEmpty) {
      return const PastAttendanceCsvResult(
        success: false,
        errorMessage: 'CSV content is empty. Please paste or upload CSV data.',
      );
    }

    try {
      final rows = const CsvToListConverter(shouldParseNumbers: false).convert(rawCsv.trim());
      if (rows.isEmpty) {
        return const PastAttendanceCsvResult(
          success: false,
          errorMessage: 'No data rows found in the CSV.',
        );
      }

      final headerRow = rows.first.map((e) => e.toString().trim()).toList();
      final dataRows = rows.skip(1).where((r) => r.isNotEmpty && r.any((cell) => cell.toString().trim().isNotEmpty)).toList();

      if (dataRows.isEmpty) {
        return const PastAttendanceCsvResult(
          success: false,
          errorMessage: 'CSV only contains headers but no student rows.',
        );
      }

      int rollIdx = -1;
      int nameIdx = -1;
      int attendedIdx = -1;
      int totalIdx = -1;
      List<int> dateColIndices = [];

      for (int i = 0; i < headerRow.length; i++) {
        final col = headerRow[i].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (rollIdx == -1 && (col.contains('roll') || col == 'slno' || col == 'id' || col == 'rollno')) {
          rollIdx = i;
        } else if (nameIdx == -1 && (col.contains('name') || col.contains('student'))) {
          nameIdx = i;
        } else if (attendedIdx == -1 && (col.contains('attended') || col.contains('present') || col == 'att')) {
          attendedIdx = i;
        } else if (totalIdx == -1 && (col.contains('held') || col.contains('total') || col == 'classes' || col == 'lectures')) {
          totalIdx = i;
        } else if (headerRow[i].contains('/') || headerRow[i].contains('-') || RegExp(r'[0-9]').hasMatch(headerRow[i])) {
          dateColIndices.add(i);
        }
      }

      // Default indices if no headers matched
      if (rollIdx == -1 && headerRow.length >= 1) rollIdx = 0;
      if (attendedIdx == -1 && headerRow.length >= 2 && dateColIndices.isEmpty) {
        attendedIdx = nameIdx != 1 ? 1 : (headerRow.length >= 3 ? 2 : 1);
      }

      int maxTotalClasses = 0;
      final List<ParsedStudentBaseline> baselines = [];

      // Check if Date Matrix format
      if (dateColIndices.length >= 2) {
        final totalSessions = dateColIndices.length;
        maxTotalClasses = totalSessions;

        for (final row in dataRows) {
          final roll = rollIdx >= 0 && rollIdx < row.length ? row[rollIdx].toString().trim() : '';
          final name = nameIdx >= 0 && nameIdx < row.length ? row[nameIdx].toString().trim() : '';
          int attendedCount = 0;

          for (final dIdx in dateColIndices) {
            if (dIdx < row.length) {
              final val = row[dIdx].toString().trim().toUpperCase();
              if (val == 'P' || val == '1' || val == 'PRESENT' || val == 'YES' || val == 'TRUE') {
                attendedCount++;
              }
            }
          }

          baselines.add(ParsedStudentBaseline(
            rollNo: roll,
            name: name,
            attendedClasses: attendedCount,
            totalClasses: totalSessions,
          ));
        }

        return PastAttendanceCsvResult(
          success: true,
          totalClassesHeld: totalSessions,
          studentBaselines: baselines,
          detectedColumns: headerRow,
          detectedFormatDescription: 'Date Matrix Format ($totalSessions date columns detected)',
        );
      }

      // Summary Count Format
      for (final row in dataRows) {
        final roll = rollIdx >= 0 && rollIdx < row.length ? row[rollIdx].toString().trim() : '';
        final name = nameIdx >= 0 && nameIdx < row.length ? row[nameIdx].toString().trim() : '';

        int attendedCount = 0;
        if (attendedIdx >= 0 && attendedIdx < row.length) {
          attendedCount = int.tryParse(row[attendedIdx].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }

        int totalCount = 0;
        if (totalIdx >= 0 && totalIdx < row.length) {
          totalCount = int.tryParse(row[totalIdx].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }

        if (totalCount > maxTotalClasses) maxTotalClasses = totalCount;

        baselines.add(ParsedStudentBaseline(
          rollNo: roll,
          name: name,
          attendedClasses: attendedCount,
          totalClasses: totalCount,
        ));
      }

      if (maxTotalClasses == 0) {
        for (var b in baselines) {
          if (b.attendedClasses > maxTotalClasses) maxTotalClasses = b.attendedClasses;
        }
      }

      // Normalize total classes across all students
      final normalizedBaselines = baselines.map((b) {
        return ParsedStudentBaseline(
          rollNo: b.rollNo,
          name: b.name,
          attendedClasses: b.attendedClasses,
          totalClasses: b.totalClasses > 0 ? b.totalClasses : maxTotalClasses,
        );
      }).toList();

      return PastAttendanceCsvResult(
        success: true,
        totalClassesHeld: maxTotalClasses,
        studentBaselines: normalizedBaselines,
        detectedColumns: headerRow,
        detectedFormatDescription: 'Summary Column Format (Roll No & Attended Count matched)',
      );
    } catch (e) {
      return PastAttendanceCsvResult(
        success: false,
        errorMessage: 'CSV Parsing Error: $e',
      );
    }
  }
}
