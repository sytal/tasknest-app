import 'package:flutter/material.dart';

import '../layout/responsive.dart';
import '../theme/brand_colors.dart';

enum AppButtonKind { primary, secondary, text, danger }

/// One button for the whole app: consistent height, radius, loading state.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonKind kind;
  final bool loading;
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = AppButtonKind.primary,
    this.loading = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !loading;
    final VoidCallback? tap = enabled ? onPressed : null;
    final child = loading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    final Widget btn = switch (kind) {
      AppButtonKind.primary || AppButtonKind.danger => FilledButton.icon(
        onPressed: tap,
        style: kind == AppButtonKind.danger
            ? FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              )
            : null,
        icon: icon == null || loading ? const SizedBox.shrink() : Icon(icon),
        label: child,
      ),
      AppButtonKind.secondary => OutlinedButton.icon(
        onPressed: tap,
        icon: icon == null || loading ? const SizedBox.shrink() : Icon(icon),
        label: child,
      ),
      AppButtonKind.text => TextButton.icon(
        onPressed: tap,
        icon: icon == null || loading ? const SizedBox.shrink() : Icon(icon),
        label: child,
      ),
    };
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Text field with the app's label/hint/error conventions.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? errorText;
  final bool obscure;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final bool autofocus;

  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.obscure = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.suffix,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofocus: autofocus,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        suffixIcon: suffix,
      ),
    );
  }
}

/// Confirmation dialog; resolves true when the user confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        AppButton(
          label: 'Cancel',
          kind: AppButtonKind.text,
          onPressed: () => Navigator.pop(d, false),
        ),
        AppButton(
          label: confirmLabel,
          kind: destructive ? AppButtonKind.danger : AppButtonKind.primary,
          onPressed: () => Navigator.pop(d, true),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Page scaffold: app bar + centred, width-capped, responsively padded body.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final double maxWidth;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.maxWidth = 1200,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    floatingActionButton: floatingActionButton,
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: body,
      ),
    ),
  );
}

/// Avatar: network photo when present, otherwise initials on a stable
/// brand-palette colour. Used for every user representation.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;

  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
  });

  String get _initials {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (p.isEmpty) return '?';
    if (p.length == 1) return p.first[0].toUpperCase();
    return (p.first[0] + p.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.avatarPalette[AppColors.avatarIndex(name)];
    final has = imageUrl != null && imageUrl!.isNotEmpty;
    return Semantics(
      label: 'Avatar of $name',
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: bg,
        backgroundImage: has ? NetworkImage(imageUrl!) : null,
        onBackgroundImageError: has ? (_, _) {} : null,
        child: has
            ? null
            : Text(
                _initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// Responsive two-pane: side by side when wide, otherwise stacked.
class TwoPane extends StatelessWidget {
  final Widget primary;
  final Widget secondary;
  final double breakpoint;
  final int primaryFlex;
  final int secondaryFlex;

  const TwoPane({
    super.key,
    required this.primary,
    required this.secondary,
    this.breakpoint = 840,
    this.primaryFlex = 3,
    this.secondaryFlex = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (context.screenWidth >= breakpoint) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: primaryFlex, child: primary),
          const SizedBox(width: Space.lg),
          Expanded(flex: secondaryFlex, child: secondary),
        ],
      );
    }
    return Column(children: [primary, secondary]);
  }
}
