/// On-device smoke test.
///
/// The whole-journey tests live in `test/flows/flows_test.dart` and run
/// **headless** under `flutter test`, so they work in CI with no device
/// attached. This file is the small part that only a real device can answer:
/// that the app boots on the platform, that `flutter_secure_storage` actually
/// reaches the Android Keystore / iOS Keychain, and that the release
/// configuration is sane.
///
/// Run it with a device or emulator attached:
///
/// ```bash
/// flutter test integration_test/app_test.dart \
///   --dart-define=APP_ENV=development \
///   --dart-define=API_BASE_URL=http://10.0.2.2:8000
/// ```
///
/// (`10.0.2.2` is the host as seen from an Android emulator — `127.0.0.1` there
/// is the emulator itself.)
///
/// **It makes no network assertions.** A smoke test that needs a live API is a
/// test of whether somebody remembered to start MariaDB, and it gets skipped
/// within a week.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jobportal_mobile/core/config/environment.dart';
import 'package:jobportal_mobile/core/storage/secure_cookie_storage.dart';
import 'package:jobportal_mobile/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the configuration is valid for this build', (tester) async {
    // Mirrors what main() does at start-up: refuses a non-https URL outside
    // development, and refuses www.jobsflood.com, which has no DNS A record.
    expect(Env.assertValid, returnsNormally);
    expect(Uri.parse(Env.apiBaseUrl).hasScheme, isTrue);

    if (Env.isProduction) {
      expect(Uri.parse(Env.apiBaseUrl).scheme, 'https');
      expect(Env.verboseLogging, isFalse,
          reason: 'a production build must not log requests');
    }
  });

  testWidgets('the app boots and reaches a screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JobPortalApp()));

    // Pumped by hand rather than settled: the splash's progress indicator
    // schedules frames for ever, so pumpAndSettle would time out on a screen
    // that is working correctly.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('secure storage really reaches the platform keystore',
      (tester) async {
    // This is the one thing no headless test can prove. The cookie jar holds
    // `hh_token` — a live session — so it must land in Android Keystore or the
    // iOS Keychain, never in SharedPreferences.
    final storage = SecureCookieStorage(namespace: 'integration-test');

    await storage.init(true, false);
    await storage.write('probe', 'value-abc');
    expect(await storage.read('probe'), 'value-abc');

    await storage.delete('probe');
    expect(await storage.read('probe'), isNull);
  });
}
