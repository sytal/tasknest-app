import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/collab_service.dart';
import '../services/session.dart';
import '../utils/feedback.dart';
import '../utils/validators.dart';

/// Shared centered, max-width form scaffold for the small account screens.
class _FormPage extends StatelessWidget {
  final String title;
  final Widget child;
  const _FormPage({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child),
      ),
    ),
  );
}

class _SubmitButton extends StatelessWidget {
  final bool busy;
  final String label;
  final VoidCallback onPressed;
  const _SubmitButton({required this.busy, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label),
  );
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: context.read<Session>().currentUser?.name);
  late final _designation = TextEditingController(text: context.read<Session>().currentUser?.designation);
  Map<String, String> _server = {};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _designation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _server = {});
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final d = _designation.text.trim();
      final user = await AccountService.updateProfile(_name.text.trim(), d.isEmpty ? null : d);
      if (!mounted) return;
      context.read<Session>().updateUser(user);
      showSnack(context, 'Profile updated');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _server = e.fieldErrors);
      if (e.fieldErrors.isEmpty && mounted) showSnack(context, e.message);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _FormPage(
    title: 'Edit profile',
    child: Form(
      key: _key,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          controller: _name,
          autofocus: true,
          maxLength: Validators.nameMax,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(labelText: 'Name', errorText: _server['name']),
          onChanged: (_) => _server.isEmpty ? null : setState(() => _server = {}),
          validator: (v) => Validators.requiredMax(v, 'Name', Validators.nameMax),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _designation,
          maxLength: Validators.nameMax,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Designation (optional)', errorText: _server['designation']),
          validator: (v) => Validators.maxLen(v, Validators.nameMax, 'Designation'),
        ),
        const SizedBox(height: 16),
        _SubmitButton(busy: _busy, label: 'Save', onPressed: _save),
      ]),
    ),
  );
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _key = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, String> _server = {};
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _server = {});
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AccountService.changePassword(_current.text, _next.text, _confirm.text);
      if (!mounted) return;
      showSnack(context, 'Password updated. Other devices were signed out.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _server = e.fieldErrors);
      if (e.fieldErrors.isEmpty && mounted) showSnack(context, e.message);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _FormPage(
    title: 'Change password',
    child: Form(
      key: _key,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          controller: _current,
          obscureText: true,
          autofocus: true,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(labelText: 'Current password', errorText: _server['current_password']),
          validator: (v) => Validators.required(v, 'Current password'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _next,
          obscureText: true,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(labelText: 'New password', helperText: 'At least ${Validators.passwordMin} characters', errorText: _server['password']),
          validator: Validators.newPassword,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirm,
          obscureText: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Confirm new password'),
          validator: (v) => v != _next.text ? 'Passwords do not match' : null,
          onFieldSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 16),
        _SubmitButton(busy: _busy, label: 'Update password', onPressed: _save),
      ]),
    ),
  );
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AccountService.forgotPassword(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _FormPage(
    title: 'Forgot password',
    child: Form(
      key: _key,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Enter your account email. If it is registered, we will send a reset link.'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(labelText: 'Email', errorText: _error),
          validator: Validators.email,
          onFieldSubmitted: (_) => _send(),
        ),
        const SizedBox(height: 16),
        if (_sent)
          const Text('If that email is registered, a reset link has been sent.')
        else
          _SubmitButton(busy: _busy, label: 'Send reset link', onPressed: _send),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResetPasswordScreen())),
          child: const Text('I have a reset token'),
        ),
      ]),
    ),
  );
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _token, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AccountService.resetPassword(_email.text.trim(), _token.text.trim(), _password.text, _confirm.text);
      if (!mounted) return;
      showSnack(context, 'Password reset. You can now sign in.');
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _FormPage(
    title: 'Reset password',
    child: Form(
      key: _key,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), validator: Validators.email),
        const SizedBox(height: 12),
        TextFormField(controller: _token, decoration: const InputDecoration(labelText: 'Reset token'), validator: (v) => Validators.required(v, 'Token')),
        const SizedBox(height: 12),
        TextFormField(controller: _password, obscureText: true, autofillHints: const [AutofillHints.newPassword], decoration: const InputDecoration(labelText: 'New password'), validator: Validators.newPassword),
        const SizedBox(height: 12),
        TextFormField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password'), validator: (v) => v != _password.text ? 'Passwords do not match' : null),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 16),
        _SubmitButton(busy: _busy, label: 'Reset password', onPressed: _reset),
      ]),
    ),
  );
}
