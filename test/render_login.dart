/// Renders the sign-in screen to a PNG so the design can be LOOKED AT rather
/// than reasoned about. Not part of the suite — run it deliberately:
///
///   flutter test test/render_login.dart
///
/// Writes build/login-preview.png at an iPhone-class viewport.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:jobportal_mobile/core/network/api_client.dart';
import 'package:jobportal_mobile/core/providers.dart';
import 'package:jobportal_mobile/core/theme/app_theme.dart';
import 'package:jobportal_mobile/features/jobseeker/authentication/login_screen.dart';

void main() {
  testWidgets('render the sign-in screen', (tester) async {
    final binding = tester.binding;
    // iPhone 14 Pro class, 3x — the same viewport the flow tests use.
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3.0;
    addTearDown(() {
      binding.platformDispatcher.views.first
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000'));
    DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
    final client = ApiClient.create(dio: dio, cookieJar: CookieJar());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RepaintBoundary(child: LoginScreen()),
        ),
      ),
    );

    // The SVGs decode asynchronously; a settle would spin on any progress
    // indicator, so pump a fixed number of frames instead.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    final out = File('build/login-preview.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('WROTE ${out.absolute.path}  (${bytes.lengthInBytes} bytes)');
  });
}
