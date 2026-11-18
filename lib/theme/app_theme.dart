import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Palette (Academic Navy + Google / Fintech Inspired Tones)
  static const Color royalNavy = Color(0xFF0F2942);
  static const Color royalNavyDark = Color(0xFF0A192F);
  static const Color royalNavyLight = Color(0xFF1E3A8A);
  static const Color googleBlue = Color(0xFF1A73E8);
  static const Color electricTeal = Color(0xFF0D9488);
  static const Color electricTealLight = Color(0xFF14B8A6);
  static const Color electricTealBg = Color(0xFFE6FFFA);

  // Google Doodle Accent Quartet (playful, used for doodles + micro accents)
  static const Color googleRed = Color(0xFFEA4335);
  static const Color googleYellow = Color(0xFFFBBC04);
  static const Color googleGreen = Color(0xFF34A853);
  static const Color googlePurple = Color(0xFF9334E6);
  static const Color googlePeach = Color(0xFFFFB59B);
  static const Color googleSky = Color(0xFFD2E3FC);
  static const Color googleMint = Color(0xFFCEEAD6);
  static const Color googleLemon = Color(0xFFFEEFC3);
  static const Color googleBlush = Color(0xFFFAD2E1);
  static const Color googleLilac = Color(0xFFE9DDFF);

  // Gradient Kits (M3 Expressive hero surfaces)
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14335C), Color(0xFF0F2942), Color(0xFF0A4A5A)],
    stops: [0.0, 0.55, 1.0],
  );
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34A853), Color(0xFF0D9488)],
  );
  static const LinearGradient sunriseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBC04), Color(0xFFFF8A65)],
  );

  // M3 Surface & Background (GPay Canvas)
  static const Color bgLight = Color(0xFFF6F8FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF1F5F9);
  static const Color surfaceContainer = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFF1F5F9);

  // Status Accents
  static const Color emeraldGreen = Color(0xFF10B981); // Present / Safe (>75%)
  static const Color emeraldGreenBg = Color(0xFFECFDF5);
  static const Color emeraldGreenBorder = Color(0xFFA7F3D0);

  static const Color crimsonRose = Color(0xFFF43F5E); // Absent / Shortage (<75%)
  static const Color crimsonRoseBg = Color(0xFFFFF1F2);
  static const Color crimsonRoseBorder = Color(0xFFFECDD3);

  static const Color amberWarning = Color(0xFFF59E0B); // Lab (2h) / Warning
  static const Color amberWarningBg = Color(0xFFFFFBEB);
  static const Color amberWarningBorder = Color(0xFFFDE68A);

  static const Color indigoAccent = Color(0xFF6366F1);
  static const Color indigoAccentBg = Color(0xFFEEF2FF);

  // Typography Palette
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // M3 Spacing Grid
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  // GPay Radii Standard
  static const double cardRadiusValue = 20.0;
  static const double pillRadiusValue = 28.0;
  static final BorderRadius cardRadius = BorderRadius.circular(cardRadiusValue);
  static final BorderRadius roundedRadius = BorderRadius.circular(cardRadiusValue);
  static final BorderRadius pillRadius = BorderRadius.circular(pillRadiusValue);
  static final BorderRadius smallRadius = BorderRadius.circular(12.0);
  // M3 Expressive squircle-ish radii
  static final BorderRadius xlRadius = BorderRadius.circular(28.0);
  static final BorderRadius heroRadius = BorderRadius.circular(32.0);

  // M3 Expressive Motion Tokens
  static const Duration motionFast = Duration(milliseconds: 200);
  static const Duration motionNormal = Duration(milliseconds: 350);
  static const Duration motionSlow = Duration(milliseconds: 550);
  static const Duration motionSpring = Duration(milliseconds: 640);
  static const Curve curveExpressive = Curves.easeOutBack;
  static const Curve curveEmphasized = Curves.easeInOutCubicEmphasized;
  static const Curve curveSpring = Curves.elasticOut;

  // Tonal Shadows (Soft, modern, non-harsh)
  static final List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.02),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static final List<BoxShadow> heroCardShadow = [
    BoxShadow(
      color: royalNavy.withOpacity(0.18),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> glowShadowTeal = [
    BoxShadow(
      color: electricTeal.withOpacity(0.24),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static final List<BoxShadow> glowShadowNavy = [
    BoxShadow(
      color: royalNavy.withOpacity(0.22),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> coloredGlow(Color color, {double opacity = 0.28}) => [
        BoxShadow(
          color: color.withOpacity(opacity),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  // Haptic Feedback Engine
  static void triggerLightHaptic() => HapticFeedback.lightImpact();
  static void triggerMediumHaptic() => HapticFeedback.mediumImpact();
  static void triggerHeavyHaptic() => HapticFeedback.heavyImpact();
  static void triggerSelectionHaptic() => HapticFeedback.selectionClick();
  static void triggerSuccessHaptic() {
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 80), () => HapticFeedback.lightImpact());
  }
  static void triggerErrorHaptic() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () => HapticFeedback.heavyImpact());
  }

  /// Brand-consistent floating snackbar used across the redesigned app.
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
    IconData? icon,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final Color bg = isError ? crimsonRose : (isSuccess ? emeraldGreen : royalNavy);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ?? (isError ? LucideIconsPlaceholder.error : (isSuccess ? LucideIconsPlaceholder.check : LucideIconsPlaceholder.info)),
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
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  /// Branded circular progress loader used by redesigned pages.
  static Widget brandLoader({double size = 30, Color color = royalNavy}) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        strokeCap: StrokeCap.round,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  // Material Design 3 Theme Data
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: royalNavy,
      scaffoldBackgroundColor: bgLight,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: ColorScheme.light(
        primary: royalNavy,
        onPrimary: Colors.white,
        primaryContainer: googleSky,
        onPrimaryContainer: royalNavy,
        secondary: electricTeal,
        onSecondary: Colors.white,
        secondaryContainer: electricTealBg,
        onSecondaryContainer: electricTeal,
        tertiary: emeraldGreen,
        onTertiary: Colors.white,
        tertiaryContainer: emeraldGreenBg,
        onTertiaryContainer: emeraldGreen,
        surface: surfaceLight,
        onSurface: textPrimary,
        surfaceContainerLow: surfaceContainerLow,
        surfaceContainer: surfaceContainer,
        error: crimsonRose,
        onError: Colors.white,
        outline: borderLight,
        outlineVariant: borderLight.withOpacity(0.7),
      ),
      textTheme: textTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.6,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.45,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.4,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w400,
          color: textMuted,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: textMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: borderLight.withOpacity(0.8), width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: royalNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: pillRadius),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: royalNavy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: pillRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: royalNavy,
          side: const BorderSide(color: borderLight, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: pillRadius),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: royalNavy,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLight,
        selectedColor: royalNavy,
        side: const BorderSide(color: borderLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: royalNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceLight,
        elevation: 8,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: textPrimary),
        contentTextStyle: GoogleFonts.inter(fontSize: 13.5, color: textSecondary, height: 1.45),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceLight,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surfaceLight,
        showDragHandle: true,
        dragHandleColor: borderLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: textSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return textMuted;
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return borderLight;
          if (states.contains(WidgetState.selected)) return emeraldGreen;
          return surfaceContainer;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.transparent : borderLight,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: royalNavy,
        linearTrackColor: borderLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: royalNavy, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: crimsonRose, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: crimsonRose, width: 1.8),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: 16,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Private icon placeholder indirection so showSnackBar avoids importing
/// lucide_icons (keeps the theme dependency-lean for reuse in tests).
class LucideIconsPlaceholder {
  static const IconData error = IconData(0xe002, fontFamily: 'MaterialIcons');
  static const IconData check = IconData(0xe5ca, fontFamily: 'MaterialIcons');
  static const IconData info = IconData(0xe88f, fontFamily: 'MaterialIcons');
}
