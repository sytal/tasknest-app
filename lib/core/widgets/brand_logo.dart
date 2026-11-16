import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';

/// Full logo (mark + wordmark + tagline) or just the mark.
class BrandLogo extends StatelessWidget {
  final double width;
  final bool markOnly;
  final double opacity;

  const BrandLogo({
    super.key,
    this.width = 220,
    this.markOnly = false,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final img = markOnly
        ? Image.asset(
            'assets/brand/logo-mark.png',
            width: width,
            fit: BoxFit.contain,
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/brand/tasknest-logo.jpeg',
              width: width,
              fit: BoxFit.contain,
            ),
          );
    return Semantics(
      label: 'TaskNest logo',
      image: true,
      child: ExcludeSemantics(
        child: Opacity(opacity: opacity, child: img),
      ),
    );
  }
}

/// Small mark plus "Task" (navy) "Nest" (orange) wordmark for nav headers.
class BrandWordmark extends StatelessWidget {
  final double markSize;
  final bool onDark;
  const BrandWordmark({super.key, this.markSize = 32, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final task = onDark || Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : AppColors.navy;
    final style = Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w800);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogo(width: markSize, markOnly: true),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Task',
                  style: style?.copyWith(color: task),
                ),
                TextSpan(
                  text: 'Nest',
                  style: style?.copyWith(color: AppColors.orange),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Friendly empty state with the faded mark, a sentence and an optional action.
class EmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(width: 96, markOnly: true, opacity: 0.45),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Soft brand backdrop: a gentle gradient with faint orange/leaf shapes so
/// large surfaces feel warm instead of flat.
class BrandBackground extends StatelessWidget {
  final Widget child;
  const BrandBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [AppColors.navyDark, AppColors.surfaceDark]
              : const [AppColors.cream, AppColors.cream200],
        ),
      ),
      child: CustomPaint(painter: _ShapesPainter(dark), child: child),
    );
  }
}

class _ShapesPainter extends CustomPainter {
  final bool dark;
  _ShapesPainter(this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final a = dark ? 0.07 : 0.10;
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.08),
      size.shortestSide * 0.35,
      Paint()..color = AppColors.orange.withValues(alpha: a),
    );
    canvas.drawCircle(
      Offset(size.width * 0.02, size.height * 0.92),
      size.shortestSide * 0.42,
      Paint()..color = AppColors.leaf.withValues(alpha: a * 0.8),
    );
  }

  @override
  bool shouldRepaint(_ShapesPainter old) => old.dark != dark;
}
