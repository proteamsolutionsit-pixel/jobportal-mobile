/// Flow tests — whole journeys, over the real app shell and router.
///
/// These run **headless** under `flutter test`, so they work on any machine and
/// in CI with no device attached. `integration_test/app_test.dart` is the
/// on-device counterpart and covers what only a real device can: secure
/// storage, permissions and platform channels.
///
/// The **transport** is faked and nothing else: the real cookie jar, the real
/// CSRF interceptor, the real error mapping, the real strict models, the real
/// routing and the real screens all run. The alternative — pointing these at a
/// live server — would make them a test of whether somebody remembered to start
/// MariaDB, and they would be skipped within a week.
///
/// **This is the only place a fake is allowed.** A mock reaching a shipped
/// build is the "no fake implementations" rule broken.
///
/// Covers, in success and failure: session restore, both sign-in doors,
/// registration, search, job detail, save, apply (including already-applied),
/// application history, withdrawal, profile, notifications and sign-out.
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:jobportal_mobile/core/network/api_client.dart';
import 'package:jobportal_mobile/core/network/csrf_interceptor.dart';
import 'package:jobportal_mobile/core/providers.dart';
import 'package:jobportal_mobile/main.dart';

const _base = 'http://127.0.0.1:8000';

// --------------------------------------------------------------------------
// Fixtures — shaped exactly as docs/api-contract-generated.md declares them.
// --------------------------------------------------------------------------

const _user = {
  'id': 7,
  'email': 'seeker@jobsflood.local',
  'full_name': 'Asha Rao',
  'role': 'seeker',
  'status': 'active',
  'candidate_id': 3,
  'must_set_password': false,
  'email_verified_at': '2026-08-29T09:00:00',
  'impersonating': false,
};

Map<String, dynamic> _job({
  int id = 41,
  String title = 'Senior Accountant',
  String status = 'active',
}) =>
    {
      'id': id,
      'title': title,
      'slug': 'job-$id',
      'description': 'Own the monthly close.',
      'location': 'Bengaluru',
      'min_experience': 3,
      'max_experience': 6,
      'hide_salary': false,
      'skill_level': 'experienced',
      'job_type': 'full_time',
      'work_mode': 'onsite',
      'vacancies': 2,
      'status': status,
      'min_salary': '600000.00',
      'max_salary': '900000.00',
      'salary_period': 'year',
      'salary_mode': 'range',
      'posted_at': '2026-08-20T10:30:00',
      'company': {'id': 2, 'name': 'Acme Ltd'},
    };

const _profile = {
  'id': 3,
  'full_name': 'Asha Rao',
  'email': 'seeker@jobsflood.local',
  'is_searchable': true,
  'is_public': false,
  'source': 'self_signup',
  'status': 'active',
  'profile_completeness': 62,
  'has_resume': true,
  'resume_name': 'asha-rao.pdf',
  'resume_size': 184320,
  'current_designation': 'Accountant',
  'current_company': 'Acme Ltd',
  'experience_years': 5,
  'experience_months': 6,
  'current_ctc': '450000.00',
  'skills': [
    {'id': 1, 'name': 'Tally', 'slug': 'tally'},
    {'id': 2, 'name': 'GST', 'slug': 'gst'},
  ],
};

/// A harness holding the adapter so a test can change an answer mid-flow.
class Harness {
  Harness()
      : jar = CookieJar(),
        dio = Dio(BaseOptions(
          baseUrl: _base,
          validateStatus: (s) => s != null && s >= 200 && s < 300,
        )) {
    adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
    client = ApiClient.create(dio: dio, cookieJar: jar);
    dio.httpClientAdapter = adapter;
  }

  final CookieJar jar;
  final Dio dio;
  late final DioAdapter adapter;
  late final ApiClient client;

  /// Put a live session in the jar, as a sign-in would.
  Future<void> signIn() => jar.saveFromResponse(Uri.parse(_base), [
        Cookie(sessionCookieName, 'jwt')..path = '/',
        Cookie(csrfCookieName, 'csrf-token')..path = '/',
      ]);

  /// The endpoints every signed-in screen touches.
  void stubCommon() {
    adapter
      ..onGet('/api/auth/me', (s) => s.reply(200, _user))
      // The sign-in screen asks whether Google is configured before it can
      // decide whether to draw that button, so every journey starting there
      // needs this. Off by default: the flows under test are the password and
      // emailed-code doors, and a Google button in the tree would only be
      // another thing for a finder to trip over.
      ..onGet('/api/auth/providers', (s) => s.reply(200, {'google': false}))
      ..onGet('/api/branding',
          (s) => s.reply(200, {'name': 'Jobsflood', 'logo_path': null}))
      ..onGet('/api/home/jobs', (s) => s.reply(200, {'items': [_job()]}))
      ..onGet('/api/seeker/suggested', (s) => s.reply(200, {'items': []}))
      ..onGet('/api/seeker/profile', (s) => s.reply(200, _profile))
      ..onGet(
        '/api/notifications',
        (s) => s.reply(200, {'items': [], 'unread': 0, 'more': false}),
      );
  }

  Widget get app => ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: const JobPortalApp(),
      );
}

/// Pump a fixed number of frames instead of settling.
///
/// `pumpAndSettle` cannot be used across the splash screen: it waits for a
/// frame-free moment and the splash's `CircularProgressIndicator` schedules
/// frames for ever, so it times out on a screen that is working perfectly.
Future<void> settle(WidgetTester tester, [int frames = 14]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // A phone, not flutter_test's 800x600 default.
    //
    // This is a mobile application and most of its screens are taller than
    // 600px, so on the default viewport a control that is perfectly visible on
    // a real device is simply off-screen and the test fails for a reason that
    // has nothing to do with the code.
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(1170, 2532) // iPhone-class, 3x
      ..devicePixelRatio = 3.0;
  });

  tearDown(() {
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  group('cold start', () {
    testWidgets('with no session, lands on sign-in', (tester) async {
      final h = Harness()..stubCommon();
      await tester.pumpWidget(h.app);
      await settle(tester);

      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('with a stored session, restores and shows Home',
        (tester) async {
      final h = Harness()..stubCommon();
      await h.signIn();

      await tester.pumpWidget(h.app);
      await settle(tester);

      expect(find.text('Hello, Asha'), findsOneWidget);
      expect(find.text('Featured jobs'), findsOneWidget);
    });

    testWidgets('a stored cookie the server rejects lands on sign-in',
        (tester) async {
      // A cookie is not proof of a session: the token can be expired, or its
      // `tv` claim can no longer match users.token_version after a
      // "sign out everywhere". Only the server can say, and it says 401.
      final h = Harness();
      h.adapter
        ..onGet('/api/auth/me', (s) => s.reply(401, {'detail': 'Not authenticated.'}))
        ..onGet('/api/branding', (s) => s.reply(200, {'name': 'Jobsflood'}));
      await h.signIn();

      await tester.pumpWidget(h.app);
      await settle(tester);

      expect(find.text('Forgot password?'), findsOneWidget);
      // And the dead cookie is gone, so nothing later fails oddly.
      expect(await h.client.hasStoredSession(), isFalse);
    });
  });

  group('signing in', () {
    testWidgets('with a password reaches Home', (tester) async {
      final h = Harness()..stubCommon();
      h.adapter.onPost('/api/auth/login', (s) {
        // The real flow gets its cookies from Set-Cookie; the mock adapter
        // cannot send headers, so the jar is primed to the same effect.
        return s.reply(200, _user);
      });

      await tester.pumpWidget(h.app);
      await settle(tester);

      await tester.enterText(find.byType(TextFormField).first, 'seeker@x.com');
      await tester.enterText(find.byType(TextFormField).last, 'Seeker@123');
      await h.signIn();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await settle(tester);

      expect(find.text('Hello, Asha'), findsOneWidget);
    });

    testWidgets('a wrong password keeps you on the form with the server message',
        (tester) async {
      final h = Harness()..stubCommon();
      h.adapter.onPost(
        '/api/auth/login',
        (s) => s.reply(401, {'detail': 'Those details do not match an account.'}),
      );

      await tester.pumpWidget(h.app);
      await settle(tester);

      await tester.enterText(find.byType(TextFormField).first, 'seeker@x.com');
      await tester.enterText(find.byType(TextFormField).last, 'wrong');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await settle(tester);

      expect(find.text('Those details do not match an account.'), findsOneWidget);
      expect(find.text('Hello, Asha'), findsNothing);
    });

    testWidgets('the emailed code door reaches Home', (tester) async {
      final h = Harness()..stubCommon();
      h.adapter
        ..onPost(
          '/api/auth/login-code',
          (s) => s.reply(200, {
            'detail': 'If that address has an account, a code is on its way.',
          }),
        )
        ..onPost(
          '/api/auth/forgot-password',
          (s) => s.reply(200, {
            'detail': 'If that address has an account, a reset link is on its way.',
          }),
        )
        ..onPost('/api/auth/login-code/verify', (s) => s.reply(200, _user));

      await tester.pumpWidget(h.app);
      await settle(tester);

      // The sign-in screen no longer offers this door. Its entrance is now
      // Forgot password -> "Or sign in with an emailed code instead", which
      // is the path a person actually takes, so that is the path tested.
      // ensureVisible first: the branded sign-in screen is taller than it was,
      // and a tap on a widget below the fold finds it but hit-tests nothing.
      await tester.ensureVisible(find.text('Forgot password?'));
      await settle(tester);
      await tester.tap(find.text('Forgot password?'));
      await settle(tester);

      // TextField, not TextFormField: the forgot-password screen uses a plain
      // one, so .byType(TextFormField) matched nothing and the finder threw
      // "Bad state: No element" rather than saying what was missing.
      await tester.enterText(find.byType(TextField).first, 'seeker@x.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
      await settle(tester);

      await tester.tap(find.text('Or sign in with an emailed code instead'));
      await settle(tester);
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Email me a code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(find.byType(TextField).last, '123456');
      await h.signIn();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await settle(tester);

      expect(find.text('Hello, Asha'), findsOneWidget);
    });
  });

  group('registration', () {
    testWidgets('creates an account and lands on Home', (tester) async {
      final h = Harness()..stubCommon();
      h.adapter.onPost('/api/auth/register', (s) => s.reply(201, _user));

      await tester.pumpWidget(h.app);
      await settle(tester);

      await tester.tap(find.text('Create an account'));
      await settle(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Asha Rao');
      await tester.enterText(fields.at(1), 'asha@example.com');
      await tester.enterText(fields.at(3), 'Seeker@123');
      await tester.enterText(fields.at(4), 'Seeker@123');

      await h.signIn();
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await settle(tester);

      expect(find.text('Hello, Asha'), findsOneWidget);
    });

    testWidgets('a 422 attaches the server message to its field', (tester) async {
      // app/main.py keeps `loc` intact precisely so a client can do this.
      final h = Harness()..stubCommon();
      h.adapter.onPost(
        '/api/auth/register',
        (s) => s.reply(422, {
          'detail': [
            {
              'loc': ['body', 'email'],
              'msg': 'That address is already registered.',
            },
          ],
        }),
      );

      await tester.pumpWidget(h.app);
      await settle(tester);
      await tester.tap(find.text('Create an account'));
      await settle(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Asha Rao');
      await tester.enterText(fields.at(1), 'taken@example.com');
      await tester.enterText(fields.at(3), 'Seeker@123');
      await tester.enterText(fields.at(4), 'Seeker@123');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await settle(tester);

      expect(find.text('That address is already registered.'), findsOneWidget);
    });
  });

  group('jobs', () {
    Future<Harness> signedIn(WidgetTester tester) async {
      final h = Harness()..stubCommon();
      await h.signIn();
      await tester.pumpWidget(h.app);
      await settle(tester);
      return h;
    }

    testWidgets('search shows the payload total, not the list length',
        (tester) async {
      final h = await signedIn(tester);
      h.adapter.onGet(
        '/api/jobs',
        (s) => s.reply(200, {
          'items': [_job()],
          'total': 137,
          'page': 1,
          'per_page': 20,
        }),
      );

      await tester.tap(find.text('Jobs'));
      await settle(tester);

      expect(find.text('137 jobs'), findsOneWidget);
      expect(find.text('Senior Accountant'), findsWidgets);
    });

    testWidgets('a capped total renders as a floor, not a precise figure',
        (tester) async {
      final h = await signedIn(tester);
      h.adapter.onGet(
        '/api/jobs',
        (s) => s.reply(200, {
          'items': [_job()],
          'total': 500,
          'page': 1,
          'per_page': 20,
          'total_capped': true,
        }),
      );

      await tester.tap(find.text('Jobs'));
      await settle(tester);

      expect(find.text('500+ jobs'), findsOneWidget);
    });

    testWidgets('an empty result offers a way onward', (tester) async {
      final h = await signedIn(tester);
      h.adapter.onGet(
        '/api/jobs',
        (s) => s.reply(200, {
          'items': [],
          'total': 0,
          'page': 1,
          'per_page': 20,
        }),
      );

      await tester.tap(find.text('Jobs'));
      await settle(tester);

      expect(find.text('No jobs matched'), findsOneWidget);
    });

    testWidgets('offline shows the offline state with a retry', (tester) async {
      final h = await signedIn(tester);
      h.adapter.onGet(
        '/api/jobs',
        (s) => s.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/api/jobs'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      await tester.tap(find.text('Jobs'));
      await settle(tester);

      expect(find.text('You appear to be offline'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('opening a job shows its detail and an Apply action',
        (tester) async {
      final h = await signedIn(tester);
      h.adapter
        ..onGet('/api/jobs/41', (s) => s.reply(200, _job()))
        ..onGet(
          '/api/jobs/41/state',
          (s) => s.reply(200, {'job_id': 41, 'has_applied': false, 'is_saved': false}),
        )
        ..onGet('/api/jobs/41/similar', (s) => s.reply(200, {'items': []}));

      await tester.tap(find.text('Senior Accountant').first);
      await settle(tester);

      expect(find.text('Job details'), findsOneWidget);
      expect(find.text('Own the monthly close.'), findsOneWidget);
      expect(find.text('Apply now'), findsOneWidget);
    });

    testWidgets('an already-applied job shows Applied instead of Apply',
        (tester) async {
      final h = await signedIn(tester);
      h.adapter
        ..onGet('/api/jobs/41', (s) => s.reply(200, _job()))
        ..onGet(
          '/api/jobs/41/state',
          (s) => s.reply(200, {'job_id': 41, 'has_applied': true, 'is_saved': false}),
        )
        ..onGet('/api/jobs/41/similar', (s) => s.reply(200, {'items': []}));

      await tester.tap(find.text('Senior Accountant').first);
      await settle(tester);

      expect(find.text('Applied'), findsOneWidget);
      expect(find.text('Apply now'), findsNothing);
    });

    testWidgets('a closed job cannot be applied to', (tester) async {
      final h = await signedIn(tester);
      h.adapter
        ..onGet('/api/jobs/41', (s) => s.reply(200, _job(status: 'closed')))
        ..onGet(
          '/api/jobs/41/state',
          (s) => s.reply(200, {'job_id': 41, 'has_applied': false, 'is_saved': false}),
        )
        ..onGet('/api/jobs/41/similar', (s) => s.reply(200, {'items': []}));

      await tester.tap(find.text('Senior Accountant').first);
      await settle(tester);

      expect(find.text('No longer accepting applications'), findsWidgets);
      expect(find.text('Apply now'), findsNothing);
    });

    testWidgets('applying sends the CSRF header and reports success',
        (tester) async {
      final h = await signedIn(tester);
      final sent = <RequestOptions>[];
      h.client.raw.interceptors.add(InterceptorsWrapper(onRequest: (o, handler) {
        sent.add(o);
        handler.next(o);
      }));

      h.adapter
        ..onGet('/api/jobs/41', (s) => s.reply(200, _job()))
        ..onGet(
          '/api/jobs/41/state',
          (s) => s.reply(200, {'job_id': 41, 'has_applied': false, 'is_saved': false}),
        )
        ..onGet('/api/jobs/41/similar', (s) => s.reply(200, {'items': []}))
        ..onPost(
          '/api/jobs/41/apply',
          (s) => s.reply(201, {
            'id': 9,
            'job_id': 41,
            'status': 'applied',
            'applied_at': '2026-08-31T10:00:00',
          }),
        );

      await tester.tap(find.text('Senior Accountant').first);
      await settle(tester);

      await tester.tap(find.text('Apply now'));
      await settle(tester);
      await tester.tap(find.text('Apply without a note'));
      await settle(tester);

      expect(find.text('Application sent.'), findsOneWidget);

      final apply = sent.firstWhere((o) => o.path.endsWith('/apply'));
      expect(
        apply.headers[csrfHeaderName],
        'csrf-token',
        reason: 'without this the server answers 403 on every write',
      );
    });

    testWidgets('a 409 on apply is shown as the rule refusing', (tester) async {
      final h = await signedIn(tester);
      h.adapter
        ..onGet('/api/jobs/41', (s) => s.reply(200, _job()))
        ..onGet(
          '/api/jobs/41/state',
          (s) => s.reply(200, {'job_id': 41, 'has_applied': false, 'is_saved': false}),
        )
        ..onGet('/api/jobs/41/similar', (s) => s.reply(200, {'items': []}))
        ..onPost(
          '/api/jobs/41/apply',
          (s) => s.reply(409, {'detail': 'You have already applied to this job.'}),
        );

      await tester.tap(find.text('Senior Accountant').first);
      await settle(tester);
      await tester.tap(find.text('Apply now'));
      await settle(tester);
      await tester.tap(find.text('Apply without a note'));
      await settle(tester);

      expect(find.text('You have already applied to this job.'), findsOneWidget);
    });
  });

  group('applications', () {
    testWidgets('the history lists what was sent', (tester) async {
      final h = Harness()..stubCommon();
      await h.signIn();
      h.adapter.onGet(
        '/api/applications/mine',
        (s) => s.reply(200, {
          'items': [
            {
              'id': 9,
              'job_id': 41,
              'status': 'shortlisted',
              'applied_at': '2026-08-20T10:00:00',
              'job': {
                'id': 41,
                'title': 'Senior Accountant',
                'slug': 'x',
                'location': 'Bengaluru',
                'job_type': 'full_time',
                'work_mode': 'onsite',
                'status': 'active',
                'company': {'id': 2, 'name': 'Acme Ltd'},
              },
            },
          ],
          'total': 1,
          'page': 1,
          'per_page': 20,
        }),
      );

      await tester.pumpWidget(h.app);
      await settle(tester);
      await tester.tap(find.text('Applied'));
      await settle(tester);

      expect(find.text('1 application'), findsOneWidget);
      expect(find.text('Shortlisted'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
    });

    testWidgets('withdrawing warns that it is PERMANENT', (tester) async {
      // has_applied counts an application row whatever its stage, so a
      // withdrawal blocks re-applying for good and no recruiter can reverse it.
      // A dialog saying only "Are you sure?" would be hiding that.
      final h = Harness()..stubCommon();
      await h.signIn();
      h.adapter.onGet(
        '/api/applications/mine',
        (s) => s.reply(200, {
          'items': [
            {
              'id': 9,
              'job_id': 41,
              'status': 'applied',
              'applied_at': '2026-08-20T10:00:00',
            },
          ],
          'total': 1,
          'page': 1,
          'per_page': 20,
        }),
      );

      await tester.pumpWidget(h.app);
      await settle(tester);
      await tester.tap(find.text('Applied'));
      await settle(tester);

      await tester.tap(find.text('Withdraw'));
      await settle(tester);

      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(find.text('Withdraw permanently'), findsOneWidget);
      expect(find.text('Keep it'), findsOneWidget);
    });

    testWidgets('an empty history offers a way to find jobs', (tester) async {
      final h = Harness()..stubCommon();
      await h.signIn();
      h.adapter.onGet(
        '/api/applications/mine',
        (s) => s.reply(200, {'items': [], 'total': 0, 'page': 1, 'per_page': 20}),
      );

      await tester.pumpWidget(h.app);
      await settle(tester);
      await tester.tap(find.text('Applied'));
      await settle(tester);

      expect(find.text('No applications yet'), findsOneWidget);
      expect(find.text('Find jobs'), findsOneWidget);
    });
  });

  group('saved jobs', () {
    testWidgets('a saved posting that has closed says so', (tester) async {
      final h = Harness()..stubCommon();
      await h.signIn();
      h.adapter.onGet(
        '/api/seeker/saved',
        (s) => s.reply(200, {
          'items': [
            {'job': _job(status: 'closed'), 'is_open': false},
          ],
          'total': 1,
          'page': 1,
          'per_page': 20,
        }),
      );

      await tester.pumpWidget(h.app);
      await settle(tester);
      await tester.tap(find.text('Saved'));
      await settle(tester);

      expect(find.text('No longer accepting applications'), findsOneWidget);
    });
  });

  group('profile', () {
    testWidgets('shows completeness, CV and skills', (tester) async {
      final h = Harness()..stubCommon();
      await h.signIn();
      h.adapter
        ..onGet('/api/seeker/employment', (s) => s.reply(200, {'items': []}))
        ..onGet('/api/seeker/education', (s) => s.reply(200, {'items': []}))
        ..onGet('/api/seeker/certifications', (s) => s.reply(200, {'items': []}))
        ..onGet('/api/seeker/links', (s) => s.reply(200, {'items': []}));

      await tester.pumpWidget(h.app);
      await settle(tester);
      await tester.tap(find.text('Profile'));
      await settle(tester);

      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('62%'), findsOneWidget);
      expect(find.text('asha-rao.pdf'), findsOneWidget);
      // Verified because the fixture carries email_verified_at — registration
      // alone would leave it NULL. Asserted before scrolling, since the header
      // leaves the viewport once we go looking for the skills.
      expect(find.text('Email verified'), findsOneWidget);

      // Skills sit below the fold on a phone-sized viewport.
      await tester.scrollUntilVisible(find.text('Tally'), 300);
      await settle(tester);
      expect(find.text('Tally'), findsOneWidget);
    });
  });

  group('notifications', () {
    testWidgets('the unread count comes from the payload, not the list',
        (tester) async {
      final h = Harness()..stubCommon();
      await h.signIn();
      // One item, twelve unread. Counting the list here is the "3 views" bug.
      h.adapter.onGet(
        '/api/notifications',
        (s) => s.reply(200, {
          'items': [
            {
              'id': 1,
              'kind': 'application.stage',
              'title': 'You were shortlisted',
              'read': false,
              'created_at': '2026-08-30T09:00:00',
            },
          ],
          'unread': 12,
          'more': true,
        }),
      );

      await tester.pumpWidget(h.app);
      await settle(tester);

      expect(find.text('12'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
      await settle(tester);

      expect(find.text('You were shortlisted'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);
    });
  });

  group('signing out', () {
    testWidgets('calls the server, clears the jar and returns to sign-in',
        (tester) async {
      // Clearing only locally would leave a live token on the server until it
      // expires, which is why the server call is not optional.
      final h = Harness()..stubCommon();
      await h.signIn();
      h.adapter
        ..onGet('/api/seeker/employment', (s) => s.reply(200, {'items': []}))
        ..onGet('/api/seeker/education', (s) => s.reply(200, {'items': []}))
        ..onGet('/api/seeker/certifications', (s) => s.reply(200, {'items': []}))
        ..onGet('/api/seeker/links', (s) => s.reply(200, {'items': []}))
        ..onGet('/api/seeker/viewers', (s) => s.reply(200, {'items': [], 'total': 0}))
        ..onPost('/api/auth/logout', (s) => s.reply(200, {'detail': 'Signed out.'}));

      await tester.pumpWidget(h.app);
      await settle(tester);
      await tester.tap(find.text('Profile'));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await settle(tester);

      await tester.tap(find.text('Sign out'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await settle(tester);

      expect(find.text('Forgot password?'), findsOneWidget);
      expect(await h.client.hasStoredSession(), isFalse);
    });
  });
}
