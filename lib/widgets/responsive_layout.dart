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
          // Persistent Desktop / Tablet Navigation Rail (M3 Expressive pill indicator)
          if (isWideScreen && navItems.isNotEmpty)
            _ExpressiveNavRail(
              selectedIndex: selectedIndex,
              navItems: navItems,
              onDestinationSelected: (index) {
                onDestinationSelected?.call(index);
                navItems[index].onTap();
              },
              extended: isDesktop,
              headerLeading: headerLeading,
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

/// M3 Expressive Navigation Rail with rounded pill active indicator.
class _ExpressiveNavRail extends StatefulWidget {
  final int selectedIndex;
  final List<AdaptiveNavItem> navItems;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;
  final Widget? headerLeading;

  const _ExpressiveNavRail({
    required this.selectedIndex,
    required this.navItems,
    required this.onDestinationSelected,
    required this.extended,
    this.headerLeading,
  });

  @override
  State<_ExpressiveNavRail> createState() => _ExpressiveNavRailState();
}

class _ExpressiveNavRailState extends State<_ExpressiveNavRail> with SingleTickerProviderStateMixin {
  late final AnimationController _indicatorController;

  @override
  void initState() {
    super.initState();
    _indicatorController = AnimationController(vsync: this, duration: AppTheme.motionNormal);
    _indicatorController.value = 1.0;
  }

  @override
  void didUpdateWidget(_ExpressiveNavRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _indicatorController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final railWidth = widget.extended ? 228.0 : 84.0;

    return AnimatedContainer(
      duration: AppTheme.motionNormal,
      curve: Curves.easeOutCubic,
      width: railWidth,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Leading brand mark
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: widget.headerLeading ??
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: widget.navItems.length,
              itemBuilder: (context, index) {
                final item = widget.navItems[index];
                final selected = index == widget.selectedIndex;
                return _RailTile(
                  item: item,
                  selected: selected,
                  extended: widget.extended,
                  indicatorController: _indicatorController,
                  onTap: () {
                    AppTheme.triggerSelectionHaptic();
                    widget.onDestinationSelected(index);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RailTile extends StatefulWidget {
  final AdaptiveNavItem item;
  final bool selected;
  final bool extended;
  final AnimationController indicatorController;
  final VoidCallback onTap;

  const _RailTile({
    required this.item,
    required this.selected,
    required this.extended,
    required this.indicatorController,
    required this.onTap,
  });

  @override
  State<_RailTile> createState() => _RailTileState();
}

class _RailTileState extends State<_RailTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.selected ? widget.item.selectedIcon : widget.item.icon,
      size: 21,
      color: widget.selected ? AppTheme.royalNavy : AppTheme.textSecondary,
    );
    final label = Text(
      widget.item.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
        color: widget.selected ? AppTheme.royalNavy : AppTheme.textSecondary,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: AppTheme.motionFast,
            curve: Curves.easeOutCubic,
            height: 52,
            padding: EdgeInsets.symmetric(horizontal: widget.extended ? 12 : 0),
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppTheme.googleSky.withOpacity(0.65)
                  : (_hovering ? AppTheme.bgLight : Colors.transparent),
              borderRadius: BorderRadius.circular(18),
            ),
            child: widget.extended
                ? Row(
                    children: [
                      SizedBox(width: 36, child: Center(child: icon)),
                      const SizedBox(width: 12),
                      Expanded(child: label),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [icon, const SizedBox(height: 3), label],
                  ),
          ),
        ),
      ),
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
