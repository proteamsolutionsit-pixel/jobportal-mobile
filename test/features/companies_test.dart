/// The company directory.
///
/// Payloads below are copied from the live `/api/companies` and
/// `/api/companies/{id}`, not invented, because the last company bug was
/// exactly a model reading field names the server does not send.
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:jobportal_mobile/core/network/api_client.dart';
import 'package:jobportal_mobile/core/providers.dart';
import 'package:jobportal_mobile/core/theme/app_theme.dart';
import 'package:jobportal_mobile/data/models/models.dart';
import 'package:jobportal_mobile/features/jobseeker/companies/companies_screen.dart';

const _base = 'http://127.0.0.1:8000';

const _page = {
  'items': [
    {
      'id': 145,
      'name': '3M India',
      'slug': '3m-india',
      'logo_path': 'uploads/logos/co_145_581dff4cef3e.png',
      'industry': 'Manufacturing',
      'hq_location': 'Bengaluru',
      'size_bucket': '1000+',
      'is_verified': true,
      'open_jobs': 39,
      'about': null,
    },
    {
      'id': 9,
      'name': 'Quiet Startup',
      'slug': 'quiet-startup',
      'logo_path': null,
      'industry': null,
      'hq_location': null,
      'size_bucket': null,
      'is_verified': false,
      'open_jobs': 0,
      'about': null,
    },
  ],
  // Deliberately larger than items.length: the label must use this.
  'total': 214,
  'page': 1,
  'per_page': 20,
};

({Widget widget, DioAdapter adapter}) harness() {
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
      child: MaterialApp(theme: AppTheme.light, home: const CompaniesScreen()),
    ),
    adapter: adapter,
  );
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  group('CompanyListOut', () {
    test('counts from the server total, not the page length', () {
      final list = CompanyListOut.decode(_page);
      expect(list.items.length, 2);
      // The "3 views" bug: a capped list counted under a total's label.
      expect(list.total, 214);
      expect(list.hasMore, isTrue);
    });

    test('carries the fields the directory actually renders', () {
      final c = CompanyListOut.decode(_page).items.first;
      expect(c.city, 'Bengaluru');
      expect(c.jobCount, 39);
      expect(c.isVerified, isTrue);
      expect(c.sizeBucket, '1000+');
    });
  });

  group('CompanyDetailOut', () {
    test('reads the company from the TOP level, not a nested key', () {
      final d = CompanyDetailOut.decode({
        'id': 145,
        'name': '3M India',
        'hq_location': 'Bengaluru',
        'is_verified': false,
        'website': 'https://example.com',
        'about': 'Science applied to life.',
        'jobs': [
          {
            'id': 163,
            'title': 'Area Sales Manager',
            'slug': 'area-sales-manager-074c67',
            'location': 'Gurugram',
            'job_type': 'full_time',
            'work_mode': 'onsite',
            'status': 'open',
          },
        ],
      });

      expect(d.company.name, '3M India');
      expect(d.company.city, 'Bengaluru');
      expect(d.company.about, 'Science applied to life.');
      expect(d.jobs, hasLength(1));
      expect(d.jobs.first.title, 'Area Sales Manager');
    });

    test('a company with no open roles decodes rather than throwing', () {
      final d = CompanyDetailOut.decode({
        'id': 9,
        'name': 'Quiet Startup',
        'is_verified': false,
      });
      expect(d.jobs, isEmpty);
    });
  });

  group('CompaniesScreen', () {
    testWidgets('lists employers and labels the SERVER total', (tester) async {
      final h = harness();
      h.adapter.onGet('/api/companies', (s) => s.reply(200, _page));

      await tester.pumpWidget(h.widget);
      await settle(tester);

      expect(find.text('3M India'), findsOneWidget);
      expect(find.text('Quiet Startup'), findsOneWidget);
      // 214, not 2.
      expect(find.text('214 companies'), findsOneWidget);
    });

    testWidgets('shows the open-role count, and omits it at zero',
        (tester) async {
      final h = harness();
      h.adapter.onGet('/api/companies', (s) => s.reply(200, _page));

      await tester.pumpWidget(h.widget);
      await settle(tester);

      expect(find.text('39 open roles'), findsOneWidget);
      // Quiet Startup has open_jobs: 0 — a "0 open roles" tag would be noise.
      expect(find.text('0 open roles'), findsNothing);
    });

    testWidgets('an empty directory says so instead of showing a blank list',
        (tester) async {
      final h = harness();
      h.adapter.onGet(
        '/api/companies',
        (s) => s.reply(200, {'items': [], 'total': 0, 'page': 1, 'per_page': 20}),
      );

      await tester.pumpWidget(h.widget);
      await settle(tester);

      expect(find.text('No companies yet'), findsOneWidget);
    });

    testWidgets('a server failure offers a retry rather than an empty screen',
        (tester) async {
      final h = harness();
      h.adapter.onGet(
        '/api/companies',
        (s) => s.reply(500, {'detail': 'boom'}),
      );

      await tester.pumpWidget(h.widget);
      await settle(tester);

      expect(find.text('No companies yet'), findsNothing);
      expect(find.textContaining('Try again'), findsWidgets);
    });
  });
}
