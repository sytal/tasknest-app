import 'dart:ui';

import 'package:flutter/material.dart';

/// A reusable frosted-glass ("glassmorphism") surface: a blurred backdrop
/// behind a semi-transparent tinted container, clipped to a rounded shape.
///
/// Used sparingly across the app (dashboard header quick-stats, bottom nav
/// bar) rather than everywhere, so the effect reads as a deliberate premium
/// touch instead of visual noise. Keep usage on small/fixed-size surfaces —
/// never wrap large scrolling content in a [BackdropFilter], since blurring
/// is comparatively expensive per frame.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color tintColor;
  final double tintOpacity;
  final Border? border;
  final EdgeInsetsGeometry? padding;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blurSigma = 18,
    required this.tintColor,
    this.tintOpacity = 0.14,
    this.border,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tintColor.withValues(alpha: tintOpacity),
            borderRadius: borderRadius,
            border: border ??
                Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Simple fade + slight rise-in entrance animation for cards/content that
/// appears once data has loaded, so the dashboard feels crafted rather than
/// static. Lightweight (no AnimationController needed) via
/// [TweenAnimationBuilder].
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      builder: (context, value, child) {
        // Hold at 0 during the delay window, then ease in.
        final delayFraction = delay.inMilliseconds /
            (duration + delay).inMilliseconds.clamp(1, double.infinity);
        final adjusted = delayFraction >= 1
            ? value
            : ((value - delayFraction) / (1 - delayFraction)).clamp(0.0, 1.0);
        return Opacity(
          opacity: adjusted,
          child: Transform.translate(
            offset: Offset(0, (1 - adjusted) * 12),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
