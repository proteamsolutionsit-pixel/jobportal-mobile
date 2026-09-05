/// Sign in with Google, client side.
///
/// What is worth pinning here is NOT the happy path — a broken one is reported
/// within minutes. It is the three ways this becomes wrong while still looking
/// like a working button:
///
///   1. the button appears when the server has Google switched OFF, so it
///      cannot possibly work;
///   2. cancelling the picker is rendered as an error, so a deliberate act
///      reads as a fault;
///   3. the app decides for itself what a token means, instead of letting the
///      server verify it.
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:jobportal_mobile/core/auth/google_sign_in_service.dart';
import 'package:jobportal_mobile/core/network/api_client.dart';
import 'package:jobportal_mobile/core/providers.dart';
import 'package:jobportal_mobile/core/theme/app_theme.dart';
import 'package:jobportal_mobile/features/jobseeker/authentication/login_screen.dart';

const _base = 'http://127.0.0.1:8000';

/// A stand-in for the platform SDK. The real one opens an account picker.
class _FakeGoogle implements GoogleSignInService {
  _FakeGoogle({this.token, this.throwing});

  final String? token;
  final Object? throwing;
  int calls = 0;

  @override
  Future<String> idToken() async {
    calls++;
    if (throwing != null) throw throwing!;
    return token!;
  }

  @override
  Future<void> signOut() async {}
}

({Widget widget, DioAdapter adapter}) harness(GoogleSignInService google) {
  final dio = Dio(BaseOptions(
    baseUrl: _base,
    validateStatus: (s) => s != null && s >= 200 && s < 300,
  ));
  final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
  final client = ApiClient.create(dio: dio, cookieJar: CookieJar());
  dio.httpClientAdapter = adapter;

  // The login screen reads branding on build; without this every test trips on
  // an unmatched route before it reaches what it is actually asserting.
  adapter.onGet(
    '/api/branding',
    (s) => s.reply(200, {'name': 'JobsFlood'}),
  );

  return (
    widget: ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        googleSignInServiceProvider.overrideWithValue(google),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    ),
    adapter: adapter,
  );
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// A phone viewport, not flutter_test's 800x600 default.
///
/// The Google button sits below the fold at the default size, so `tap` found
/// the widget but hit-tested nothing and the handler never ran — the tests
/// failed reporting `calls: 0`, which reads like a broken handler rather than a
/// test harness that cannot reach the control. The flow tests set the same
/// viewport for the same reason.
void usePhoneViewport(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1179, 2556)
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Scroll the control into view, then tap it.
Future<void> tapButton(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
}

void main() {
  group('the button follows the SERVER', () {
    testWidgets('hidden when the server reports google: false', (tester) async {
      usePhoneViewport(tester);
      final h = harness(_FakeGoogle(token: 'tok'));
      h.adapter.onGet(
        '/api/auth/providers',
        (s) => s.reply(200, {'google': false}),
      );

      await tester.pumpWidget(h.widget);
      await settle(tester);

      expect(find.text('Continue with Google'), findsNothing);
      // The password door is unaffected — with Google off, it is the only one.
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('shown when the server reports google: true', (tester) async {
      usePhoneViewport(tester);
      final h = harness(_FakeGoogle(token: 'tok'));
      h.adapter.onGet(
        '/api/auth/providers',
        (s) => s.reply(200, {'google': true}),
      );

      await tester.pumpWidget(h.widget);
      await settle(tester);

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('hidden when the providers call fails', (tester) async {
      // A flaky call must hide the button, not offer one that cannot work.
      final h = harness(_FakeGoogle(token: 'tok'));
      h.adapter.onGet('/api/auth/providers', (s) => s.reply(500, {}));

      await tester.pumpWidget(h.widget);
      await settle(tester);

      expect(find.text('Continue with Google'), findsNothing);
    });
  });

  group('pressing it', () {
    testWidgets('sends the SDK token to the server and signs in',
        (tester) async {
      usePhoneViewport(tester);
      final google = _FakeGoogle(token: 'id-token-from-google');
      final h = harness(google);
      h.adapter.onGet(
        '/api/auth/providers',
        (s) => s.reply(200, {'google': true}),
      );
      h.adapter.onPost(
        '/api/auth/google/mobile',
        (s) => s.reply(200, {
          'id': 1,
          'email': 'seeker@test.dev',
          'full_name': 'A Seeker',
          'role': 'seeker',
          'status': 'active',
        }),
        data: {'id_token': 'id-token-from-google'},
      );

      await tester.pumpWidget(h.widget);
      await settle(tester);
      await tapButton(tester, 'Continue with Google');
      await settle(tester);

      expect(google.calls, 1);
      // No error surfaced.
      expect(find.textContaining('did not complete'), findsNothing);
    });

    testWidgets('a CANCELLED picker says nothing at all', (tester) async {
      usePhoneViewport(tester);
      final google = _FakeGoogle(throwing: const GoogleSignInCancelled());
      final h = harness(google);
      h.adapter.onGet(
        '/api/auth/providers',
        (s) => s.reply(200, {'google': true}),
      );

      await tester.pumpWidget(h.widget);
      await settle(tester);
      await tapButton(tester, 'Continue with Google');
      await settle(tester);

      // Backing out is a decision, not a fault. Nothing may be shown, and the
      // button must be usable again.
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('a server refusal is shown as the server worded it',
        (tester) async {
      usePhoneViewport(tester);
      final google = _FakeGoogle(token: 'stale');
      final h = harness(google);
      h.adapter.onGet(
        '/api/auth/providers',
        (s) => s.reply(200, {'google': true}),
      );
      h.adapter.onPost(
        '/api/auth/google/mobile',
        (s) => s.reply(404, {
          'detail': 'No account for nobody@nowhere.test. Create one to continue.',
        }),
        data: {'id_token': 'stale'},
      );

      await tester.pumpWidget(h.widget);
      await settle(tester);
      await tapButton(tester, 'Continue with Google');
      await settle(tester);

      expect(find.textContaining('No account for'), findsOneWidget);
    });
  });

  group('the client ids', () {
    test('the token is requested for the SERVER audience', () {
      // The backend verifies `aud` against its own web client id. Requesting a
      // token for the iOS client instead would fail verification — and the
      // failure is a 401 that says nothing about why.
      expect(
        GoogleClients.server,
        '61359852805-dagr0hepadlvhgef9qlka5klofkp9p7j.apps.googleusercontent.com',
      );
      expect(GoogleClients.ios, isNot(GoogleClients.server));
    });
  });
}
