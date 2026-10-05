/// Renders the seeker's main screens to PNGs so the design can be LOOKED AT
/// rather than reasoned about. Not part of the suite — run it deliberately:
///
///   flutter test test/render_screens.dart
///
/// Writes build/preview-*.png at an iPhone-class viewport, with the app's own
/// fonts loaded (flutter_test otherwise draws every glyph as a box).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:jobportal_mobile/core/network/api_client.dart';
import 'package:jobportal_mobile/core/network/csrf_interceptor.dart';
import 'package:jobportal_mobile/core/providers.dart';
import 'package:jobportal_mobile/core/widgets/common.dart';
import 'package:jobportal_mobile/main.dart';

const _base = 'http://127.0.0.1:8000';

/// A posting in JobOut's real shape — `job_types` and `benefits` as lists,
/// as the API sends them (see test/fixtures/live/job_detail.json).
Map<String, dynamic> _job(int id, String title, String company, String loc,
        {String mode = 'onsite', String type = 'full_time', bool verified = true}) =>
    {
      'id': id,
      'title': title,
      'slug': 'job-$id',
      'reference_code': 'JF-${id.toString().padLeft(6, '0')}',
      'description': 'Own the day-to-day of a busy team: scheduling, '
          'coordination and keeping every shift running on time.',
      'description_format': 'text',
      'responsibilities': 'Plan weekly rosters\nTrack attendance and leave\n'
          'Resolve scheduling conflicts quickly',
      'responsibilities_format': 'text',
      'requirements': 'Graduate in any discipline\nComfortable with Excel',
      'requirements_format': 'text',
      'key_skills': 'Scheduling, Excel, Payroll, Communication',
      'location': loc,
      'min_experience': 1,
      'max_experience': 4,
      'min_salary': '350000.00',
      'max_salary': '600000.00',
      'salary_period': 'year',
      'salary_mode': 'range',
      'hide_salary': false,
      'skill_level': 'experienced',
      'job_type': type,
      'job_types': [type],
      'benefits': ['provident_fund', 'health_insurance', 'paid_leave'],
      'work_mode': mode,
      'vacancies': 3,
      'view_count': 214,
      'application_count': 18,
      'status': 'active',
      'posted_at': '2026-10-03T10:30:00',
      'expires_at': '2026-11-03T10:30:00',
      'company': {
        'id': id,
        'name': company,
        'slug': company.toLowerCase(),
        'logo_path': null,
        'industry': 'IT Services',
        'hq_location': loc,
        'is_verified': verified,
      },
      'closure': null,
    };

/// A real captured server response (see test/fixtures/live/).
Object? _live(String name) =>
    jsonDecode(File('test/fixtures/live/$name.json').readAsStringSync());

Map<String, dynamic> _brief(Map<String, dynamic> j) => {
      for (final k in ['id', 'title', 'slug', 'location', 'job_type', 'work_mode', 'status', 'company'])
        k: j[k],
    };

Future<void> _loadFonts() async {
  for (final (family, path) in [
    ('InterVar', 'assets/fonts/inter-var.ttf'),
    ('Jakarta', 'assets/fonts/jakarta-var.ttf'),
    // Icons: without this every Material icon is a box too.
    ('MaterialIcons', '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'),
  ]) {
    final f = File(path);
    if (!f.existsSync()) continue;
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    await loader.load();
  }
}

Future<void> _snap(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('snap')),
  );
  // Real async time: a second toImage() inside the fake-async test zone
  // never completes.
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    return image.toByteData(format: ui.ImageByteFormat.png);
  });
  final out = File('build/preview-$name.png')..parent.createSync(recursive: true);
  out.writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('WROTE ${out.absolute.path}');
}

/// Scroll the first list until [f] is built, then bring it on screen.
Future<void> _reveal(WidgetTester tester, Finder f) async {
  // From the top, so a target the list has already scrolled past is found.
  for (var i = 0; i < 6; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pump(const Duration(milliseconds: 60));
  }
  for (var i = 0; i < 15 && f.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 60));
  }
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 60));
}

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets('render home, profile and assistant', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.binding.platformDispatcher.views.first
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3.0;
    addTearDown(() => tester.binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio());

    final jar = CookieJar();
    final dio = Dio(BaseOptions(
      baseUrl: _base,
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    ));
    final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
    final client = ApiClient.create(dio: dio, cookieJar: jar);
    dio.httpClientAdapter = adapter;
    await jar.saveFromResponse(Uri.parse(_base), [
      Cookie(sessionCookieName, 'jwt')..path = '/',
      Cookie(csrfCookieName, 'csrf')..path = '/',
    ]);

    adapter
      ..onGet('/api/auth/me', (s) => s.reply(200, {
            'id': 7, 'email': 'tirumurthyuk@gmail.com', 'full_name': 'A Tirumurthy',
            'role': 'seeker', 'status': 'active', 'candidate_id': 3,
            'must_set_password': false, 'email_verified_at': '2026-08-29T09:00:00',
          }))
      ..onGet('/api/auth/providers', (s) => s.reply(200, {'google': false}))
      ..onGet('/api/branding', (s) => s.reply(200, {'name': 'JobsFlood'}))
      ..onGet('/api/home/jobs', (s) => s.reply(200, [
            _job(1, 'HR Executive', 'Accenture', 'Bengaluru'),
            _job(2, 'Payroll Associate', 'Infosys', 'Pune', mode: 'hybrid'),
            _job(3, 'Talent Acquisition Specialist', 'Bosch', 'Bengaluru'),
          ]))
      ..onGet('/api/jobs', (s) => s.reply(200, {
            'items': [
              _job(1, 'HR Executive', 'Accenture', 'Bengaluru'),
              _job(2, 'Payroll Associate', 'Infosys', 'Pune', mode: 'hybrid'),
              _job(3, 'Talent Acquisition Specialist', 'Bosch', 'Bengaluru'),
              _job(5, 'Workforce Scheduler', 'Capgemini', 'Chennai', mode: 'remote'),
            ],
            'total': 141, 'page': 1, 'per_page': 20, 'total_capped': false,
          }))
      ..onGet('/api/jobs/facets', (s) => s.reply(200, {}))
      ..onGet('/api/jobs/1', (s) => s.reply(200, _job(1, 'HR Executive', 'Accenture', 'Bengaluru')))
      ..onGet('/api/jobs/1/state', (s) => s.reply(200, {'job_id': 1, 'has_applied': false, 'is_saved': true}))
      ..onGet('/api/jobs/1/similar', (s) => s.reply(200, [
            _job(5, 'Workforce Scheduler', 'Capgemini', 'Chennai', mode: 'remote'),
          ]))
      ..onGet('/api/seeker/viewers', (s) => s.reply(200, {'items': [], 'total': 3, 'view_total': 7}))
      ..onGet('/api/seeker/alerts', (s) => s.reply(200, [
            {'id': 1, 'name': 'HR jobs in Bengaluru', 'keywords': 'HR Executive', 'location': 'Bengaluru',
             'frequency': 'daily', 'is_active': true, 'created_at': '2026-09-20T10:00:00'},
            {'id': 2, 'name': 'Payroll', 'keywords': 'Payroll', 'location': null,
             'frequency': 'weekly', 'is_active': false, 'created_at': '2026-09-10T10:00:00'},
          ]))
      ..onGet('/api/seeker/suggested', (s) => s.reply(200, {'items': [
            _job(4, 'HR Scheduler', 'Capgemini', 'Bengaluru'),
          ]}))
      ..onGet('/api/applications/mine', (s) => s.reply(200, {
            'items': [
              {'id': 1, 'job_id': 1, 'status': 'interview', 'applied_at': '2026-09-28T10:00:00',
               'job': _brief(_job(1, 'HR Executive', 'Accenture', 'Bengaluru'))},
              {'id': 2, 'job_id': 3, 'status': 'shortlisted', 'applied_at': '2026-09-25T10:00:00',
               'job': _brief(_job(3, 'Talent Acquisition Specialist', 'Bosch', 'Bengaluru'))},
              {'id': 3, 'job_id': 2, 'status': 'viewed', 'applied_at': '2026-09-21T10:00:00',
               'job': _brief(_job(2, 'Payroll Associate', 'Infosys', 'Pune'))},
              {'id': 4, 'job_id': 5, 'status': 'applied', 'applied_at': '2026-10-02T10:00:00',
               'job': _brief(_job(5, 'Workforce Scheduler', 'Capgemini', 'Chennai'))},
            ],
            'total': 4, 'page': 1, 'per_page': 20,
          }))
      ..onGet('/api/seeker/saved', (s) => s.reply(200, {
            'items': [
              {'saved_at': '2026-10-01T09:00:00', 'is_open': true,
               'job': _job(1, 'HR Executive', 'Accenture', 'Bengaluru')},
              {'saved_at': '2026-09-29T09:00:00', 'is_open': true,
               'job': _job(5, 'Workforce Scheduler', 'Capgemini', 'Chennai', mode: 'remote')},
            ],
            'total': 2, 'page': 1, 'per_page': 20,
          }))
      ..onGet('/api/seeker/profile', (s) => s.reply(200, {
            'id': 3, 'full_name': 'A Tirumurthy', 'email': 'tirumurthyuk@gmail.com',
            'is_searchable': true, 'is_public': false, 'source': 'self_signup',
            'status': 'active', 'profile_completeness': 72, 'has_resume': true,
            'resume_name': 'A Tirumurthy.pdf', 'resume_size': 184320,
            'headline': 'HR Scheduler · 7 mos exp', 'phone': '8792564479',
            'current_location': 'Bangalore', 'current_designation': 'HR Scheduler',
            'current_company': 'APT HR tech', 'experience_years': 0, 'experience_months': 7,
            'skills': [
              {'id': 1, 'name': 'HR Scheduling', 'slug': 'a'},
              {'id': 2, 'name': 'Payroll', 'slug': 'b'},
              {'id': 3, 'name': 'Excel', 'slug': 'c'},
              {'id': 4, 'name': 'Attendance Management', 'slug': 'd'},
              {'id': 5, 'name': 'Budgeting', 'slug': 'e'},
            ],
          }))
      ..onGet('/api/seeker/education', (s) => s.reply(200, {'items': []}))
      ..onGet('/api/seeker/certifications', (s) => s.reply(200, {'items': []}))
      ..onGet('/api/notifications', (s) => s.reply(200, {
            'items': [
              {'id': 1, 'kind': 'application.shortlisted', 'title': 'You were shortlisted for HR Executive',
               'body': 'Accenture moved your application forward.', 'link': '/jobs/1', 'read': false,
               'created_at': '2026-10-05T08:00:00'},
              {'id': 2, 'kind': 'application.stage', 'title': 'Interview invitation: Talent Acquisition Specialist',
               'body': 'Bosch would like to interview you.', 'link': '/seeker/applications', 'read': false,
               'created_at': '2026-10-04T12:00:00'},
              {'id': 3, 'kind': 'application.rejected', 'title': 'Update on Payroll Associate',
               'body': 'Infosys has filled this role.', 'link': '/seeker/applications', 'read': true,
               'created_at': '2026-09-30T09:00:00'},
            ],
            'unread': 2,
            'more': false,
          }))
      ..onGet('/api/notifications/preferences', (s) => s.reply(200, _live('notification_prefs')))
      ..onGet('/api/companies', (s) => s.reply(200, {
            'items': [
              {'id': 1, 'name': 'Accenture', 'slug': 'accenture', 'industry': 'IT Services',
               'hq_location': 'Bengaluru', 'is_verified': true, 'open_jobs': 12},
              {'id': 3, 'name': 'Bosch', 'slug': 'bosch', 'industry': 'Engineering',
               'hq_location': 'Bengaluru', 'is_verified': true, 'open_jobs': 4},
              {'id': 2, 'name': 'Infosys', 'slug': 'infosys', 'industry': 'IT Services',
               'hq_location': 'Pune', 'is_verified': false, 'open_jobs': 7},
            ],
            'total': 149, 'page': 1, 'per_page': 20,
          }))
      ..onGet('/api/companies/1', (s) => s.reply(200, {
            'id': 1, 'name': 'Accenture', 'slug': 'accenture', 'logo_path': null,
            'industry': 'IT Services', 'hq_location': 'Bengaluru', 'size_bucket': '10000+',
            'is_verified': true, 'open_jobs': 12,
            'about': 'A global professional services company helping clients build their digital core.',
            'website': 'https://accenture.com',
            'jobs': [
              {'id': 1, 'title': 'HR Executive', 'slug': 'hr-executive', 'location': 'Bengaluru',
               'min_experience': 1, 'hide_salary': false, 'skill_level': 'experienced',
               'job_type': 'full_time', 'work_mode': 'onsite', 'company_id': 1,
               'company_name': 'Accenture', 'logo_path': null},
              {'id': 6, 'title': 'Payroll Specialist', 'slug': 'payroll-specialist', 'location': 'Hyderabad',
               'min_experience': 2, 'hide_salary': false, 'skill_level': 'experienced',
               'job_type': 'full_time', 'work_mode': 'hybrid', 'company_id': 1,
               'company_name': 'Accenture', 'logo_path': null},
            ],
          }))
      ..onGet('/api/seeker/employment', (s) => s.reply(200, [
            {'id': 1, 'company_name': 'APT HR tech', 'designation': 'HR Scheduler', 'location': 'Bengaluru',
             'start_date': '2024-05-01', 'end_date': '2024-12-31', 'is_current': false,
             'description': 'Rostered 300+ staff across shifts for an Accenture account.'},
            {'id': 2, 'company_name': 'Playto Lab', 'designation': 'Relationship Manager Intern',
             'location': 'Bengaluru', 'start_date': '2023-01-01', 'end_date': '2023-06-30',
             'is_current': false, 'description': null},
          ]))
      ..onGet('/api/seeker/links', (s) => s.reply(200, [
            {'id': 1, 'label': 'LinkedIn', 'url': 'https://linkedin.com/in/tirumurthy', 'sort_order': 0},
            {'id': 2, 'label': 'Portfolio', 'url': 'https://tirumurthy.dev', 'sort_order': 1},
          ]))
      ..onGet('/api/seeker/skills', (s) => s.reply(200, {'items': [
            {'id': 7, 'name': 'HR Analytics', 'slug': 'hr-analytics', 'category': 'HR'},
            {'id': 8, 'name': 'HR Operations', 'slug': 'hr-operations', 'category': 'HR'},
          ]}))
      ..onGet('/api/assistant/intents', (s) => s.reply(200, {
            'role': 'seeker',
            'chips': ['Recommend jobs for me', 'How complete is my profile?', 'My applications', 'Remote jobs'],
          }))
      ..onPost('/api/assistant/ask', (s) => s.reply(200, {
            'question': 'How complete is my profile?',
            'answer': {
              'intent': 'my_profile',
              'text': 'Your profile is 72% complete. Filling these would add 28 points:',
              'facts': [
                {'label': 'Profile score', 'value': '72%'},
                {'label': 'Applications', 'value': '6'},
              ],
              'items': [
                {'title': 'About you', 'url': '/seeker/profile'},
                {'title': 'Salary & notice period', 'url': '/seeker/profile'},
              ],
              'actions': [{'label': 'Edit my profile', 'url': '/seeker/profile'}],
              'chips': ['Recommend jobs for me'],
            },
          }));

    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('snap'),
      child: ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: const JobPortalApp(),
      ),
    ));
    await _frames(tester, 30);
    await _snap(tester, '1-home');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -560));
    await _frames(tester);
    await _snap(tester, '2-home-scrolled');

    await tester.tap(find.text('Profile').last);
    await _frames(tester, 30);
    await _snap(tester, '3-profile');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await _frames(tester);
    await _snap(tester, '4-profile-scrolled');

    await tester.tap(find.text('Home').last);
    await _frames(tester);
    await tester.ensureVisible(find.text('Ask the assistant'));
    await tester.tap(find.text('Ask the assistant'));
    await _frames(tester, 25);
    await tester.tap(find.text('How complete is my profile?'));
    await _frames(tester, 25);
    await _snap(tester, '5-assistant');

    await tester.pageBack();
    await _frames(tester);
    await tester.tap(find.text('Jobs').last);
    await _frames(tester, 30);
    await _snap(tester, '6-jobs');

    await tester.tap(find.text('HR Executive').first);
    await _frames(tester, 30);
    await _snap(tester, '7-job-detail');

    await tester.pageBack();
    await _frames(tester);
    await tester.tap(find.text('Applied').last);
    await _frames(tester, 30);
    await _snap(tester, '8-applied');

    await tester.tap(find.text('Saved').last);
    await _frames(tester, 30);
    await _snap(tester, '9-saved');

    await tester.tap(find.text('Profile').last);
    await _frames(tester, 20);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await _frames(tester, 25);
    await _snap(tester, '10-settings');

    await tester.tap(find.text('Job alerts'));
    await _frames(tester, 20);
    await _snap(tester, '11-alerts');
    await tester.pageBack();
    await _frames(tester);

    await tester.tap(find.text('Notifications'));
    await _frames(tester, 20);
    await _snap(tester, '12-notification-prefs');
    await tester.pageBack();
    await _frames(tester);

    await tester.tap(find.text('Change password'));
    await _frames(tester, 20);
    await _snap(tester, '13-change-password');
    await tester.pageBack();
    await _frames(tester);
    await tester.pageBack();
    await _frames(tester);

    // Profile: the edit screens.
    await _reveal(tester, find.text('Employment'));
    await tester.tap(find.text('Manage').first);
    await _frames(tester, 20);
    await _snap(tester, '14-employment');
    await tester.pageBack();
    await _frames(tester);

    await _reveal(tester, find.text('Skills'));
    await tester.tap(find.descendant(
      of: find.ancestor(of: find.text('Skills').first, matching: find.byType(SectionCard)),
      matching: find.byType(TextButton),
    ));
    await _frames(tester, 20);
    await tester.enterText(find.byType(TextField).first, 'HR');
    await _frames(tester, 20);
    await _snap(tester, '15-skills');
    await tester.pageBack();
    await _frames(tester);

    await _reveal(tester, find.text('Online presence'));
    await tester.tap(find.text('Manage').last);
    await _frames(tester, 20);
    await _snap(tester, '16-links');
    await tester.pageBack();
    await _frames(tester);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
    await _frames(tester, 20);
    await _snap(tester, '17-notifications');
    await tester.pageBack();
    await _frames(tester);

    await tester.tap(find.text('Home').last);
    await _frames(tester);
    await _reveal(tester, find.text('Browse companies'));
    await tester.tap(find.text('Browse companies'));
    await _frames(tester, 20);
    await _snap(tester, '18-companies');
    await tester.tap(find.text('Accenture').first);
    await _frames(tester, 20);
    await _snap(tester, '19-company');
    await tester.pageBack();
    await _frames(tester);
    await tester.pageBack();
    await _frames(tester);

    await tester.tap(find.text('Jobs').last);
    await _frames(tester, 20);
    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await _frames(tester, 25);
    await _snap(tester, '20-filters');
  });
}
