import 'package:flutter/material.dart';
import '../models/task.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  Color _color() {
    switch (status) {
      case StatusOptions.inProgress:
        return Colors.orange;
      case StatusOptions.done:
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Chip(
      label: Text(
        StatusOptions.label(status),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class PriorityChip extends StatelessWidget {
  final String priority;
  const PriorityChip({super.key, required this.priority});

  Color _color() {
    switch (priority) {
      case PriorityOptions.high:
        return Colors.red;
      case PriorityOptions.low:
        return Colors.grey;
      default:
        return Colors.amber.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Chip(
      label: Text(
        PriorityOptions.label(priority),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
