/// Proves the transport decided in `docs/decisions.md` D-001 actually works.
///
/// Three of these guard failures that are otherwise invisible until a user hits
/// them:
///
///  * **the CSRF header is attached on unsafe verbs and not on safe ones.**
///    Without it every write in the application answers 403 — and it is written
///    once, in an interceptor, so nothing in a feature screen would ever hint at
///    the cause.
///  * **a 401 clears the jar.** Keeping a dead cookie makes every later screen
///    fail in a way that looks like a server fault.
///  * **a 422 body becomes field errors keyed by `loc`.** The server translates
///    pydantic's text into product wording and keeps `loc` intact *specifically*
///    so a client can do this. Getting it wrong means the messages land in a
///    banner instead of on the inputs.
///
/// The mock adapter fakes the **transport**, not the API — the cookie jar,
/// interceptors and error mapping under test are all the real ones.
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:jobportal_mobile/core/errors/api_exception.dart';
import 'package:jobportal_mobile/core/network/api_client.dart';
import 'package:jobportal_mobile/core/network/csrf_interceptor.dart';

const _base = 'http://127.0.0.1:8000';

/// Build a client over an in-memory jar and a fake transport.
({ApiClient client, DioAdapter adapter, CookieJar jar, List<RequestOptions> seen})
    _harness({SessionExpiredCallback? onExpired}) {
  final jar = CookieJar();
  final dio = Dio(BaseOptions(
    baseUrl: _base,
    validateStatus: (s) => s != null && s >= 200 && s < 300,
    headers: {'Accept': 'application/json'},
  ));
  final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());

  final seen = <RequestOptions>[];
  // Appended AFTER the client's own interceptors, so it observes the request as
  // it will actually be sent.
  final client = ApiClient.create(dio: dio, cookieJar: jar, onSessionExpired: onExpired);
  client.raw.interceptors.add(InterceptorsWrapper(
    onRequest: (o, h) {
      seen.add(o);
      h.next(o);
    },
  ));
  // DioAdapter registers itself as httpClientAdapter; keep it that way.
  dio.httpClientAdapter = adapter;

  return (client: client, adapter: adapter, jar: jar, seen: seen);
}

Future<void> _seedCookies(CookieJar jar, {String csrf = 'csrf-value-abc'}) {
  return jar.saveFromResponse(Uri.parse(_base), [
    Cookie(sessionCookieName, 'jwt-value')..path = '/',
    Cookie(csrfCookieName, csrf)..path = '/',
  ]);
}

void main() {
  group('CSRF — the header that makes every write work', () {
    test('an unsafe verb carries X-CSRF-Token from the hh_csrf cookie', () async {
      final h = _harness();
      await _seedCookies(h.jar);
      h.adapter.onPost('/api/jobs/1/apply', (s) => s.reply(201, {'id': 9}));

      await h.client.post<Map<String, dynamic>>('/api/jobs/1/apply', body: {});

      final sent = h.seen.single;
      expect(sent.headers[csrfHeaderName], 'csrf-value-abc',
          reason: 'without this the server answers 403 on every write');
    });

    test('all four unsafe verbs carry it', () async {
      // Written out rather than looped: require_csrf gates each of these
      // independently, and a loop that silently skipped one would still pass.
      Future<void> check(
        String label,
        void Function(DioAdapter a) arrange,
        Future<void> Function(ApiClient c) call,
      ) async {
        final h = _harness();
        await _seedCookies(h.jar);
        arrange(h.adapter);
        await call(h.client);
        expect(h.seen.single.headers[csrfHeaderName], 'csrf-value-abc',
            reason: '$label is an unsafe verb and require_csrf gates it');
      }

      const ok = {'detail': 'ok'};
      await check('POST', (a) => a.onPost('/api/thing', (s) => s.reply(200, ok)),
          (c) => c.post<Map<String, dynamic>>('/api/thing'));
      await check('PUT', (a) => a.onPut('/api/thing', (s) => s.reply(200, ok)),
          (c) => c.put<Map<String, dynamic>>('/api/thing'));
      await check('PATCH', (a) => a.onPatch('/api/thing', (s) => s.reply(200, ok)),
          (c) => c.patch<Map<String, dynamic>>('/api/thing'));
      await check('DELETE', (a) => a.onDelete('/api/thing', (s) => s.reply(200, ok)),
          (c) => c.delete<Map<String, dynamic>>('/api/thing'));
    });

    test('a GET does not carry it — the server exempts safe verbs', () async {
      final h = _harness();
      await _seedCookies(h.jar);
      h.adapter.onGet('/api/jobs', (s) => s.reply(200, {'items': [], 'total': 0}));

      await h.client.get<Map<String, dynamic>>('/api/jobs');

      expect(h.seen.single.headers.containsKey(csrfHeaderName), isFalse);
    });

    test('with no cookie the request still goes, and the SERVER refuses it', () async {
      // Deliberately not a client-side failure: a 403 from the server is a real,
      // diagnosable answer where a local refusal is an invented one no log sees.
      final h = _harness();
      h.adapter.onPost('/api/thing',
          (s) => s.reply(403, {'detail': 'CSRF token missing or invalid.'}));

      await expectLater(
        h.client.post<Map<String, dynamic>>('/api/thing'),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.forbidden)
            .having((e) => e.isProbablyCsrf, 'isProbablyCsrf', isTrue)),
      );
      expect(h.seen.single.headers.containsKey(csrfHeaderName), isFalse);
    });

    test('a 403 on a GET is NOT reported as a CSRF problem', () async {
      // Safe verbs are exempt server-side, so a 403 there is a real
      // authorisation failure and must not send the reader to look at cookies.
      final h = _harness();
      await _seedCookies(h.jar);
      h.adapter.onGet('/api/admin/thing', (s) => s.reply(403, {'detail': 'Forbidden.'}));

      await expectLater(
        h.client.get<Map<String, dynamic>>('/api/admin/thing'),
        throwsA(isA<ApiException>().having((e) => e.isProbablyCsrf, 'isProbablyCsrf', isFalse)),
      );
    });
  });

  group('session expiry', () {
    test('a 401 clears the jar and fires the callback', () async {
      var fired = false;
      final h = _harness(onExpired: () => fired = true);
      await _seedCookies(h.jar);
      expect(await h.client.hasStoredSession(), isTrue);

      h.adapter.onGet('/api/seeker/profile', (s) => s.reply(401, {'detail': 'Not authenticated.'}));

      await expectLater(
        h.client.get<Map<String, dynamic>>('/api/seeker/profile'),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.unauthorised)),
      );

      expect(fired, isTrue);
      expect(await h.client.hasStoredSession(), isFalse,
          reason: 'a dead cookie makes every later screen fail like a server fault');
    });

    test('a 403 does NOT clear the session', () async {
      // Losing the session on a permissions refusal would sign the user out for
      // touching something they were never allowed to touch.
      final h = _harness();
      await _seedCookies(h.jar);
      h.adapter.onPost('/api/thing', (s) => s.reply(403, {'detail': 'Refused.'}));

      await expectLater(h.client.post<Map<String, dynamic>>('/api/thing'),
          throwsA(isA<ApiException>()));
      expect(await h.client.hasStoredSession(), isTrue);
    });

    test('clearSession removes both halves', () async {
      final h = _harness();
      await _seedCookies(h.jar);
      await h.client.clearSession();

      expect(await h.client.hasStoredSession(), isFalse);
      expect(await readCsrfToken(h.jar, Uri.parse(_base)), isNull);
    });
  });

  group('error mapping', () {
    Future<ApiException> capture(Future<void> Function() f) async {
      try {
        await f();
      } on ApiException catch (e) {
        return e;
      }
      fail('expected an ApiException');
    }

    test('422 becomes field errors keyed by the LAST loc element', () async {
      final h = _harness();
      await _seedCookies(h.jar);
      h.adapter.onPost(
        '/api/auth/register',
        (s) => s.reply(422, {
          'detail': [
            {
              'loc': ['body', 'password'],
              'msg': 'Use at least 8 characters.',
              'type': 'value_error',
            },
            {
              'loc': ['body', 'email'],
              'msg': 'Enter a valid email address.',
              'type': 'value_error',
            },
          ],
        }),
      );

      final e = await capture(() => h.client.post('/api/auth/register', body: {}));
      expect(e.kind, ApiErrorKind.validation);
      // The server's own wording, passed through. Paraphrasing it here would
      // undo the boundary translation in app/main.py.
      expect(e.fieldErrors['password'], 'Use at least 8 characters.');
      expect(e.fieldErrors['email'], 'Enter a valid email address.');
    });

    test('the first message per field wins', () async {
      final h = _harness();
      h.adapter.onPost(
        '/api/thing',
        (s) => s.reply(422, {
          'detail': [
            {'loc': ['body', 'password'], 'msg': 'First.'},
            {'loc': ['body', 'password'], 'msg': 'Second.'},
          ],
        }),
      );
      final e = await capture(() => h.client.post('/api/thing', body: {}));
      expect(e.fieldErrors['password'], 'First.');
    });

    test('409 is a rule refusing, not a crash', () async {
      final h = _harness();
      await _seedCookies(h.jar);
      h.adapter.onPost('/api/jobs/1/apply',
          (s) => s.reply(409, {'detail': 'You have already applied to this job.'}));

      final e = await capture(() => h.client.post('/api/jobs/1/apply', body: {}));
      expect(e.kind, ApiErrorKind.conflict);
      expect(e.message, 'You have already applied to this job.');
    });

    test('5xx is retryable; 409 and 422 are not', () async {
      final h = _harness();
      h.adapter
        ..onGet('/api/a', (s) => s.reply(500, {'detail': 'boom'}))
        ..onGet('/api/b', (s) => s.reply(409, {'detail': 'no'}));

      expect((await capture(() => h.client.get('/api/a'))).isRetryable, isTrue);
      expect((await capture(() => h.client.get('/api/b'))).isRetryable, isFalse);
    });

    test('a 500 does not leak the server body to the reader', () async {
      // Never expose a raw stack trace or an internal message.
      final h = _harness();
      h.adapter.onGet('/api/a',
          (s) => s.reply(500, {'detail': 'Traceback: pymysql.err.OperationalError'}));

      final e = await capture(() => h.client.get('/api/a'));
      expect(e.message, isNot(contains('pymysql')));
      expect(e.message, isNot(contains('Traceback')));
    });

    test('429 is not presented as a generic failure', () async {
      final h = _harness();
      h.adapter.onPost('/api/auth/forgot-password', (s) => s.reply(429, {'detail': null}));
      final e = await capture(() => h.client.post('/api/auth/forgot-password', body: {}));
      expect(e.kind, ApiErrorKind.tooManyRequests);
    });

    test('a 2xx with no body is a contract breach, not a null to shrug at', () async {
      final h = _harness();
      h.adapter.onGet('/api/nothing', (s) => s.reply(200, null));

      final e = await capture(() => h.client.get<Map<String, dynamic>>('/api/nothing'));
      expect(e.kind, ApiErrorKind.malformedResponse);
    });

    test('a connection failure reads as offline, not as a server error', () async {
      final h = _harness();
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

      final e = await capture(() => h.client.get('/api/jobs'));
      expect(e.kind, ApiErrorKind.offline);
      expect(e.isRetryable, isTrue);
    });
  });
}
