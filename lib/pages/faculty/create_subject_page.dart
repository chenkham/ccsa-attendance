import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../db/database_helper.dart';
import '../../models/student.dart';
import '../../models/subject.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/doodle_art.dart';
import '../../widgets/micro_interactions.dart';

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

    try {
      // Only fetch students who have signed up with proper email, roll no, exam roll no
      final onlineStudents = await ApiService.instance.getRegisteredStudents(
        course: _selectedCourse,
        semester: _selectedSemester,
      );

      for (final std in onlineStudents) {
        try {
          await DatabaseHelper.instance.insertStudent(std);
        } catch (_) {}
      }

      mergedStudents = onlineStudents;
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
      // When geofencing is OFF store NO coordinates — otherwise cloud-derived
      // geofence state falsely turns ON for every device.
      latitude: _geofenceEnabled ? _targetLatitude : null,
      longitude: _geofenceEnabled ? _targetLongitude : null,
      radiusMeters: _radiusMeters,
      createdAt: DateTime.now(),
    );

    // Save to local SQLite & Hostinger MySQL Cloud Database
    try {
      await DatabaseHelper.instance.insertSubject(subject);
    } catch (_) {}

    await ApiService.instance.syncSubject(subject);

    AppTheme.triggerSuccessHaptic();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Subject "${subject.code} - ${subject.name}" created successfully! '
            'Previous register attendance can be imported anytime from Subject Details.',
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
        backgroundColor: AppTheme.bgLight,
        title: Text(
          'Create Subject',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.royalNavy),
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
                        TextFormField(
                          controller: _codeController,
                          decoration: _inputDecoration(
                            label: 'Subject Code',
                            hint: 'e.g. BCA 301',
                            prefixIcon: LucideIcons.hash,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Enter code' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _profController,
                          decoration: _inputDecoration(
                            label: 'Teacher Name',
                            hint: 'Faculty in charge',
                            prefixIcon: LucideIcons.user,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Enter faculty name' : null,
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
                            padding: EdgeInsets.all(20),
                            child: Center(child: BrandLoader(size: 36)),
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
                  PressableScale(
                    onTap: _handleCreateSubject,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.royalNavy, Color(0xFF164E7E)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppTheme.glowShadowNavy,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.check, size: 18, color: Colors.white),
                          const SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              'Create Subject (${_selectedStudentIds.length} Students)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14.5, color: Colors.white),
                            ),
                          ),
                        ],
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
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppTheme.royalNavy.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppTheme.royalNavy),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
          ),
        ),
        const SizedBox(width: 8),
        const DoodleUnderline(width: 30, height: 6),
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
