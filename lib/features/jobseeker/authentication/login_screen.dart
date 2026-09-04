/// Sign in.
///
/// The visual design carries the brand rather than sitting on a plain white
/// field: a brand-gradient sky, the web app's own city skyline behind it, and
/// the form on a raised card. The skyline is literally the same asset the web
/// footer uses — offices, which is where the jobs are — so the two products
/// share artwork instead of an approximation of it.
///
/// Everything below the decoration is unchanged in behaviour. In particular the
/// two doors, the identical answer for registered and unregistered addresses,
/// and every validator string stay exactly as they were; they are load-bearing
/// and covered by `test/features/login_screen_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    final text = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);

    // The banner is a fraction of the viewport rather than a fixed height, so a
    // small phone does not lose the whole form below the fold and a tablet does
    // not get a thin ribbon. Clamped because neither extreme reads well.
    final bannerHeight = (media.size.height * 0.34).clamp(200.0, 300.0);

    return Scaffold(
      backgroundColor: C.surfaceSunk,
      body: Stack(
        children: [
          _BrandBanner(height: bannerHeight),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x6),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: bannerHeight * 0.16),
                      _Wordmark(name: brand?.name ?? 'JobsFlood'),
                      SizedBox(height: bannerHeight * 0.14),
                      _FormCard(
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Sign in', style: text.headlineSmall),
                              const SizedBox(height: Sp.x1),
                              Text(
                                'Find your next role and track every '
                                'application in one place.',
                                style: text.bodySmall,
                              ),
                              const SizedBox(height: Sp.x5),
                              ..._fields(context),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Sp.x5),
                      _footer(context, text),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _fields(BuildContext context) => [
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
        PrimaryButton(label: 'Sign in', busy: _busy, onPressed: _submit),
        const SizedBox(height: Sp.x5),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.x3),
              child: Text('or', style: Theme.of(context).textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: Sp.x5),
        // The second door, and a genuinely good one on a phone: the code
        // arrives in the mail app on the same device. It is also the re-auth
        // path when a 12-hour session ends, since there is no refresh token
        // (MOB-B-001).
        SizedBox(
          height: Touch.primary + 4,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _emailMeACode,
            icon: const Icon(Icons.mail_outline_rounded, size: 18),
            label: const Text('Email me a sign-in code'),
          ),
        ),
      ];

  Widget _footer(BuildContext context, TextTheme text) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('New here?', style: text.bodyMedium),
          TextButton(
            onPressed: () => context.push(Routes.register),
            child: const Text('Create an account'),
          ),
        ],
      );
}

/// The gradient sky with the skyline sitting on its horizon.
class _BrandBanner extends StatelessWidget {
  const _BrandBanner({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // brand-700 -> 500 -> 400: the same ramp the web header uses,
                // dark enough at the top for white text to clear contrast.
                colors: [C.brand700, C.brand500, C.brand400],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // The web's own decorative wash, at low opacity so it reads as
          // texture rather than as a second image competing with the skyline.
          Opacity(
            opacity: 0.35,
            child: SvgPicture.asset(
              'assets/images/hero-wash.svg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SvgPicture.asset(
              'assets/images/skyline.svg',
              fit: BoxFit.fitWidth,
              alignment: Alignment.bottomCenter,
              // The asset is drawn for a light footer, so it needs to be lifted
              // to white here. Its own fade to transparent is preserved.
              colorFilter: const ColorFilter.mode(
                Color(0x40FFFFFF),
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo and product name, over the banner.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The mark is rendered directly, with no plate behind it.
        //
        // It is already a self-contained badge — a white disc with a blue ring
        // and transparent corners. Sitting it on a white rounded square put a
        // white circle inside a white box, which swallowed the ring and made
        // the whole thing read as a smudge. The shadow goes on the circle
        // itself so it lifts off the gradient without a second shape.
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x40101520),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/app-icon.png',
            fit: BoxFit.contain,
            // 512px source on an 88pt box: filtered down rather than letting
            // the default nearest-ish sampling alias the ring.
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(height: Sp.x3),
        Text(
          name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontFamily: Fonts.display,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: Sp.x1),
        Text(
          'Jobs that fit, without the noise',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xCCFFFFFF),
              ),
        ),
      ],
    );
  }
}

/// The raised sheet the form sits on.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.x5),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(R.lg + 4),
        border: Border.all(color: C.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A101520),
            blurRadius: 28,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
