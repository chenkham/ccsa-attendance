import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/subject.dart';
import '../theme/app_theme.dart';
import 'doodle_art.dart';
import 'micro_interactions.dart';
import 'marquee_text.dart';

/// M3 Expressive Primary Action Pill Button — springy press, tonal glow.
class GPayActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isPrimary;
  final double height;

  const GPayActionPill({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.isPrimary = true,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? (isPrimary ? theme.colorScheme.primary : theme.colorScheme.surface);
    final fg = foregroundColor ?? (isPrimary ? Colors.white : theme.colorScheme.primary);

    return PressableScale(
      onTap: onPressed,
      child: SizedBox(
        height: height,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppTheme.pillRadius,
            gradient: isPrimary
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bg, Color.lerp(bg, Colors.black, 0.16)!],
                  )
                : null,
            border: isPrimary ? null : Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.7), width: 1.2),
            boxShadow: isPrimary ? AppTheme.glowShadowNavy : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick Action Button — tonal squircle tile with springy press.
class GPayQuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? backgroundColor;

  const GPayQuickActionItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iColor = iconColor ?? theme.colorScheme.primary;
    final bColor = backgroundColor ?? iColor.withOpacity(0.09);

    return PressableScale(
      onTap: onTap,
      pressedScale: 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: iColor.withOpacity(0.10), width: 1),
              boxShadow: [
                BoxShadow(color: iColor.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iColor, size: 22),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 76,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.85),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tonal Metric Stat Card with animated counter.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6), width: 1.0),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Icon(icon, size: 18, color: accentColor),
                ),
              ),
              if (subtitle != null)
                Flexible(
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarqueeText(
                text: value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Subject / Course Card with doodle accent corner.
class SubjectCard extends StatelessWidget {
  final Subject subject;
  final VoidCallback onTakeAttendance;
  final VoidCallback onManualAttendance;
  final VoidCallback onExportCsv;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.onTakeAttendance,
    required this.onManualAttendance,
    required this.onExportCsv,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.cardRadius,
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.7), width: 1.0),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Code badge, Cohort, Batch chip & Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: AppTheme.royalNavy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subject.code,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.royalNavy,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Text(
                      '${subject.course} ${subject.semesterDisplay}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: subject.batchType == 'whole' ? AppTheme.indigoAccentBg : AppTheme.amberWarningBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subject.batchLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: subject.batchType == 'whole' ? AppTheme.indigoAccent : const Color(0xFFB45309),
                    ),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.moreVertical, size: 18, color: AppTheme.textSecondary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  onSelected: (val) {
                    if (val == 'csv') onExportCsv();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'csv',
                      child: Row(
                        children: [
                          Icon(LucideIcons.fileSpreadsheet, size: 16, color: AppTheme.emeraldGreen),
                          SizedBox(width: 10),
                          Text('Export Official CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(LucideIcons.trash2, size: 16, color: AppTheme.crimsonRose),
                          SizedBox(width: 10),
                          Text('Delete Subject', style: TextStyle(color: AppTheme.crimsonRose, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Marquee / Truncated Subject Title
            MarqueeText(
              text: subject.name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(LucideIcons.userCheck, size: 13, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Prof. ${subject.professorName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
            const SizedBox(height: 12),

            // Bottom Action & Enrollment Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.bgLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.users, size: 13, color: AppTheme.royalNavy),
                      const SizedBox(width: 6),
                      Text(
                        '${subject.enrolledStudentIds.length} Enrolled',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                PressableScale(
                  onTap: onTakeAttendance,
                  pressedScale: 0.94,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.royalNavy, Color(0xFF164E7E)],
                      ),
                      borderRadius: AppTheme.pillRadius,
                      boxShadow: AppTheme.glowShadowNavy,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.qrCode, size: 15, color: Colors.white),
                        const SizedBox(width: 7),
                        Text(
                          'Take Attendance',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Expressive Empty State Composition with layered Doodle vector scenes.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;
  final DoodleScene? scene;
  final IconData? buttonIcon;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonPressed,
    this.scene,
    this.buttonIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.xlRadius,
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.6), width: 1.0),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DoodleEmptyArt(scene: scene ?? _sceneForIcon(icon), size: 140),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              softWrap: true,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ),
          if (buttonLabel != null && onButtonPressed != null) ...[
            const SizedBox(height: 20),
            PressableScale(
              onTap: onButtonPressed!,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: AppTheme.pillRadius,
                  boxShadow: AppTheme.glowShadowNavy,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(buttonIcon ?? LucideIcons.plus, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      buttonLabel!,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  DoodleScene _sceneForIcon(IconData icon) {
    if (icon == LucideIcons.search || icon == LucideIcons.searchX) return DoodleScene.magnifier;
    if (icon == LucideIcons.wifiOff || icon == LucideIcons.cloudOff) return DoodleScene.wifiOff;
    if (icon == LucideIcons.calendarX || icon == LucideIcons.calendar) return DoodleScene.calendar;
    if (icon == LucideIcons.rocket || icon == LucideIcons.plusCircle) return DoodleScene.rocket;
    if (icon == LucideIcons.shieldCheck || icon == LucideIcons.shield) return DoodleScene.shieldCheck;
    if (icon == LucideIcons.clipboardCheck || icon == LucideIcons.checkSquare) return DoodleScene.clipboardCheck;
    if (icon == LucideIcons.qrCode || icon == LucideIcons.scanLine) return DoodleScene.qrFrame;
    return DoodleScene.openBook;
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? count;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: MarqueeText(
                      text: title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.royalNavy,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.royalNavy.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.royalNavy,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              const DoodleUnderline(width: 52, height: 7),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
