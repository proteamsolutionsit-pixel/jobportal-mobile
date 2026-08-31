/// Signing in with an emailed six-digit code.
///
/// ## The rule this screen exists to not break
///
/// **`POST /api/auth/login-code` gives one answer, always** — the same sentence
/// and the same 200 for a registered address, an unregistered one, a malformed
/// one, a throttled caller and an account already over its cap. A throttled
/// request is deliberately **not** a 429, because *a different status for the
/// same question is itself an answer*.
///
/// That identity was expensive. Timing was equalised against a module-level
/// dummy bcrypt hash after a **measured** oracle was found: declining cost 55 ms
/// where issuing and no-such-account both cost ~900 ms, so probing one address
/// six times in an hour and watching the sixth reply come back fast answered
/// "this account exists" — through the very limit meant to stop the probing.
///
/// So this screen shows the server's sentence and advances **whatever
/// happened**. It must never say "we've sent a code to that address" or "no
/// account found"; both would rebuild the oracle on the client.
///
/// ## And the one thing the copy must say
///
/// **Three wrong guesses consume the code.** Refusing a fourth attempt while
/// leaving the code alive would be a rate limit, not a cap — so after three, a
/// *new code* is needed, not a wait. Copy that says "try again" leaves people
/// sitting on a dead code.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import 'auth_controller.dart';

class LoginCodeScreen extends ConsumerStatefulWidget {
  const LoginCodeScreen({super.key, required this.email});
  final String email;

  @override
  ConsumerState<LoginCodeScreen> createState() => _LoginCodeScreenState();
}

class _LoginCodeScreenState extends ConsumerState<LoginCodeScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();

  bool _sent = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  /// One code a minute is a server-side cap, so the button says so rather than
  /// letting people discover it by being refused.
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _email.text = widget.email;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _requestCode() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      final message = await ref.read(authRepositoryProvider).requestLoginCode(email);
      if (!mounted) return;
      setState(() {
        _sent = true;
        // The server's own sentence, verbatim. It is deliberately the same for
        // every outcome; do not add to it, and do not branch on it.
        _notice = message.detail;
      });
      _startCooldown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the six-digit code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).verifyLoginCode(
            email: _email.text.trim(),
            code: code,
          );
      // The router redirects on the state change.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _code.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.surface,
      appBar: AppBar(title: const Text('Sign in by email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Sp.x5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _sent ? 'Enter your code' : 'We will email you a code',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: Sp.x2),
                Text(
                  _sent
                      ? 'It is six digits and is valid for 10 minutes.'
                      : 'No password needed — we send a six-digit code to your inbox.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Sp.x5),

                if (_error != null) ...[
                  InlineError(_error!),
                  const SizedBox(height: Sp.x4),
                ],
                if (_notice != null) ...[
                  InlineNotice(_notice!, icon: Icons.mark_email_read_outlined),
                  const SizedBox(height: Sp.x4),
                ],

                TextField(
                  controller: _email,
                  enabled: !_sent,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
                  ),
                ),
                const SizedBox(height: Sp.x4),

                if (_sent) ...[
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 26,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w700,
                      color: C.ink900,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '000000',
                      hintStyle: TextStyle(
                        fontSize: 26,
                        letterSpacing: 10,
                        color: C.ink400,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onSubmitted: (_) => _verify(),
                  ),
                  const SizedBox(height: Sp.x3),

                  // The cap, stated up front. Discovering it by being refused
                  // is how people end up entering a dead code repeatedly.
                  Container(
                    padding: const EdgeInsets.all(Sp.x3),
                    decoration: BoxDecoration(
                      color: C.warn50,
                      borderRadius: R.brMd,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 17, color: C.warn600),
                        const SizedBox(width: Sp.x2),
                        Expanded(
                          child: Text(
                            'After three incorrect attempts this code stops working '
                            'and you will need a new one.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: C.warn600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.x5),

                  PrimaryButton(
                    label: 'Sign in',
                    busy: _busy,
                    onPressed: _verify,
                  ),
                  const SizedBox(height: Sp.x3),

                  Center(
                    child: TextButton(
                      onPressed: _cooldown > 0 || _busy ? null : _requestCode,
                      child: Text(
                        _cooldown > 0
                            ? 'Send another code in ${_cooldown}s'
                            : 'Send another code',
                      ),
                    ),
                  ),
                ] else
                  PrimaryButton(
                    label: 'Email me a code',
                    busy: _busy,
                    icon: Icons.send_rounded,
                    onPressed: _requestCode,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
