import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/totp_qr_service.dart';
import '../theme/app_theme.dart';

class DynamicQrDisplay extends StatefulWidget {
  final String subjectId;
  final String sessionId;
  final double size;
  final bool isBigScreen;
  final bool geofenceEnabled;
  final double? targetLat;
  final double? targetLng;
  final double radiusMeters;

  const DynamicQrDisplay({
    super.key,
    required this.subjectId,
    required this.sessionId,
    this.size = 260,
    this.isBigScreen = false,
    this.geofenceEnabled = false,
    this.targetLat,
    this.targetLng,
    this.radiusMeters = 50.0,
  });

  @override
  State<DynamicQrDisplay> createState() => _DynamicQrDisplayState();
}

class _DynamicQrDisplayState extends State<DynamicQrDisplay> with SingleTickerProviderStateMixin {
  Timer? _timer;
  String _currentPayload = '';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _refreshQrPayload();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (mounted) {
        setState(() {
          _progress = TotpQrService.instance.cycleProgress;
          final newPayload = TotpQrService.instance.generateDynamicPayload(
            subjectId: widget.subjectId,
            sessionId: widget.sessionId,
            geofenceEnabled: widget.geofenceEnabled,
            targetLat: widget.targetLat,
            targetLng: widget.targetLng,
            radiusMeters: widget.radiusMeters,
          );
          if (newPayload != _currentPayload) {
            _currentPayload = newPayload;
          }
        });
      }
    });
  }

  void _refreshQrPayload() {
    _currentPayload = TotpQrService.instance.generateDynamicPayload(
      subjectId: widget.subjectId,
      sessionId: widget.sessionId,
      geofenceEnabled: widget.geofenceEnabled,
      targetLat: widget.targetLat,
      targetLng: widget.targetLng,
      radiusMeters: widget.radiusMeters,
    );
  }

  @override
  void didUpdateWidget(covariant DynamicQrDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geofenceEnabled != widget.geofenceEnabled ||
        oldWidget.targetLat != widget.targetLat ||
        oldWidget.targetLng != widget.targetLng ||
        oldWidget.radiusMeters != widget.radiusMeters) {
      _refreshQrPayload();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrSize = widget.size;
    final remainingSecs = (3 - (_progress * 3)).clamp(0.1, 3.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // QR Container with countdown progress ring
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: qrSize + 32,
              height: qrSize + 32,
              child: CircularProgressIndicator(
                value: 1.0 - _progress,
                strokeWidth: 4.5,
                strokeCap: StrokeCap.round,
                backgroundColor: AppTheme.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _progress < 0.7 ? AppTheme.royalNavy : AppTheme.amberWarning,
                ),
              ),
            ),

            // White Card housing the QR code
            Container(
              width: qrSize + 14,
              height: qrSize + 14,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softShadow,
                border: Border.all(color: AppTheme.borderLight, width: 1.5),
              ),
              child: _currentPayload.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.royalNavy))
                  : QrImageView(
                      data: _currentPayload,
                      version: QrVersions.auto,
                      size: qrSize,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0A192F),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0F172A),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Simple Refresh indicator & Geofence pill
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderLight, width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.refreshCw, size: 13, color: AppTheme.royalNavy),
                  const SizedBox(width: 6),
                  Text(
                    'Refreshes in ${remainingSecs.toStringAsFixed(1)}s',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.royalNavy,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.geofenceEnabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.electricTealBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.electricTeal, width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.mapPin, size: 13, color: AppTheme.electricTeal),
                    const SizedBox(width: 6),
                    Text(
                      'GPS ${widget.radiusMeters.toInt()}m',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.electricTeal,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
