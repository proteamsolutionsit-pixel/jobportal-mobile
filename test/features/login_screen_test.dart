/// Widget tests for the sign-in screens.
///
/// The one that matters most is the enumeration guard: **`/login-code` must
/// render the same thing for a registered address and an unregistered one.**
/// The server spent measured effort making those indistinguishable — equalising
/// timing against a dummy bcrypt hash after finding a real oracle — and a
/// client that says "we've sent you a code" versus "no account found" hands the
/// whole thing back.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:jobportal_mobile/core/network/api_client.dart';
import 'package:jobportal_mobile/core/providers.dart';
import 'package:jobportal_mobile/core/theme/app_theme.dart';
import 'package:jobportal_mobile/features/jobseeker/authentication/login_code_screen.dart';
import 'package:jobportal_mobile/features/jobseeker/authentication/login_screen.dart';
import 'package:cookie_jar/cookie_jar.dart';

const _base = 'http://127.0.0.1:8000';

/// The identical sentence the server returns for every outcome on /login-code.
const _oneAnswer =
    'If that address has an account, a sign-in code is on its way.';

({Widget widget, DioAdapter adapter}) harness(Widget screen) {
  final dio = Dio(BaseOptions(
    baseUrl: _base,
    validateStatus: (s) => s != null && s >= 200 && s < 300,
  ));
  final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
  final client = ApiClient.create(dio: dio, cookieJar: CookieJar());
  dio.httpClientAdapter = adapter;

  return (
    widget: ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(client)],
      child: MaterialApp(theme: AppTheme.light, home: screen),
    ),
    adapter: adapter,
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('offers both doors', (tester) async {
      final h = harness(const LoginScreen());
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Email me a sign-in code'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('will not submit an empty form', (tester) async {
      final h = harness(const LoginScreen());
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('shows the server\'s 401 sentence, not one of ours',
        (tester) async {
      // Unknown address and wrong password answer identically. The screen
      // renders whatever the server said, so it cannot tell them apart either.
      const serverSaid = 'Those details do not match an account.';
      final h = harness(const LoginScreen());
      h.adapter.onPost(
        '/api/auth/login',
        (s) => s.reply(401, {'detail': serverSaid}),
      );

      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
      await tester.enterText(find.byType(TextFormField).last, 'wrong-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text(serverSaid), findsOneWidget);
    });
  });

  group('LoginCodeScreen — the enumeration guard', () {
    Future<void> requestCodeFor(WidgetTester tester, String email) async {
      await tester.enterText(find.byType(TextField).first, email);
      await tester.tap(find.widgetWithText(FilledButton, 'Email me a code'));
      await tester.pumpAndSettle();
    }

    testWidgets('a registered address gets the server sentence', (tester) async {
      final h = harness(const LoginCodeScreen(email: ''));
      h.adapter.onPost(
        '/api/auth/login-code',
        (s) => s.reply(200, {'detail': _oneAnswer}),
      );

      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      await requestCodeFor(tester, 'registered@example.com');

      expect(find.text(_oneAnswer), findsOneWidget);
      expect(find.text('Enter your code'), findsOneWidget);
    });

    testWidgets('an UNREGISTERED address renders exactly the same', (tester) async {
      // Same 200, same sentence, same next screen. This is the whole point:
      // the client must not be able to tell, because then neither can a
      // stranger probing addresses.
      final h = harness(const LoginCodeScreen(email: ''));
      h.adapter.onPost(
        '/api/auth/login-code',
        (s) => s.reply(200, {'detail': _oneAnswer}),
      );

      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      await requestCodeFor(tester, 'nobody@example.com');

      expect(find.text(_oneAnswer), findsOneWidget);
      expect(find.text('Enter your code'), findsOneWidget);

      // And nothing anywhere on screen hints either way.
      expect(find.textContaining('not found'), findsNothing);
      expect(find.textContaining('no account'), findsNothing);
      expect(find.textContaining('does not exist'), findsNothing);
    });

    testWidgets('states that three wrong guesses kill the code', (tester) async {
      // Three failures CONSUME the code — refusing a fourth while leaving the
      // code alive would be a rate limit, not a cap. Copy saying "try again"
      // leaves people entering a dead code.
      final h = harness(const LoginCodeScreen(email: 'a@b.com'));
      h.adapter.onPost(
        '/api/auth/login-code',
        (s) => s.reply(200, {'detail': _oneAnswer}),
      );

      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Email me a code'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('three incorrect attempts'),
        findsOneWidget,
        reason: 'the cap must be stated before people hit it',
      );
      expect(find.textContaining('need a new one'), findsOneWidget);
    });

    testWidgets('a short code is refused before a request is made',
        (tester) async {
      final h = harness(const LoginCodeScreen(email: 'a@b.com'));
      h.adapter.onPost(
        '/api/auth/login-code',
        (s) => s.reply(200, {'detail': _oneAnswer}),
      );

      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Email me a code'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.textContaining('six-digit code'), findsWidgets);
    });

    testWidgets('the resend button goes on cooldown — one code a minute',
        (tester) async {
      final h = harness(const LoginCodeScreen(email: 'a@b.com'));
      h.adapter.onPost(
        '/api/auth/login-code',
        (s) => s.reply(200, {'detail': _oneAnswer}),
      );

      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Email me a code'));

      // Pumped by hand rather than pumpAndSettle: the cooldown is a PERIODIC
      // timer, so a settle would never return. Two pumps let the request's
      // future complete and the rebuild land.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Stated rather than discovered by being refused.
      expect(find.textContaining('Send another code in'), findsOneWidget);

      // Dispose the screen so its periodic timer is cancelled — otherwise the
      // test ends with a pending timer and fails for an unrelated reason.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
