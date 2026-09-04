/// Native Google sign-in.
///
/// **Not a webview.** Google refuses OAuth inside an embedded browser
/// (`disallowed_useragent`), so the account picker has to be the platform's
/// own. That is the whole reason this exists rather than the app simply
/// opening `/api/auth/google/start` the way the web client does.
///
/// The token this returns is verified server-side by
/// `POST /api/auth/google/mobile`. Nothing here is trusted.
library;

import 'package:google_sign_in/google_sign_in.dart';

/// Google client ids.
///
/// **Not secrets.** They ship inside every copy of the app and Google's own
/// documentation prints them. The client *secret* belongs to the web client
/// and never leaves the server.
abstract final class GoogleClients {
  /// The audience the backend verifies against — so this is the one the app
  /// must request, NOT the iOS or Android client below.
  ///
  /// `verify_id_token` checks the token's `aud` equals
  /// `settings.google_client_id`, which is this value. A token minted for the
  /// iOS client is refused, correctly: that check is exactly what stops a token
  /// from another application signing someone in here.
  static const server =
      '61359852805-dagr0hepadlvhgef9qlka5klofkp9p7j.apps.googleusercontent.com';

  /// Identifies the app to Google on iOS. Bundle `com.jobsflood.jobportalMobile`.
  static const ios =
      '61359852805-u5qlnoi3doj1v4irvro2sjnscu8m4j6a.apps.googleusercontent.com';

  // Android needs no client id here. The SDK identifies the app by its package
  // name and signing certificate, which is why that OAuth client carries a
  // SHA-1 fingerprint and no secret.
}

/// The reader backed out of the account picker. Not an error, and must not be
/// shown as one.
class GoogleSignInCancelled implements Exception {
  const GoogleSignInCancelled();
}

class GoogleSignInFailed implements Exception {
  const GoogleSignInFailed(this.message);
  final String message;
  @override
  String toString() => message;
}

class GoogleSignInService {
  GoogleSignInService({GoogleSignIn? client})
      : _client = client ??
            GoogleSignIn(
              clientId: GoogleClients.ios,
              serverClientId: GoogleClients.server,
              scopes: const ['email', 'profile'],
            );

  final GoogleSignIn _client;

  /// Runs the platform account picker and returns an ID token for the server.
  Future<String> idToken() async {
    // Sign out first so the picker always appears. Without it a second attempt
    // silently reuses the account chosen last time — wrong precisely when
    // somebody is trying again because the first choice was the wrong account.
    await _client.signOut();

    final account = await _client.signIn();
    if (account == null) throw const GoogleSignInCancelled();

    final auth = await account.authentication;
    final token = auth.idToken;
    if (token == null || token.isEmpty) {
      // Nearly always a configuration fault rather than a user one. On Android
      // it means the SHA-1 registered with Google does not match the key this
      // build was signed with — and the SHA-1 changes under Play App Signing.
      throw const GoogleSignInFailed(
        'Google did not return a sign-in token. Check that this build is '
        'signed with the certificate registered in Google Cloud.',
      );
    }
    return token;
  }

  Future<void> signOut() => _client.signOut();
}
