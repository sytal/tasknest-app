import 'package:flutter/material.dart';

/// A small circular avatar showing a member's initials, used wherever we
/// need a lightweight visual stand-in for a user without fetching an image
/// (e.g. overlapping member avatar stacks on project cards).
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;

  const InitialsAvatar({super.key, required this.name, this.size = 24});

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color _bgColor(ColorScheme scheme) {
    // Derive a stable but varied tint from the name so avatars in a stack
    // are visually distinguishable while staying within the brand palette.
    final hash = name.codeUnits.fold<int>(0, (acc, c) => acc + c);
    final hues = [scheme.primary, scheme.secondary, scheme.tertiary];
    return hues[hash % hues.length];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = _bgColor(scheme);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: scheme.surface, width: 1.5),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: scheme.brightness == Brightness.dark
              ? scheme.onPrimary
              : Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Overlapping stack of [InitialsAvatar]s, capped at [max] visible avatars
/// with a "+N" overflow indicator.
class AvatarStack extends StatelessWidget {
  final List<String> names;
  final int max;
  final double size;

  const AvatarStack({
    super.key,
    required this.names,
    this.max = 3,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final visible = names.take(max).toList();
    final overflow = names.length - visible.length;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: size,
      width:
          size +
          (visible.length - 1) * size * 0.65 +
          (overflow > 0 ? size * 0.65 : 0),
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * size * 0.65,
              child: InitialsAvatar(name: visible[i], size: size),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * size * 0.65,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.surface, width: 1.5),
                ),
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
