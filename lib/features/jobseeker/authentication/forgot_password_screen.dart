/// Request a password reset link.
///
/// **Identical answer for every address**, same rule as `/login-code`: a
/// registered address, an unregistered one and a malformed one all get the same
/// sentence and the same 200. The screen shows what the server said and stops
/// there — it must never confirm or deny that an account exists.
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

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _sent;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final message = await ref.read(authRepositoryProvider).forgotPassword(email);
      if (!mounted) return;
      // Verbatim, and the same for every outcome.
      setState(() => _sent = message.detail);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.surface,
      appBar: AppBar(title: const Text('Reset your password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Sp.x5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_sent != null) ...[
                  InlineNotice(_sent!, icon: Icons.mark_email_read_outlined),
                  const SizedBox(height: Sp.x5),
                  Text(
                    'Open the link on this device and you will be able to set a '
                    'new password.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Sp.x5),
                  OutlinedButton(
                    onPressed: () => context.go(Routes.login),
                    child: const Text('Back to sign in'),
                  ),
                  const SizedBox(height: Sp.x4),
                  Center(
                    child: TextButton(
                      onPressed: () => context.pushReplacement(
                        Routes.loginCode,
                        extra: _email.text.trim(),
                      ),
                      child: const Text('Or sign in with an emailed code instead'),
                    ),
                  ),
                ] else ...[
                  Text(
                    'We will email you a link',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Sp.x2),
                  Text(
                    'Enter the address you signed up with.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Sp.x5),

                  if (_error != null) ...[
                    InlineError(_error!),
                    const SizedBox(height: Sp.x4),
                  ],

                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    autocorrect: false,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
                    ),
                  ),
                  const SizedBox(height: Sp.x5),

                  PrimaryButton(
                    label: 'Send reset link',
                    busy: _busy,
                    onPressed: _submit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
