/// The one HTTP client. Everything the app sends goes through here.
///
/// Assembles what `docs/decisions.md` D-001 decided:
///
///  1. a **persisted cookie jar** in Android Keystore / iOS Keychain, holding
///     the `hh_token` session and the `hh_csrf` half;
///  2. a **CSRF interceptor** putting `X-CSRF-Token` on every unsafe verb;
///  3. **one place** that turns a `DioException` into an [ApiException];
///  4. a **session-expiry hook** that clears the jar on 401.
///
/// No backend change was needed for any of it, which was the point.
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../config/environment.dart';
import '../errors/api_exception.dart';
import '../storage/secure_cookie_storage.dart';
import 'csrf_interceptor.dart';

/// Called when the server says the session is gone.
typedef SessionExpiredCallback = void Function();

class ApiClient {
  ApiClient._(this._dio, this.jar);

  final Dio _dio;

  /// Exposed so the auth layer can clear it on sign-out and inspect it on cold
  /// start. Nothing else should touch it.
  final CookieJar jar;

  Dio get raw => _dio;

  /// Build the production client.
  ///
  /// [onSessionExpired] fires on the first 401 after a live session. The app
  /// clears the jar, routes to sign-in remembering where the reader was, and
  /// offers "Email me a sign-in code" — which is a genuinely good re-auth on a
  /// phone, because the mail arrives on the same device.
  ///
  /// That flow exists because **the session is 12 hours with no refresh**
  /// (`access_token_minutes = 720`, and refresh-token rotation is listed under
  /// *Not done* on the server). Task MOB-B-001 covers the real fix; this is the
  /// honest interim, not a workaround pretending to be one.
  factory ApiClient.create({
    SessionExpiredCallback? onSessionExpired,
    CookieJar? cookieJar,
    Dio? dio,
  }) {
    Env.assertValid();

    final jar = cookieJar ?? PersistCookieJar(storage: SecureCookieStorage());

    final client = dio ??
        Dio(BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 60), // uploads
          headers: {'Accept': 'application/json'},
          // Dio must not throw for us — every non-2xx is turned into a typed
          // ApiException below, in one place.
          validateStatus: (s) => s != null && s >= 200 && s < 300,
        ));

    // ORDER MATTERS. CookieManager must run first on the request so the jar has
    // attached `hh_csrf` before CsrfInterceptor reads it, and first on the
    // response so a fresh `Set-Cookie` is stored before anything reacts to the
    // body.
    client.interceptors.add(CookieManager(jar));
    client.interceptors.add(CsrfInterceptor(jar));

    if (Env.verboseLogging) {
      // Development only, and headers stay off even here: the request headers
      // carry the session cookie and the CSRF token, and a response body on
      // /api/seeker/profile is somebody's personal data.
      client.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
      ));
    }

    client.interceptors.add(InterceptorsWrapper(
      onError: (e, handler) async {
        final failure = ApiException.from(e);

        if (failure.kind == ApiErrorKind.unauthorised) {
          // Clear locally whatever the reason — expired, revoked by a "sign out
          // everywhere", or the account disabled. All three mean the same thing
          // to this client, and keeping a dead cookie makes every later screen
          // fail in a way that looks like a server fault.
          await jar.deleteAll();
          onSessionExpired?.call();
        }

        return handler.reject(
          DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: failure,
          ),
        );
      },
    ));

    return ApiClient._(client, jar);
  }

  // -------------------------------------------------------------------------
  // Verbs. Each returns the decoded body and throws ApiException on anything
  // else, so no caller ever handles a DioException.
  // -------------------------------------------------------------------------

  Future<T> get<T>(String path, {Map<String, dynamic>? query, CancelToken? cancelToken}) =>
      _send(() => _dio.get<T>(path, queryParameters: query, cancelToken: cancelToken));

  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query, CancelToken? cancelToken}) =>
      _send(() => _dio.post<T>(path, data: body, queryParameters: query, cancelToken: cancelToken));

  Future<T> put<T>(String path, {Object? body, CancelToken? cancelToken}) =>
      _send(() => _dio.put<T>(path, data: body, cancelToken: cancelToken));

  Future<T> patch<T>(String path, {Object? body, CancelToken? cancelToken}) =>
      _send(() => _dio.patch<T>(path, data: body, cancelToken: cancelToken));

  Future<T> delete<T>(String path, {Object? body, CancelToken? cancelToken}) =>
      _send(() => _dio.delete<T>(path, data: body, cancelToken: cancelToken));

  Future<T> _send<T>(Future<Response<T>> Function() call) async {
    try {
      final response = await call();
      final data = response.data;
      if (data == null) {
        // A 2xx with no body where one was declared is a contract breach, not a
        // null to shrug at. Silence is not success.
        throw ApiException(
          kind: ApiErrorKind.malformedResponse,
          message: 'The server answered successfully but sent no content.',
          statusCode: response.statusCode,
          method: response.requestOptions.method,
          path: response.requestOptions.path,
        );
      }
      return data;
    } on DioException catch (e) {
      final wrapped = e.error;
      if (wrapped is ApiException) throw wrapped;
      throw ApiException.from(e);
    }
  }

  /// Drop the local session. Called by sign-out **after** the server call, and
  /// by the 401 path above.
  ///
  /// Clearing only locally would leave a live token on the server until it
  /// expires, which is why `POST /api/auth/logout` is not optional — it issues
  /// `delete_cookie` for both halves.
  Future<void> clearSession() => jar.deleteAll();

  /// Whether a session cookie is present. **Not proof it is valid** — only the
  /// server can say that, and it says it with a 401.
  Future<bool> hasStoredSession() =>
      hasSessionCookie(jar, Uri.parse(Env.apiBaseUrl));
}
