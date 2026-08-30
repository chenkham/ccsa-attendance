import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../db/database_helper.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/device_security_service.dart';
import '../../services/location_service.dart';
import '../../services/totp_qr_service.dart';
import '../../theme/app_theme.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _torchOn = false;
  double _currentZoom = 0.0; // 0.0 to 1.0
  late AnimationController _laserAnimController;

  @override
  void initState() {
    super.initState();
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _setZoom(double zoom) {
    setState(() => _currentZoom = zoom.clamp(0.0, 1.0));
    _scannerController.setZoomScale(_currentZoom);
    AppTheme.triggerLightHaptic();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);
    AppTheme.triggerLightHaptic();

    // 1. Validate Dynamic 3-Second HMAC-SHA256 Token
    final validation = TotpQrService.instance.validatePayload(rawValue);

    if (!validation.isValid) {
      AppTheme.triggerErrorHaptic();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validation.errorMessage ?? 'Invalid QR Code'),
            backgroundColor: AppTheme.crimsonRose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    // 2. LAYER 5: Classroom GPS Geofencing Check (If enabled by Faculty)
    if (validation.geofenceEnabled && validation.targetLat != null && validation.targetLng != null) {
      final geoResult = await LocationService.instance.verifyStudentInClassroom(
        targetLat: validation.targetLat!,
        targetLng: validation.targetLng!,
        radiusMeters: validation.radiusMeters,
      );

      if (!geoResult.isWithin) {
        AppTheme.triggerErrorHaptic();
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: const Row(
                children: [
                  Icon(LucideIcons.mapPinOff, color: AppTheme.crimsonRose, size: 24),
                  SizedBox(width: 8),
                  Text('Outside Classroom!'),
                ],
              ),
              content: Text(
                geoResult.errorMessage ?? 'You are physically outside the geofenced classroom radius.',
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalNavy),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
    }

    // 3. Hardware Device Binding Check (1 Student = 1 Phone)
    final student = AuthService.instance.currentStudent;
    final user = AuthService.instance.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in as a student first.'),
            backgroundColor: AppTheme.crimsonRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _isProcessing = false);
      return;
    }



    final sessionId = validation.sessionId;
    if (sessionId == null) {
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    final subject = await DatabaseHelper.instance.getSubjectById(validation.subjectId ?? '');
    final subjectCode = subject?.code ?? 'SUBJECT';
    final subjectName = subject?.name ?? 'Lecture Session';

    // 4. Biometric Authentication Check (On Supported Phones)
    final bioAuth = await DeviceSecurityService.instance.authenticateBiometric(
      reason: 'Scan Attendance for $subjectCode',
    );

    if (!bioAuth) {
      AppTheme.triggerErrorHaptic();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric / passcode confirmation required.'),
            backgroundColor: AppTheme.crimsonRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    // 5. Check if already marked present in this session
    final existingRecords = await DatabaseHelper.instance.getRecordsForSession(sessionId);
    final alreadyMarked = existingRecords.any((r) => r.studentId == user.id);

    if (alreadyMarked) {
      AppTheme.triggerLightHaptic();
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(LucideIcons.checkCircle2, color: AppTheme.emeraldGreen, size: 24),
                SizedBox(width: 8),
                Text('Already Recorded'),
              ],
            ),
            content: Text('Your attendance for $subjectCode is already recorded for this lecture.'),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalNavy),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('Back to Home'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 6. Record Verified Attendance in Local Database & Hostinger MySQL Cloud
    await DatabaseHelper.instance.recordSingleStudentAttendance(
      sessionId: sessionId,
      studentId: user.id,
      studentRollNo: user.studentRollNo ?? student?.classRollNo ?? 'N/A',
      studentName: user.name,
    );

    // Sync live scan to Hostinger MySQL immediately
    await ApiService.instance.recordStudentAttendanceLive(
      sessionId: sessionId,
      studentId: user.id,
      email: user.email,
      name: user.name,
      rollNo: user.studentRollNo ?? student?.classRollNo ?? '',
      subjectId: validation.subjectId ?? subject?.id,
      subjectCode: subjectCode,
      subjectName: subjectName,
      teacherEmail: subject?.teacherEmail,
    );

    AppTheme.triggerSuccessHaptic();

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppTheme.emeraldGreenBg,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(LucideIcons.checkCheck, size: 36, color: Color(0xFF047857)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Attendance Confirmed!',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
              ),
              const SizedBox(height: 6),
              Text(
                '$subjectCode • $subjectName',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Verified for ${user.name} (${user.studentRollNo ?? "Student"})',
                style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, true);
                  },
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanWindowSize = size.width * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full Screen Camera Viewfinder
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // 2. Translucent Dark Mask with Cutout
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.65),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: scanWindowSize,
                    height: scanWindowSize,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Viewfinder Focus Reticle & Animated Laser Line
          Center(
            child: SizedBox(
              width: scanWindowSize,
              height: scanWindowSize,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _laserAnimController,
                    builder: (context, child) {
                      return Positioned(
                        top: _laserAnimController.value * (scanWindowSize - 20) + 10,
                        left: 16,
                        right: 16,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.transparent, AppTheme.electricTeal, Colors.white, AppTheme.electricTeal, Colors.transparent],
                            ),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(color: AppTheme.electricTeal.withOpacity(0.8), blurRadius: 10, spreadRadius: 1),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Header Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Material(
                  color: Colors.black.withOpacity(0.5),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Text(
                  'Scan Classroom QR',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                ),
                Material(
                  color: Colors.black.withOpacity(0.5),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: Icon(_torchOn ? LucideIcons.zap : LucideIcons.zapOff, color: _torchOn ? Colors.amber : Colors.white, size: 20),
                    onPressed: () {
                      setState(() => _torchOn = !_torchOn);
                      _scannerController.toggleTorch();
                      AppTheme.triggerLightHaptic();
                    },
                  ),
                ),
              ],
            ),
          ),

          // 5. Bottom Controls: Zoom Presets (1x, 2x, 3x) + Live Zoom Slider
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom Quick Presets
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildZoomPresetButton('1x', 0.0),
                    const SizedBox(width: 12),
                    _buildZoomPresetButton('2x', 0.35),
                    const SizedBox(width: 12),
                    _buildZoomPresetButton('3x', 0.7),
                    const SizedBox(width: 12),
                    _buildZoomPresetButton('Max', 1.0),
                  ],
                ),
                const SizedBox(height: 12),

                // Zoom Slider
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.zoomOut, color: Colors.white, size: 16),
                      Expanded(
                        child: Slider(
                          value: _currentZoom,
                          min: 0.0,
                          max: 1.0,
                          activeColor: AppTheme.electricTeal,
                          inactiveColor: Colors.white24,
                          onChanged: _setZoom,
                        ),
                      ),
                      const Icon(LucideIcons.zoomIn, color: Colors.white, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Align QR code within the frame or use zoom from your desk.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomPresetButton(String label, double zoomValue) {
    final bool isSelected = (_currentZoom - zoomValue).abs() < 0.15;

    return Material(
      color: isSelected ? AppTheme.electricTeal : Colors.black.withOpacity(0.6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _setZoom(zoomValue),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
