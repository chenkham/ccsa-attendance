import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/faculty_directory_service.dart';
import '../../services/student_directory_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/doodle_art.dart';
import '../../widgets/micro_interactions.dart';
import '../faculty/faculty_dashboard_page.dart';
import '../student/student_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late final AnimationController _entranceController;

  // Sign In Controllers
  final TextEditingController _signInEmailController = TextEditingController();
  final TextEditingController _signInPasswordController = TextEditingController();
  bool _obscureSignInPassword = true;
  bool _isSigningIn = false;

  // Sign Up Controllers
  String _signUpRole = 'student'; // 'student' | 'faculty'
  CcsaDirectoryStudent? _selectedDirectoryStudent;

  // Faculty Selection
  String _selectedFacultyName = 'Dr. Rizwan Rehman';
  bool _isGuestFaculty = false;
  final TextEditingController _guestFacultyNameController = TextEditingController();

  final TextEditingController _signUpEmailController = TextEditingController();
  final TextEditingController _signUpPasswordController = TextEditingController();
  final TextEditingController _signUpConfirmPasswordController = TextEditingController();
  bool _obscureSignUpPassword = true;
  bool _isSigningUp = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _entranceController = AnimationController(vsync: this, duration: AppTheme.motionSlow);
    _entranceController.forward();
    StudentDirectoryService.instance.fetchLiveDirectory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _entranceController.dispose();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _guestFacultyNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmPasswordController.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? LucideIcons.alertCircle : LucideIcons.checkCircle2,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppTheme.crimsonRose : AppTheme.emeraldGreen,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // -------------------------------------------------------------
  // SIGN IN
  // -------------------------------------------------------------

  Future<void> _handleSignIn() async {
    final email = _signInEmailController.text.trim();
    final password = _signInPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showToast('Please enter both email and password.', isError: true);
      return;
    }

    setState(() => _isSigningIn = true);
    AppTheme.triggerLightHaptic();

    try {
      final res = await AuthService.instance.loginWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      setState(() => _isSigningIn = false);

      if (res['success'] == true) {
        AppTheme.triggerSuccessHaptic();
        final user = AuthService.instance.currentUser;
        if (user?.role == 'faculty') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FacultyDashboardPage()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentDashboardPage()));
        }
      } else {
        AppTheme.triggerErrorHaptic();
        _showToast(res['message'] ?? 'Sign in failed.', isError: true);
      }
    } catch (e) {
      if (mounted) setState(() => _isSigningIn = false);
      _showToast('Login error: $e', isError: true);
    }
  }

  // -------------------------------------------------------------
  // SIGN UP & EMAIL OTP FLOW (Item 1 & 2)
  // -------------------------------------------------------------

  Future<void> _handleSignUp() async {
    String name = '';
    String? course;
    int? semester;

    if (_signUpRole == 'student') {
      if (_selectedDirectoryStudent == null) {
        _showToast('Please select your name from the CCSA Student Directory.', isError: true);
        return;
      }
      name = _selectedDirectoryStudent!.name;
      course = _selectedDirectoryStudent!.course;
      semester = _selectedDirectoryStudent!.semester;
    } else {
      // Faculty Role
      if (_isGuestFaculty) {
        name = _guestFacultyNameController.text.trim();
        if (name.isEmpty) {
          _showToast('Please enter guest faculty name.', isError: true);
          return;
        }
      } else {
        name = _selectedFacultyName;
      }
    }

    final email = _signUpEmailController.text.trim();
    final password = _signUpPasswordController.text;
    final confirmPassword = _signUpConfirmPasswordController.text;

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      _showToast('Please enter a valid email address.', isError: true);
      return;
    }

    if (password.length < 6) {
      _showToast('Password must be at least 6 characters.', isError: true);
      return;
    }

    if (password != confirmPassword) {
      _showToast('Passwords do not match.', isError: true);
      return;
    }

    setState(() => _isSigningUp = true);
    AppTheme.triggerLightHaptic();

    try {
      // 1. Check if an account already exists for this email or student name (Item 1)
      final checkRes = await ApiService.instance.checkUserExists(
        email: email,
        name: name,
        role: _signUpRole,
      );

      if (checkRes['exists'] == true) {
        if (mounted) setState(() => _isSigningUp = false);
        AppTheme.triggerErrorHaptic();
        _showToast(checkRes['message'] ?? 'An account already exists for this student/email. Please sign in.', isError: true);
        return;
      }

      // 2. Dispatch real Hostinger Email OTP via Hostinger SMTP (Item 1)
      final otpRes = await ApiService.instance.sendOtp(
        email: email,
        name: name,
        type: 'signup',
      );

      if (mounted) setState(() => _isSigningUp = false);

      if (otpRes['success'] != true) {
        AppTheme.triggerErrorHaptic();
        _showToast(otpRes['message'] ?? 'Failed to send OTP email.', isError: true);
        return;
      }

      if (!mounted) return;

      _showSignUpOtpDialog(
        name: name,
        email: email,
        password: password,
        course: course,
        semester: semester,
      );
    } catch (e) {
      if (mounted) setState(() => _isSigningUp = false);
      _showToast('Signup error: $e', isError: true);
    }
  }

  void _showSignUpOtpDialog({
    required String name,
    required String email,
    required String password,
    String? course,
    int? semester,
  }) {
    final TextEditingController otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.royalNavy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.mailCheck, color: AppTheme.royalNavy, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Email Verification',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A 6-digit OTP code has been sent to your email inbox:',
                    style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.royalNavy),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sourceCodePro(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4),
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: '• • • • • •',
                      counterText: '',
                      filled: true,
                      fillColor: AppTheme.bgLight,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderLight)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isVerifying ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isVerifying
                    ? null
                    : () async {
                        final enteredOtp = otpController.text.trim();
                        if (enteredOtp.isEmpty) {
                          _showToast('Please enter the 6-digit OTP code.', isError: true);
                          return;
                        }

                        setDialogState(() => isVerifying = true);

                        // 1. Verify against Hostinger MySQL API
                        final verifyRes = await ApiService.instance.verifySignup(
                          email: email,
                          otp: enteredOtp,
                          name: name,
                          password: password,
                          role: _signUpRole,
                          course: course ?? 'BCA',
                          semester: semester ?? 1,
                        );

                        if (verifyRes['success'] != true) {
                          setDialogState(() => isVerifying = false);
                          _showToast(verifyRes['message'] ?? 'Invalid or expired OTP code.', isError: true);
                          return;
                        }

                        // 2. Save into local SQLite database
                        try {
                          final regResult = await AuthService.instance.signup(
                            name: name,
                            email: email,
                            password: password,
                            role: _signUpRole,
                            course: course,
                            semester: semester,
                          );

                          if (context.mounted) {
                            Navigator.pop(ctx);

                            if (regResult['success'] == true) {
                              AppTheme.triggerSuccessHaptic();
                              _showToast('Account Created! Welcome to CCSA Attendance.');
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _signUpRole == 'faculty'
                                      ? const FacultyDashboardPage()
                                      : const StudentDashboardPage(),
                                ),
                              );
                            } else {
                              _showToast(regResult['message'] ?? 'Account setup completed.', isError: false);
                            }
                          }
                        } catch (e) {
                          setDialogState(() => isVerifying = false);
                          _showToast('Local database error: $e', isError: true);
                        }
                      },
                child: isVerifying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify & Create Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // STUDENT DIRECTORY SEARCH BOTTOM SHEET
  // -------------------------------------------------------------

  void _openStudentDirectoryPicker() {
    AppTheme.triggerLightHaptic();
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          final results = StudentDirectoryService.instance.searchStudents(query);

          return Container(
            height: MediaQuery.of(context).size.height * 0.78,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Your Name',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.royalNavy),
                          ),
                          Text(
                            'CCSA Dibrugarh University Registered Directory',
                            style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 20),
                        onPressed: () => Navigator.pop(bCtx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search or type your full name...',
                      prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.bgLight,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderLight)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderLight)),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        query = val.trim();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),

                if (query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedDirectoryStudent = CcsaDirectoryStudent(
                            name: query,
                            course: 'BCA',
                            semester: 1,
                          );
                        });
                        Navigator.pop(bCtx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldGreenBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.emeraldGreenBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.userPlus, size: 16, color: Color(0xFF047857)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Use "$query" as my name',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF047857)),
                              ),
                            ),
                            const Icon(LucideIcons.arrowRight, size: 14, color: Color(0xFF047857)),
                          ],
                        ),
                      ),
                    ),
                  ),

                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.userX, size: 36, color: AppTheme.textSecondary),
                                const SizedBox(height: 8),
                                Text('No directory match found.', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                                const SizedBox(height: 12),
                                if (query.isNotEmpty)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.royalNavy,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    icon: const Icon(LucideIcons.userCheck, size: 16),
                                    label: Text('Use "$query" as My Name'),
                                    onPressed: () {
                                      setState(() {
                                        _selectedDirectoryStudent = CcsaDirectoryStudent(
                                          name: query,
                                          course: 'BCA',
                                          semester: 1,
                                        );
                                      });
                                      Navigator.pop(bCtx);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
                          itemBuilder: (context, index) {
                            final std = results[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 2),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.googleSky,
                                child: Text(
                                  std.name.isNotEmpty ? std.name[0].toUpperCase() : 'S',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                                ),
                              ),
                              title: Text(std.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              subtitle: Text('${std.course} ${std.semesterDisplay}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                              trailing: const Icon(LucideIcons.chevronRight, size: 16, color: AppTheme.textSecondary),
                              onTap: () {
                                setState(() {
                                  _selectedDirectoryStudent = std;
                                });
                                Navigator.pop(bCtx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // FORGOT PASSWORD DIALOG
  // -------------------------------------------------------------

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController otpController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    int currentStep = 1; // 1: Email, 2: OTP Verification, 3: Set New Password
    bool isSubmitting = false;
    String validatedOtp = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          String dialogTitle = 'Reset Password';
          if (currentStep == 2) dialogTitle = 'Verify OTP Code';
          if (currentStep == 3) dialogTitle = 'Set New Password';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: const BoxDecoration(
                    color: AppTheme.electricTealBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    currentStep == 1
                        ? LucideIcons.mail
                        : (currentStep == 2 ? LucideIcons.mailCheck : LucideIcons.keyRound),
                    color: AppTheme.electricTeal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dialogTitle,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step Indicator
                  Row(
                    children: [
                      for (int i = 1; i <= 3; i++) ...[
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: currentStep >= i ? AppTheme.royalNavy : AppTheme.borderLight,
                          ),
                          child: Center(
                            child: Text(
                              '$i',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: currentStep >= i ? Colors.white : AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ),
                        if (i < 3)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: currentStep > i ? AppTheme.royalNavy : AppTheme.borderLight,
                            ),
                          ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (currentStep == 1) ...[
                    Text(
                      'Enter your registered email address. We will send a 6-digit OTP code to your Gmail inbox.',
                      style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Registered Email',
                        prefixIcon: const Icon(LucideIcons.mail, size: 18, color: AppTheme.royalNavy),
                        filled: true,
                        fillColor: AppTheme.bgLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ] else if (currentStep == 2) ...[
                    Text(
                      'Please check your Gmail inbox and enter the 6-digit verification code sent to:',
                      style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emailController.text.trim(),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.royalNavy),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sourceCodePro(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4),
                      maxLength: 6,
                      decoration: InputDecoration(
                        hintText: '• • • • • •',
                        counterText: '',
                        filled: true,
                        fillColor: AppTheme.bgLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'OTP Verified! Please enter your new password below:',
                      style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(LucideIcons.lock, size: 18, color: AppTheme.royalNavy),
                        filled: true,
                        fillColor: AppTheme.bgLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: const Icon(LucideIcons.lock, size: 18, color: AppTheme.royalNavy),
                        filled: true,
                        fillColor: AppTheme.bgLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) {
                          _showToast('Please enter your email.', isError: true);
                          return;
                        }

                        // STEP 1: Send OTP
                        if (currentStep == 1) {
                          setDialogState(() => isSubmitting = true);
                          final otpRes = await ApiService.instance.sendOtp(
                            email: email,
                            name: 'User',
                            type: 'reset',
                          );
                          setDialogState(() => isSubmitting = false);

                          if (otpRes['success'] == true) {
                            AppTheme.triggerLightHaptic();
                            _showToast('Verification code sent to your email.');
                            setDialogState(() => currentStep = 2);
                          } else {
                            AppTheme.triggerErrorHaptic();
                            _showToast(otpRes['message'] ?? 'Failed to send OTP code.', isError: true);
                          }
                        }
                        // STEP 2: Verify OTP
                        else if (currentStep == 2) {
                          final enteredOtp = otpController.text.trim();
                          if (enteredOtp.length < 6) {
                            _showToast('Please enter the complete 6-digit OTP code.', isError: true);
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          final verifyRes = await ApiService.instance.verifyResetOtp(
                            email: email,
                            otp: enteredOtp,
                          );
                          setDialogState(() => isSubmitting = false);

                          if (verifyRes['success'] == true) {
                            AppTheme.triggerSuccessHaptic();
                            validatedOtp = enteredOtp;
                            _showToast('OTP verified! Please set your new password.');
                            setDialogState(() => currentStep = 3);
                          } else {
                            AppTheme.triggerErrorHaptic();
                            _showToast(verifyRes['message'] ?? 'Invalid or expired OTP code.', isError: true);
                          }
                        }
                        // STEP 3: Set New Password
                        else {
                          final newPass = newPasswordController.text;
                          final confirmPass = confirmPasswordController.text;

                          if (newPass.isEmpty || confirmPass.isEmpty) {
                            _showToast('Please fill in both password fields.', isError: true);
                            return;
                          }

                          if (newPass.length < 4) {
                            _showToast('Password must be at least 4 characters long.', isError: true);
                            return;
                          }

                          if (newPass != confirmPass) {
                            _showToast('Passwords do not match. Please recheck.', isError: true);
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          final resetRes = await ApiService.instance.resetPassword(
                            email: email,
                            otp: validatedOtp.isNotEmpty ? validatedOtp : otpController.text.trim(),
                            newPassword: newPass,
                          );
                          setDialogState(() => isSubmitting = false);

                          if (context.mounted) {
                            if (resetRes['success'] == true) {
                              Navigator.pop(ctx);
                              AppTheme.triggerSuccessHaptic();
                              _showToast('Password updated in database! You can now sign in.');
                              _signInEmailController.text = email;
                              _signInPasswordController.text = newPass;
                            } else {
                              AppTheme.triggerErrorHaptic();
                              _showToast(resetRes['message'] ?? 'Failed to reset password.', isError: true);
                            }
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        currentStep == 1
                            ? 'Send Code'
                            : (currentStep == 2 ? 'Verify OTP' : 'Set New Password'),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // BUILD MAIN UI
  // -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(
                    CurvedAnimation(parent: _entranceController, curve: AppTheme.curveExpressive),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Expressive doodle header card
                      _buildBrandHeader(),
                      const SizedBox(height: 16),

                      // Tab Bar Selector (Sign In / Sign Up)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderLight),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: Colors.white,
                          unselectedLabelColor: AppTheme.textSecondary,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppTheme.royalNavy, Color(0xFF164E7E)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'Sign In'),
                            Tab(text: 'Create Account'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Tab Views
                      SizedBox(
                        height: 520,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildSignInForm(),
                            _buildSignUpForm(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: AppTheme.heroRadius,
        boxShadow: AppTheme.heroCardShadow,
      ),
      child: ClipRRect(
        borderRadius: AppTheme.heroRadius,
        child: Stack(
          children: [
            // Doodle pattern backdrop
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: DoodlePatternPainter(ink: Colors.white, opacity: 0.08, seed: 11),
                ),
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    // Logo medallion
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 14, offset: const Offset(0, 6)),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/du.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(LucideIcons.graduationCap, size: 30, color: AppTheme.royalNavy),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'CCSAAS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _GoogleDotsRow(),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Centre for Computer Science and Applications',
                            maxLines: 2,
                            softWrap: true,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                          Text(
                            'Dibrugarh University',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Feature pills — wrap to a second line on narrow screens
                const Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _HeaderPill(icon: LucideIcons.qrCode, label: 'Dynamic QR'),
                    _HeaderPill(icon: LucideIcons.mapPin, label: 'Geo-verified'),
                    _HeaderPill(icon: LucideIcons.cloud, label: 'Live Sync'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel('Academic Email Address'),
          StaggeredEntrance(
            index: 0,
            child: TextFormField(
              controller: _signInEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(hint: 'e.g. name@du.ac.in', prefixIcon: LucideIcons.mail),
            ),
          ),
          const SizedBox(height: 16),

          _buildInputLabel('Password'),
          StaggeredEntrance(
            index: 1,
            child: TextFormField(
              controller: _signInPasswordController,
              obscureText: _obscureSignInPassword,
              decoration: _inputDecoration(
                hint: 'Enter your password',
                prefixIcon: LucideIcons.lock,
                suffixIcon: IconButton(
                  icon: Icon(_obscureSignInPassword ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: AppTheme.textSecondary),
                  onPressed: () => setState(() => _obscureSignInPassword = !_obscureSignInPassword),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.googleBlue),
              ),
            ),
          ),
          const SizedBox(height: 12),

          StaggeredEntrance(
            index: 2,
            child: PressableScale(
              onTap: _isSigningIn ? null : _handleSignIn,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.royalNavy, Color(0xFF164E7E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.glowShadowNavy,
                ),
                alignment: Alignment.center,
                child: _isSigningIn
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.logIn, size: 18, color: Colors.white),
                          const SizedBox(width: 9),
                          Text(
                            'Sign In',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14.5, color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel('I am registering as:'),
          Row(
            children: [
              Expanded(
                child: _buildRoleSelectorChip(
                  label: 'Student',
                  icon: LucideIcons.user,
                  isSelected: _signUpRole == 'student',
                  onTap: () {
                    AppTheme.triggerSelectionHaptic();
                    setState(() => _signUpRole = 'student');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRoleSelectorChip(
                  label: 'Faculty',
                  icon: LucideIcons.briefcase,
                  isSelected: _signUpRole == 'faculty',
                  onTap: () {
                    AppTheme.triggerSelectionHaptic();
                    setState(() => _signUpRole = 'faculty');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_signUpRole == 'student') ...[
            _buildInputLabel('Full Name (Select from CCSA Directory)'),
            PressableScale(
              onTap: _openStudentDirectoryPicker,
              pressedScale: 0.985,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _selectedDirectoryStudent != null ? AppTheme.royalNavy : AppTheme.borderLight, width: _selectedDirectoryStudent != null ? 1.5 : 1),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.userCheck, size: 18, color: _selectedDirectoryStudent != null ? AppTheme.googleGreen : AppTheme.royalNavy),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedDirectoryStudent != null
                            ? '${_selectedDirectoryStudent!.name} (${_selectedDirectoryStudent!.course} ${_selectedDirectoryStudent!.semesterDisplay})'
                            : 'Tap to choose your name...',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: _selectedDirectoryStudent != null ? FontWeight.w700 : FontWeight.w400,
                          color: _selectedDirectoryStudent != null ? AppTheme.royalNavy : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const Icon(LucideIcons.chevronDown, size: 18, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
          ] else ...[
            _buildInputLabel('Faculty Name (CCSA Directory)'),
            DropdownButtonFormField<String>(
              value: _isGuestFaculty ? 'Guest Faculty' : _selectedFacultyName,
              decoration: _inputDecoration(prefixIcon: LucideIcons.user),
              items: FacultyDirectoryService.facultyOptions.map((f) {
                return DropdownMenuItem(value: f, child: Text(f, style: GoogleFonts.inter(fontSize: 13)));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    if (val == 'Guest Faculty') {
                      _isGuestFaculty = true;
                    } else {
                      _isGuestFaculty = false;
                      _selectedFacultyName = val;
                    }
                  });
                }
              },
            ),
            if (_isGuestFaculty) ...[
              const SizedBox(height: 10),
              _buildInputLabel('Enter Guest Faculty Name'),
              TextFormField(
                controller: _guestFacultyNameController,
                decoration: _inputDecoration(hint: 'e.g. Dr. Guest Lecturer', prefixIcon: LucideIcons.userPlus),
              ),
            ],
          ],
          const SizedBox(height: 14),

          _buildInputLabel('Email Address'),
          TextFormField(
            controller: _signUpEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(hint: 'your.email@gmail.com', prefixIcon: LucideIcons.mail),
          ),
          const SizedBox(height: 14),

          _buildInputLabel('Password'),
          TextFormField(
            controller: _signUpPasswordController,
            obscureText: _obscureSignUpPassword,
            decoration: _inputDecoration(
              hint: 'Min 6 characters',
              prefixIcon: LucideIcons.lock,
              suffixIcon: IconButton(
                icon: Icon(_obscureSignUpPassword ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: AppTheme.textSecondary),
                onPressed: () => setState(() => _obscureSignUpPassword = !_obscureSignUpPassword),
              ),
            ),
          ),
          const SizedBox(height: 14),

          _buildInputLabel('Confirm Password'),
          TextFormField(
            controller: _signUpConfirmPasswordController,
            obscureText: _obscureSignUpPassword,
            decoration: _inputDecoration(hint: 'Repeat password', prefixIcon: LucideIcons.lock),
          ),
          const SizedBox(height: 20),

          PressableScale(
            onTap: _isSigningUp ? null : _handleSignUp,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.royalNavy, Color(0xFF164E7E)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.glowShadowNavy,
              ),
              alignment: Alignment.center,
              child: _isSigningUp
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)),
                        const SizedBox(width: 10),
                        Text(
                          'Sending Code...',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.userPlus, size: 18, color: Colors.white),
                        const SizedBox(width: 9),
                        Text(
                          'Create Account',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14.5, color: Colors.white),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRoleSelectorChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.95,
      child: AnimatedContainer(
        duration: AppTheme.motionFast,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.royalNavy, Color(0xFF164E7E)],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppTheme.royalNavy : AppTheme.borderLight),
          boxShadow: isSelected ? AppTheme.glowShadowNavy : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.royalNavy),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, IconData? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 17, color: AppTheme.royalNavy) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderLight)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderLight)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.royalNavy, width: 1.5)),
    );
  }
}

/// Tiny Google-colored dot quartet used next to the brand name.
class _GoogleDotsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const colors = [
      AppTheme.googleBlue,
      AppTheme.googleRed,
      AppTheme.googleYellow,
      AppTheme.googleGreen,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < colors.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
          ),
        ],
      ],
    );
  }
}

/// Small translucent pill for header feature tags.
class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
