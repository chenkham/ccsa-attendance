import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'db/database_helper.dart';
import 'pages/auth/login_page.dart';
import 'pages/faculty/faculty_dashboard_page.dart';
import 'pages/student/student_dashboard_page.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Multiplatform Database Initialization
  try {
    if (kIsWeb) {
      databaseFactory = createDatabaseFactoryFfiWeb(
        options: SqfliteFfiWebOptions(inMemory: true),
      );
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  } catch (e) {
    debugPrint('Database factory initialization note: $e');
  }

  // Transparent status bar with dark icons
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppTheme.bgLight,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // Safe background initialization
  try {
    if (!kIsWeb) {
      await DatabaseHelper.instance.database;
    }
    await ApiService.instance.initialize();
    await AuthService.instance.initialize();
  } catch (e) {
    debugPrint('Startup background services notice: $e');
  }

  runApp(const CCSASmartAttendanceApp());
}

class CCSASmartAttendanceApp extends StatelessWidget {
  const CCSASmartAttendanceApp({super.key});

  Widget _getInitialScreen() {
    if (AuthService.instance.isLoggedIn) {
      return AuthService.instance.isFaculty
          ? const FacultyDashboardPage()
          : const StudentDashboardPage();
    }
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CCSAAS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: _getInitialScreen(),
    );
  }
}
