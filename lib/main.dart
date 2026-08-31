/// JobPortal — the JobSeeker app.
///
/// A second client of the same API the web application uses. The web build is
/// the functional source of truth; see `docs/` beside this package and
/// `jobportal-python/CLAUDE.md`, which is authoritative for the server.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/environment.dart';
import 'core/theme/app_theme.dart';
import 'routing/router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail at start-up rather than shipping a configuration that cannot work.
  // The server sets Secure on the session cookie outside debug, so over plain
  // http the session is simply never sent and every screen fails with nothing
  // logged to say why. This mirrors the server's own refusal to serve with
  // DEBUG=false and COOKIE_SECURE=false.
  Env.assertValid();

  runApp(const ProviderScope(child: JobPortalApp()));
}

class JobPortalApp extends ConsumerWidget {
  const JobPortalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'JobPortal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) {
        // Respect the reader's text-size setting, but hold a ceiling: past
        // about 1.6x the fixed-height controls (the 44px action bar, the tab
        // labels) start clipping rather than reflowing. Accessibility means the
        // text scales AND stays legible.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.6,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child!,
        );
      },
    );
  }
}
