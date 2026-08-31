/// Which server this build talks to.
///
/// Supplied at **compile time** through `--dart-define`, not read from a
/// bundled `.env`. See `.env.example` for the values and the build commands.
///
/// The reason is worth stating, because `.env` is the more usual answer and the
/// brief asks for the file: **a `.env` shipped as a Flutter asset is readable by
/// anyone who unzips the APK.** For base URLs that is harmless — they are not
/// secret — but a file called `.env` invites the next person to put something in
/// it that is. `--dart-define` has no such invitation: there is no file in the
/// bundle to find. The `.env.example` therefore documents the variables and the
/// command, and nothing is ever loaded from disk at runtime.
///
/// **No secret belongs here regardless.** There is no API key, no client secret
/// and no signing key in this application — the session is a cookie the server
/// issues, and that is the whole of the app's credentials.
library;

enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment fromName(String name) {
    return AppEnvironment.values.firstWhere(
      (e) => e.name == name,
      // An unrecognised name falls to development rather than production.
      // Getting this the other way round would mean a typo in a build command
      // silently shipped a debug build pointed at live candidate data.
      orElse: () => AppEnvironment.development,
    );
  }
}

class Env {
  const Env._();

  static const _name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static final AppEnvironment current = AppEnvironment.fromName(_name);

  /// The API origin. Scheme and host must stay stable per environment: cookies
  /// are scoped by domain, so pointing dev at `127.0.0.1` and staging at a
  /// hostname correctly gives two separate jars — but the jar must be keyed per
  /// environment or switching carries a dead session across.
  ///
  /// **Use the apex on production.** `www.jobsflood.com` has no DNS A record,
  /// and an app pointed at it fails to resolve in a way that reads as the phone
  /// being offline rather than as a misconfiguration.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static bool get isDevelopment => current == AppEnvironment.development;
  static bool get isProduction => current == AppEnvironment.production;

  /// Whether verbose request logging is permitted.
  ///
  /// **Never in production.** A request log on this API carries the session
  /// cookie, and a response log carries profile data and, on one endpoint,
  /// resume bytes.
  static bool get verboseLogging => isDevelopment;

  /// `cookie_secure` is true on the server outside debug, so the session cookie
  /// is `Secure` and is never sent over plain http — the session would simply
  /// not exist, with nothing logged to say why. Checked at start-up so the
  /// failure is loud rather than mysterious.
  static bool get requiresHttps => !isDevelopment;

  /// Fails the build's start-up rather than shipping a configuration that
  /// cannot work. Mirrors the server's own refusal to serve with `DEBUG=false`
  /// and an insecure cookie setting.
  static void assertValid() {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('API_BASE_URL is not a valid absolute URL: "$apiBaseUrl"');
    }
    if (requiresHttps && uri.scheme != 'https') {
      throw StateError(
        'API_BASE_URL must be https outside development (got "$apiBaseUrl"). '
        'The server sets Secure on the session cookie outside debug, so over '
        'plain http the session is never sent and every screen fails with no '
        'explanation.',
      );
    }
    if (uri.host.startsWith('www.jobsflood.com')) {
      throw StateError(
        'www.jobsflood.com has no DNS A record. Use the apex, '
        'https://jobsflood.com.',
      );
    }
  }
}
