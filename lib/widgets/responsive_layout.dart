import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

/// Universal Responsive Breakpoint & Device Detection Utility
class Responsive {
  static const double mobileMaxWidth = 600.0;
  static const double tabletMaxWidth = 1024.0;
  static const double desktopContentMaxWidth = 1200.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileMaxWidth;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileMaxWidth &&
      MediaQuery.of(context).size.width < tabletMaxWidth;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletMaxWidth;

  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileMaxWidth;

  static bool get isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static bool get isMobilePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get isApplePlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  /// Pick appropriate value based on active screen breakpoint
  static T value<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }
}

/// Navigation Item Model for Adaptive Shells
class AdaptiveNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  const AdaptiveNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });
}

/// Universal Adaptive Scaffold (Bottom Navigation on Mobile, Navigation Rail on Tablet/Desktop)
class AdaptiveScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final int selectedIndex;
  final List<AdaptiveNavItem> navItems;
  final ValueChanged<int>? onDestinationSelected;
  final Widget? floatingActionButton;
  final Widget? headerLeading;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    required this.title,
    this.titleWidget,
    this.actions,
    this.selectedIndex = 0,
    required this.navItems,
    this.onDestinationSelected,
    this.floatingActionButton,
    this.headerLeading,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    final isWideScreen = isDesktop || isTablet;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: Row(
        children: [
          // Persistent Desktop / Tablet Navigation Rail
          if (isWideScreen && navItems.isNotEmpty)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                AppTheme.triggerLightHaptic();
                onDestinationSelected?.call(index);
                navItems[index].onTap();
              },
              backgroundColor: Colors.white,
              minWidth: isDesktop ? 80 : 72,
              extended: false,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: headerLeading ??
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderLight),
                        boxShadow: AppTheme.softShadow,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/du.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(LucideIcons.graduationCap, color: AppTheme.royalNavy, size: 22),
                          ),
                        ),
                      ),
                    ),
              ),
              destinations: navItems.map((item) {
                return NavigationRailDestination(
                  icon: Icon(item.icon, size: 22, color: AppTheme.textSecondary),
                  selectedIcon: Icon(item.selectedIcon, size: 22, color: AppTheme.royalNavy),
                  label: Text(item.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),

          if (isWideScreen && navItems.isNotEmpty)
            const VerticalDivider(width: 1, thickness: 1, color: AppTheme.borderLight),

          // Main Screen Area with Desktop Max-Width Constraint
          Expanded(
            child: body,
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Adaptive Content Wrapper with Desktop Scrollbar & Max-Width Constraints
class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.maxWidth = Responsive.desktopContentMaxWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
