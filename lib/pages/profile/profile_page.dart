import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../db/database_helper.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/device_security_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/doodle_art.dart';
import '../../widgets/micro_interactions.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  // Student specific controllers
  final _classRollController = TextEditingController();
  final _examRollController = TextEditingController();
  String _selectedCourse = 'BCA';
  int _selectedSemester = 1;

  // Faculty specific controllers
  final _departmentController = TextEditingController();
  final _designationController = TextEditingController();

  String _deviceId = 'Loading...';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _classRollController.dispose();
    _examRollController.dispose();
    _departmentController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = AuthService.instance.currentUser;
    final devId = await DeviceSecurityService.instance.getHardwareDeviceId();

    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;

      if (user.isStudent) {
        final std = await DatabaseHelper.instance.getStudentById(user.id);
        _classRollController.text = std?.classRollNo ?? user.studentRollNo ?? '';
        _examRollController.text = std?.duExamRollNo ?? user.duExamRollNo ?? '';
        _selectedCourse = std?.course ?? user.course ?? 'BCA';
        _selectedSemester = std?.semester ?? user.semester ?? 1;
      } else {
        _departmentController.text = user.department ?? 'CCSA, Dibrugarh University';
        _designationController.text = user.designation ?? 'Assistant Professor';
      }
    }

    if (mounted) {
      setState(() {
        _deviceId = devId;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      AppTheme.triggerErrorHaptic();
      return;
    }

    setState(() => _isSaving = true);
    AppTheme.triggerLightHaptic();

    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final updatedUser = User(
      id: user.id,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: user.password,
      role: user.role,
      studentRollNo: user.isStudent ? _classRollController.text.trim() : null,
      duExamRollNo: user.isStudent ? _examRollController.text.trim() : null,
      course: user.isStudent ? _selectedCourse : null,
      semester: user.isStudent ? _selectedSemester : null,
      designation: !user.isStudent ? _designationController.text.trim() : null,
      department: !user.isStudent ? _departmentController.text.trim() : null,
      deviceId: _deviceId,
      profileCompleted: true,
      createdAt: user.createdAt,
    );

    final success = await AuthService.instance.updateUser(updatedUser);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        AppTheme.triggerSuccessHaptic();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Academic profile updated successfully!'),
            backgroundColor: AppTheme.emeraldGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      } else {
        AppTheme.triggerErrorHaptic();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update profile.'),
            backgroundColor: AppTheme.crimsonRose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isStudent = user?.isStudent ?? true;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.bgLight,
        title: Text(
          'Academic Profile',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.royalNavy),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Overview Header Card — expressive gradient hero
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.heroGradient,
                      borderRadius: AppTheme.heroRadius,
                      boxShadow: AppTheme.heroCardShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: AppTheme.heroRadius,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(painter: DoodlePatternPainter(ink: Colors.white, opacity: 0.08, seed: 41)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user?.name ?? 'User Profile',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user?.email ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.75)),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isStudent ? AppTheme.electricTealBg : AppTheme.emeraldGreenBg,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isStudent ? 'CCSA Student' : 'CCSA Faculty',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: isStudent ? AppTheme.electricTeal : const Color(0xFF047857),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Student Academic Details Card
                  if (isStudent) ...[
                    _buildSectionHeader('Academic Details & Enrollment', LucideIcons.bookOpen),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
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
                                      onChanged: (val) => setState(() => _selectedCourse = val ?? 'BCA'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Semester', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.royalNavy)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<int>(
                                      value: _selectedSemester,
                                      isExpanded: true,
                                      decoration: _inputDecoration(prefixIcon: LucideIcons.layers),
                                      items: List.generate(8, (i) => i + 1).map((sem) {
                                        return DropdownMenuItem(value: sem, child: Text('Semester $sem'));
                                      }).toList(),
                                      onChanged: (val) => setState(() => _selectedSemester = val ?? 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text('Class Roll Number', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.royalNavy)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _classRollController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _inputDecoration(
                              hint: 'e.g. 01 / BCA-21-01',
                              prefixIcon: LucideIcons.creditCard,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your class roll number' : null,
                          ),
                          const SizedBox(height: 14),
                          Text('DU Exam / Registration Number', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.royalNavy)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _examRollController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _inputDecoration(
                              hint: 'e.g. 21BCA001',
                              prefixIcon: LucideIcons.fileText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Faculty Details Card
                  if (!isStudent) ...[
                    _buildSectionHeader('Faculty Information', LucideIcons.briefcase),
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
                            controller: _designationController,
                            decoration: _inputDecoration(label: 'Designation', hint: 'e.g. Assistant Professor', prefixIcon: LucideIcons.userCheck),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _departmentController,
                            decoration: _inputDecoration(label: 'Department', hint: 'CCSA, Dibrugarh University', prefixIcon: LucideIcons.building),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Save Profile Button
                  PressableScale(
                    onTap: _isSaving ? null : _saveProfile,
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
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.check, size: 18, color: Colors.white),
                                const SizedBox(width: 9),
                                Text(
                                  'Save Profile',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14.5, color: Colors.white),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
      children: [
        Icon(icon, size: 16, color: AppTheme.royalNavy),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
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
