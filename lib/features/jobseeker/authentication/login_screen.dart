/// Sign in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../routing/router.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
      await ref.read(authControllerProvider.notifier).login(
            email: _email.text.trim(),
            password: _password.text,
          );
      // The router's redirect takes it from here.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // The server's own sentence. An unknown address and a wrong password
        // both answer 401 with an identical body, and nothing here may tell
        // them apart — that identity is what stops the form being an
        // enumeration oracle.
        _error = e.message;
        _fieldErrors = e.fieldErrors;
      });
      _form.currentState!.validate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The second door. Sends the reader to the code screen with their address.
  void _emailMeACode() {
    final email = _email.text.trim();
    context.push(Routes.loginCode, extra: email);
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandingProvider).valueOrNull;

    return Scaffold(
      backgroundColor: C.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Sp.x5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: Sp.x5),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: C.brand500,
                        borderRadius: BorderRadius.circular(R.lg),
                      ),
                      child: const Icon(Icons.work_rounded,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: Sp.x4),
                    Text(
                      'Sign in to ${brand?.name ?? 'JobPortal'}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: Sp.x2),
                    Text(
                      'Find your next role and track every application in one place.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: Sp.x6),

                    if (_error != null) ...[
                      InlineError(_error!),
                      const SizedBox(height: Sp.x4),
                    ],

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
                      ),
                      validator: (v) {
                        if (_fieldErrors['email'] != null) return _fieldErrors['email'];
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: Sp.x4),

                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
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
                        if (v == null || v.isEmpty) return 'Enter your password.';
                        return null;
                      },
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push(Routes.forgotPassword),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: Sp.x2),

                    PrimaryButton(
                      label: 'Sign in',
                      busy: _busy,
                      onPressed: _submit,
                    ),

                    const SizedBox(height: Sp.x5),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Sp.x3),
                          child: Text(
                            'or',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: Sp.x5),

                    // The second door, and a genuinely good one on a phone: the
                    // code arrives in the mail app on the same device. It is
                    // also the re-auth path when a 12-hour session ends, since
                    // there is no refresh token (MOB-B-001).
                    SizedBox(
                      height: Touch.primary + 4,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _emailMeACode,
                        icon: const Icon(Icons.mail_outline_rounded, size: 18),
                        label: const Text('Email me a sign-in code'),
                      ),
                    ),

                    const SizedBox(height: Sp.x6),
                    // Wrap, not Row: at 390px the label and the button together
                    // need more than the 342px of content width, and a Row
                    // overflowed by 48px. Wrapping to a second line is the
                    // right answer on a narrow phone.
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'New here?',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => context.push(Routes.register),
                          child: const Text('Create an account'),
                        ),
                      ],
                    ),
                    const SizedBox(height: Sp.x4),
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
