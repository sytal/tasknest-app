import 'package:flutter/material.dart';

import '../core/theme/brand_colors.dart';
import '../models/task.dart';

/// Shared pill-style badge used by [StatusChip] and [PriorityChip].
class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Pill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    // Lift the text colour toward white (dark theme) or black (light theme)
    // so small pills keep >= 4.5:1 contrast on their tinted background.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = Color.lerp(
      color,
      isDark ? Colors.white : Colors.black,
      isDark ? 0.6 : 0.4,
    )!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class OverdueChip extends StatelessWidget {
  const OverdueChip({super.key});

  @override
  Widget build(BuildContext context) => const _Pill(
    label: 'Overdue',
    color: AppColors.danger,
    icon: Icons.warning_amber_rounded,
  );
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  static Color colorFor(String status) {
    switch (status) {
      case StatusOptions.inProgress:
        return AppColors.amber;
      case StatusOptions.done:
        return AppColors.leaf;
      default:
        return AppColors.navy; // navy tint
    }
  }

  static IconData iconFor(String status) {
    switch (status) {
      case StatusOptions.inProgress:
        return Icons.autorenew;
      case StatusOptions.done:
        return Icons.check_circle;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: StatusOptions.label(status),
      color: colorFor(status),
      icon: iconFor(status),
    );
  }
}

class PriorityChip extends StatelessWidget {
  final String priority;
  const PriorityChip({super.key, required this.priority});

  static Color colorFor(String priority) {
    switch (priority) {
      case PriorityOptions.high:
        return AppColors.orange;
      case PriorityOptions.low:
        return AppColors.leaf;
      default:
        return AppColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: PriorityOptions.label(priority),
      color: colorFor(priority),
      icon: Icons.flag,
    );
  }
}

/// Simple colored-circle avatar with initials, used in place of a real
/// profile photo for task assignees.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final String? avatarUrl;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.radius = 12,
    this.avatarUrl,
  });

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Color _colorFor(String seed) {
    return AppColors.avatarPalette[AppColors.avatarIndex(seed)];
  }

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }
    final color = _colorFor(name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
