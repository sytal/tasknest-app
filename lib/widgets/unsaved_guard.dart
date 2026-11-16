import 'package:flutter/material.dart';

/// Blocks back navigation while [dirty] and asks the user to confirm
/// discarding unsaved changes.
class UnsavedChangesGuard extends StatelessWidget {
  final bool dirty;
  final Widget child;

  const UnsavedChangesGuard({
    super.key,
    required this.dirty,
    required this.child,
  });

  static Future<bool> confirmDiscard(BuildContext context) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await confirmDiscard(context)) nav.pop();
      },
      child: child,
    );
  }
}
