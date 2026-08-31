/// One error type for everything the API and the network can do to us.
///
/// Centralised because the alternative is every screen inventing its own
/// wording for a 401, and because two of these cases carry rules that must not
/// be re-decided per screen:
///
///  * **A 422 carries `loc`.** `app/main.py` translates pydantic's own text into
///    product wording at the boundary and keeps `loc` intact *specifically* so a
///    client can attach each message to its field. Inventing client copy here
///    would undo that — the library's own text reaching a screen ("String should
///    have at least 8 characters" under a password box) is the bug that handler
///    exists to prevent, and so is our own paraphrase of it.
///  * **A 403 from an unsafe verb is almost always a missing CSRF header**, not
///    an authorisation failure. Saying "you do not have permission" there sends
///    the reader to look in the wrong place.
library;

import 'package:dio/dio.dart';

enum ApiErrorKind {
  /// No network, DNS failure, connection refused.
  offline,

  /// Connect, send or receive timed out.
  timeout,

  /// 401 — no session, expired session, or a token whose `tv` claim no longer
  /// matches `users.token_version` (someone signed out everywhere, or the
  /// account was disabled). All three are the same thing to the client: sign in
  /// again.
  unauthorised,

  /// 403. On an unsafe verb, read [isProbablyCsrf] before blaming permissions.
  forbidden,

  /// 404.
  notFound,

  /// 409 — a rule refused. Applying twice; a recruiter trying to set
  /// `withdrawn`.
  conflict,

  /// 422 — field validation. [fieldErrors] is populated.
  validation,

  /// 429 — rate limited.
  tooManyRequests,

  /// 400, and anything else in the 4xx range.
  badRequest,

  /// 5xx.
  server,

  /// The transport worked and the body was not what the contract declared.
  ///
  /// **This is a real error and must not be swallowed.** A client that quietly
  /// accepts an unexpected shape hides a server sending the wrong one — the web
  /// build lost four screens to exactly that tolerance, silently, because its
  /// client had been written to accept either shape.
  malformedResponse,

  /// The request was cancelled by us.
  cancelled,

  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.method,
    this.path,
    this.cause,
  });

  final ApiErrorKind kind;

  /// What to show the reader. **For a 422 this is the server's own sentence**,
  /// not ours.
  final String message;

  final int? statusCode;

  /// Field name → message, built from the 422 body's `loc`. Attach each to its
  /// input rather than dumping them in a banner.
  final Map<String, String> fieldErrors;

  final String? method;
  final String? path;
  final Object? cause;

  /// A 403 on a mutating request is far more often the CSRF header being absent
  /// than a permissions problem: `require_csrf` is a dependency on every unsafe
  /// route and answers exactly this.
  bool get isProbablyCsrf =>
      kind == ApiErrorKind.forbidden &&
      method != null &&
      !const {'GET', 'HEAD', 'OPTIONS', 'TRACE'}.contains(method!.toUpperCase());

  /// Whether retrying could plausibly help. **Applying for a job is excluded by
  /// the caller regardless** — a retry after a 500 can produce a second
  /// application row if the first partially succeeded, and applying twice is not
  /// recoverable from the candidate's side.
  bool get isRetryable =>
      kind == ApiErrorKind.offline ||
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.server;

  @override
  String toString() => 'ApiException($kind, $statusCode, $message)';

  // -------------------------------------------------------------------------

  static ApiException from(DioException e) {
    final method = e.requestOptions.method;
    final path = e.requestOptions.path;
    final status = e.response?.statusCode;

    ApiException build(ApiErrorKind kind, String message,
            {Map<String, String> fields = const {}}) =>
        ApiException(
          kind: kind,
          message: message,
          statusCode: status,
          fieldErrors: fields,
          method: method,
          path: path,
          cause: e,
        );

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return build(ApiErrorKind.timeout,
            'The server took too long to answer. Check your connection and try again.');
      case DioExceptionType.connectionError:
        return build(ApiErrorKind.offline,
            'Cannot reach JobPortal. Check your internet connection.');
      case DioExceptionType.cancel:
        return build(ApiErrorKind.cancelled, 'Cancelled.');
      case DioExceptionType.badCertificate:
        return build(ApiErrorKind.offline,
            'The connection to JobPortal could not be verified securely.');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    if (status == null) {
      return build(ApiErrorKind.unknown, 'Something went wrong. Please try again.');
    }

    final body = e.response?.data;
    final detail = _detail(body);

    switch (status) {
      case 400:
        return build(ApiErrorKind.badRequest, detail ?? 'That request could not be processed.');
      case 401:
        // Deliberately one sentence for every cause. The server answers an
        // unknown address and a wrong password with an identical 401 so the
        // form is not an enumeration oracle; restating that distinction here
        // would rebuild the oracle on the client.
        return build(ApiErrorKind.unauthorised,
            detail ?? 'Your session has ended. Please sign in again.');
      case 403:
        return build(ApiErrorKind.forbidden,
            detail ?? 'That action was refused. Please try again.');
      case 404:
        return build(ApiErrorKind.notFound, detail ?? 'That could not be found.');
      case 409:
        return build(ApiErrorKind.conflict, detail ?? 'That is no longer possible.');
      case 422:
        final fields = _fieldErrors(body);
        return build(
          ApiErrorKind.validation,
          detail ?? (fields.isNotEmpty ? fields.values.first : 'Please check the form.'),
          fields: fields,
        );
      case 429:
        return build(ApiErrorKind.tooManyRequests,
            detail ?? 'Too many attempts. Please wait a little and try again.');
    }

    if (status >= 500) {
      return build(ApiErrorKind.server,
          'JobPortal had a problem answering. Please try again shortly.');
    }
    return build(ApiErrorKind.unknown, detail ?? 'Something went wrong.');
  }

  /// FastAPI's `{"detail": "..."}`. When `detail` is a list it is the validation
  /// shape and is handled by [_fieldErrors] instead.
  static String? _detail(Object? body) {
    if (body is Map && body['detail'] is String) {
      final s = (body['detail'] as String).trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  /// Turn the 422 body into field → message.
  ///
  /// `loc` is `["body", "password"]` or `["query", "page"]`; the **last** string
  /// element is the field. The server keeps `loc` intact precisely so this is
  /// possible, and uses its own wording in `msg` — which is why `msg` is passed
  /// through untouched.
  static Map<String, String> _fieldErrors(Object? body) {
    if (body is! Map) return const {};
    final detail = body['detail'];
    if (detail is! List) return const {};

    final out = <String, String>{};
    for (final item in detail) {
      if (item is! Map) continue;
      final msg = item['msg'];
      if (msg is! String || msg.isEmpty) continue;

      final loc = item['loc'];
      String field = '_';
      if (loc is List && loc.isNotEmpty) {
        final names = loc.whereType<String>().toList();
        if (names.isNotEmpty) field = names.last;
      }
      // First message per field wins — a second on the same input is almost
      // always a consequence of the first, and stacking them reads as noise.
      out.putIfAbsent(field, () => msg);
    }
    return out;
  }
}
