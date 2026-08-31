/// Create a seeker account.
///
/// The server narrows anything that is not seeker or recruiter to **seeker**
/// rather than erroring, so a posted `"admin"` mints an ordinary account. This
/// app only ever sends seeker.
///
/// **Registration does not verify the address.** `email_verified_at` stays NULL
/// and the profile shows "Unverified" with the remedy beside it — filling in a
/// form proves nothing about the address in it. Signing in with an emailed code
/// is what stamps it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../routing/router.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
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
      await ref.read(authControllerProvider.notifier).register(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            passwordConfirm: _confirm.text,
            phone: _phone.text.trim(),
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // The server's own wording. app/main.py translates pydantic's text into
        // product copy at the boundary and keeps `loc` intact so each message
        // lands on its field; paraphrasing here would undo that.
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
    return Scaffold(
      backgroundColor: C.surface,
      appBar: AppBar(title: const Text('Create your account')),
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
                  Text(
                    'Join in under a minute',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Sp.x2),
                  Text(
                    'You can add your CV and the rest of your profile afterwards.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Sp.x5),

                  if (_error != null) ...[
                    InlineError(_error!),
                    const SizedBox(height: Sp.x4),
                  ],

                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 19),
                    ),
                    validator: (v) =>
                        _fieldErrors['full_name'] ??
                        ((v == null || v.trim().isEmpty)
                            ? 'Enter your name.'
                            : null),
                  ),
                  const SizedBox(height: Sp.x4),

                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
                    ),
                    validator: (v) =>
                        _fieldErrors['email'] ??
                        ((v == null || v.trim().isEmpty)
                            ? 'Enter your email address.'
                            : null),
                  ),
                  const SizedBox(height: Sp.x4),

                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: 'Mobile number (optional)',
                      prefixIcon: Icon(Icons.phone_outlined, size: 19),
                      // Deliberately no "we will verify this". Mobile number
                      // verification was deferred by the owner and there is no
                      // sender behind it — promising it would be a lie.
                      helperText: 'Recruiters use this to contact you.',
                    ),
                    validator: (v) => _fieldErrors['phone'],
                  ),
                  const SizedBox(height: Sp.x4),

                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Password',
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
                      if (v == null || v.isEmpty) return 'Choose a password.';
                      // The floor only. The real policy — Have I Been Pwned,
                      // own name/email, keyboard runs — is the server's, and
                      // restating it here would go stale the moment it changes.
                      if (v.length < 8) return 'Use at least 8 characters.';
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
                      labelText: 'Confirm password',
                      prefixIcon: Icon(Icons.lock_outline_rounded, size: 19),
                    ),
                    validator: (v) {
                      if (_fieldErrors['password_confirm'] != null) {
                        return _fieldErrors['password_confirm'];
                      }
                      if (v != _password.text) {
                        return 'The passwords do not match.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Sp.x6),

                  // The CTA colour: this is the single most important action on
                  // the screen. Using it anywhere else destroys its meaning.
                  PrimaryButton(
                    label: 'Create account',
                    busy: _busy,
                    cta: true,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: Sp.x4),

                  // Wrap for the same reason as the login screen: this pair
                  // overflowed a Row by 122px at 390px wide.
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.go(Routes.login),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
