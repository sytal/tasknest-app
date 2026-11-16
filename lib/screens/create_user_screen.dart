import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session.dart';

import '../services/api_client.dart';
import '../services/user_service.dart';
import '../utils/validators.dart';
import '../widgets/unsaved_guard.dart';

/// Lets a director/ceo create a brand-new user account (name, email,
/// password, role, designation) via `POST /api/users`. Reachable from the
/// Manage Members screen ("create a new user") and from the Profile screen
/// for director/ceo accounts.
class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _designationController = TextEditingController();
  String _role = 'member';
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = {};
  bool _obscure = true;

  bool get _isDirty =>
      _nameController.text.isNotEmpty ||
      _emailController.text.isNotEmpty ||
      _passwordController.text.isNotEmpty ||
      _designationController.text.isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = {};
    });
    try {
      final user = await UserService.create(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _role,
        designation: context.read<Session>().currentUser?.role == 'ceo'
            ? _designationController.text.trim()
            : '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} created successfully.')),
        );
        Navigator.of(context).pop(user);
      }
    } on ApiException catch (e) {
      setState(() {
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
      });
      _formKey.currentState!.validate();
    } catch (_) {
      setState(() => _error = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      dirty: _isDirty && !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Create User')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add a new team member',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create a login for a new director, CEO, or member. '
                      'They can sign in immediately with the password below.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      maxLength: Validators.nameMax,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) =>
                          Validators.requiredMax(
                            v,
                            'Name',
                            Validators.nameMax,
                          ) ??
                          _fieldErrors['name'],
                      onChanged: (_) => _fieldErrors.remove('name'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) =>
                          Validators.email(v) ?? _fieldErrors['email'],
                      onChanged: (_) => _fieldErrors.remove('email'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Temporary password',
                        helperText:
                            'At least ${Validators.passwordMin} characters',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      autofillHints: const [AutofillHints.newPassword],
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) =>
                          Validators.newPassword(v) ?? _fieldErrors['password'],
                      onChanged: (_) => _fieldErrors.remove('password'),
                    ),
                    if (context.read<Session>().currentUser?.role == 'ceo') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _designationController,
                        decoration: const InputDecoration(
                          labelText: 'Designation (optional)',
                          prefixIcon: Icon(Icons.work_outline),
                        ),
                        maxLength: Validators.nameMax,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => Validators.maxLen(
                          v,
                          Validators.nameMax,
                          'Designation',
                        ),
                      ),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'member',
                          child: Text(
                            'Member',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'director',
                          child: Text(
                            'Director',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ceo',
                          child: Text('CEO', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (v) => setState(() => _role = v ?? _role),
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        helperText: 'Controls what this account can see and do',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create User'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
