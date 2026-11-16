import 'package:flutter/material.dart';

/// Window size classes (Material 3 adaptive guidance).
enum SizeClass { compact, medium, expanded, large }

/// Spacing scale: use only these values for padding and gaps.
class Space {
  Space._();
  static const double xs = 4,
      sm = 8,
      md = 12,
      lg = 16,
      xl = 24,
      xxl = 32,
      huge = 48;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  SizeClass get sizeClass => sizeClassFor(screenWidth);

  bool get isCompact => sizeClass == SizeClass.compact;

  /// True for >= 840 px (expanded and large).
  bool get isWide => screenWidth >= 840;

  double get pagePadding => switch (sizeClass) {
    SizeClass.compact => Space.lg,
    SizeClass.medium => Space.xl,
    _ => Space.xxl,
  };
}

SizeClass sizeClassFor(double width) {
  if (width < 600) return SizeClass.compact;
  if (width < 840) return SizeClass.medium;
  if (width < 1200) return SizeClass.expanded;
  return SizeClass.large;
}

/// Centres content, caps its width and applies the responsive page padding.
class AppPage extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool scroll;

  const AppPage({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.scroll = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pagePadding;
    final body = Padding(
      padding: EdgeInsets.symmetric(horizontal: p),
      child: child,
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: scroll ? SingleChildScrollView(child: body) : body,
      ),
    );
  }
}

/// Height of the bottom navigation bar plus safe area; use as bottom padding
/// for scrollables so content is never hidden under it.
double bottomNavClearance(BuildContext context) => context.isWide
    ? Space.lg
    : kBottomNavigationBarHeight +
          MediaQuery.paddingOf(context).bottom +
          Space.lg;
