/// The double-submit half of the session.
///
/// The server issues two cookies (`backend/app/core/security.py`):
///
/// | cookie | httpOnly | why |
/// |---|---|---|
/// | `hh_token` | **yes** | the JWT session. Page JS can never read it. |
/// | `hh_csrf`  | **no**  | must be readable — the client echoes it in a header |
///
/// `deps.py::require_csrf` compares the `hh_csrf` cookie against the
/// `X-CSRF-Token` header with `hmac.compare_digest`, on **every** verb outside
/// `{GET, HEAD, OPTIONS, TRACE}`. Without this interceptor every write in the
/// application answers **403 "CSRF token missing or invalid."** — which is the
/// first bug of any feature milestone that skips it.
///
/// ## Why a native client honours a browser control
///
/// CSRF is a browser problem: an attacker origin can make a browser send cookies
/// but cannot read one to build a header. None of that applies to a Flutter app.
/// The header is sent anyway because the alternative is a **second code path on
/// the server** — and `jobportal-python/CLAUDE.md` is emphatic that auth must not
/// fork. Honouring a control that costs one header is cheaper than owning a
/// bespoke server-side exemption for mobile, forever. See `docs/decisions.md`
/// D-001.
///
/// The value is read from the **jar**, never from a body: `hh_csrf` is only ever
/// delivered as a `Set-Cookie`.
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

/// Verbs the server treats as safe — `deps.py::SAFE_METHODS`.
const _safeMethods = {'GET', 'HEAD', 'OPTIONS', 'TRACE'};

const csrfCookieName = 'hh_csrf';
const csrfHeaderName = 'X-CSRF-Token';

/// The session cookie's name. Not read by this interceptor — it is httpOnly and
/// rides along in the jar — but named here so `logout` can assert it is gone.
const sessionCookieName = 'hh_token';

class CsrfInterceptor extends Interceptor {
  CsrfInterceptor(this._jar);

  final CookieJar _jar;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_safeMethods.contains(options.method.toUpperCase())) {
      return handler.next(options);
    }

    final token = await readCsrfToken(_jar, options.uri);
    if (token != null) {
      options.headers[csrfHeaderName] = token;
    }

    // A missing token is deliberately NOT turned into a local failure. The
    // server is the authority on whether a request is authorised, and a 403
    // from it is a real, diagnosable answer — where a client-side refusal would
    // be an invented one that no server log ever sees. ApiException.isProbablyCsrf
    // exists to make that 403 legible when it happens.
    return handler.next(options);
  }
}

/// Read `hh_csrf` for [uri] out of the jar.
///
/// Exposed for tests and for the logout path, which asserts the pair is gone.
Future<String?> readCsrfToken(CookieJar jar, Uri uri) async {
  final cookies = await jar.loadForRequest(uri);
  for (final cookie in cookies) {
    if (cookie.name == csrfCookieName && cookie.value.isNotEmpty) {
      return cookie.value;
    }
  }
  return null;
}

/// Whether a live session cookie is present for [uri].
///
/// Used on cold start to decide whether calling `/api/auth/me` is worth a round
/// trip. **It is not proof of a valid session** — the token can be expired, or
/// its `tv` claim can no longer match `users.token_version` after a "sign out
/// everywhere". Only the server can answer that, and it answers with a 401.
Future<bool> hasSessionCookie(CookieJar jar, Uri uri) async {
  final cookies = await jar.loadForRequest(uri);
  return cookies.any((c) => c.name == sessionCookieName && c.value.isNotEmpty);
}
