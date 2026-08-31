/// Change password — and the screen `must_set_password` routes to.
///
/// When it is reached because `must_set_password` is set, there is deliberately
/// **no way out except completing it**. That flag is enforced in the auth
/// dependency, so every other screen's writes would be refused anyway; letting
/// somebody past it would just produce a shell where nothing works.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import 'auth_controller.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });

    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: _current.text,
            password: _password.text,
            passwordConfirm: _confirm.text,
          );
      // Picks up must_set_password clearing, which releases the redirect.
      await ref.read(authControllerProvider.notifier).refresh();
      if (!mounted) return;
      showSnack(context, 'Password updated.');
      if (context.canPop()) context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.fieldErrors.isEmpty ? e.message : null;
        _fieldErrors = e.fieldErrors;
      });
      _form.currentState!.validate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final forced = auth is SignedIn && auth.mustSetPassword;

    return PopScope(
      canPop: !forced,
      child: Scaffold(
        backgroundColor: C.surface,
        appBar: AppBar(
          title: Text(forced ? 'Set a new password' : 'Change password'),
          automaticallyImplyLeading: !forced,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Sp.x5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (forced) ...[
                      const InlineNotice(
                        'Before you continue, please choose a password of your own.',
                        icon: Icons.lock_reset_rounded,
                      ),
                      const SizedBox(height: Sp.x5),
                    ],
                    if (_error != null) ...[
                      InlineError(_error!),
                      const SizedBox(height: Sp.x4),
                    ],

                    TextFormField(
                      controller: _current,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 19),
                      ),
                      validator: (v) =>
                          _fieldErrors['current_password'] ??
                          ((v == null || v.isEmpty)
                              ? 'Enter your current password.'
                              : null),
                    ),
                    const SizedBox(height: Sp.x4),

                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                        helperText: 'At least 8 characters.',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (_fieldErrors['password'] != null) {
                          return _fieldErrors['password'];
                        }
                        if (v == null || v.length < 8) {
                          return 'Use at least 8 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: Sp.x4),

                    TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 19),
                      ),
                      validator: (v) =>
                          _fieldErrors['password_confirm'] ??
                          (v != _password.text ? 'The passwords do not match.' : null),
                    ),
                    const SizedBox(height: Sp.x6),

                    PrimaryButton(
                      label: 'Update password',
                      busy: _busy,
                      onPressed: _submit,
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
