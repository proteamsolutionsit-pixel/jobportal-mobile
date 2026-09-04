/// Everything that starts, restores or ends a session.
///
/// Both sign-in doors live here together on purpose. The server shares
/// `_complete_sign_in()` between them so that *"a fix to what a successful
/// sign-in does cannot land on one door and not the other"*; the client keeps
/// them in one class for the same reason.
library;

import '../../core/network/api_client.dart';
import '../models/models.dart';

class AuthRepository {
  const AuthRepository(this._api);
  final ApiClient _api;

  /// `POST /api/auth/register` → 201.
  ///
  /// The form offers seeker and recruiter; anything else is **narrowed to
  /// seeker** server-side rather than refused. This app only ever sends seeker.
  ///
  /// **Registration does not verify the address.** `email_verified_at` stays
  /// NULL and the profile says "Unverified" with the remedy beside it — filling
  /// in a form proves nothing about the address in it.
  Future<UserOut> register({
    required String fullName,
    required String email,
    required String password,
    String? passwordConfirm,
    String? phone,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/api/auth/register',
      body: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'password_confirm': ?passwordConfirm,
        'role': 'seeker',
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
    return UserOut.decode(json);
  }

  /// `POST /api/auth/login`. Sets both cookies.
  ///
  /// **An unknown address and a wrong password answer with an identical 401.**
  /// `LoginIn.email` is a plain `str` rather than `EmailStr` for exactly that
  /// reason — a malformed address must get the same 401, or the form becomes an
  /// enumeration oracle. Nothing in this client may distinguish them.
  Future<UserOut> login({required String email, required String password}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    return UserOut.decode(json);
  }

  /// Sign in with a Google ID token from the native SDK.
  ///
  /// The token is verified server-side — signature, audience and
  /// `email_verified` — before any session exists. A 404 here means Google
  /// authenticated the person but this application has no account for that
  /// address, which is deliberate: an OAuth token cannot say whether a new
  /// account should be a seeker, a recruiter or an agency, so none is invented.
  Future<UserOut> loginWithGoogle(String idToken) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/api/auth/google/mobile',
      body: {'id_token': idToken},
    );
    return UserOut.decode(json);
  }

  /// Which third-party sign-in doors the server actually has configured.
  ///
  /// Asked rather than assumed: the button must not appear when the server
  /// cannot honour it. Any failure answers "none", so a flaky call hides the
  /// button rather than offering one that will fail.
  Future<bool> googleAvailable() async {
    try {
      final json =
          await _api.get<Map<String, dynamic>>('/api/auth/providers');
      return json['google'] == true;
    } catch (_) {
      return false;
    }
  }

  /// `POST /api/auth/login-code` — ask for a six-digit code.
  ///
  /// **One answer, always.** The same sentence and the same 200 for a registered
  /// address, an unregistered one, a malformed one, a throttled caller and an
  /// account already over its cap — and a throttled request is deliberately
  /// **not** a 429, because a different status for the same question is itself
  /// an answer. Timing was equalised against a dummy bcrypt hash after a
  /// *measured* oracle was found (declining cost 55 ms where issuing cost
  /// ~900 ms).
  ///
  /// So the caller shows the returned sentence and moves to the code screen,
  /// whatever happened. Branching on the outcome here would rebuild the oracle.
  Future<Message> requestLoginCode(String email) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/api/auth/login-code',
      body: {'email': email},
    );
    return Message.decode(json);
  }

  /// `POST /api/auth/login-code/verify`.
  ///
  /// **Three wrong guesses consume the code** — refusing the fourth while
  /// leaving the code alive would be a rate limit, not a cap. The error copy
  /// must therefore say a *new code* is needed, not "try again", or people sit
  /// on a dead code.
  ///
  /// Signing in this way **stamps `email_verified_at`**, because reading a code
  /// out of the mailbox is precisely the proof that column records.
  Future<UserOut> verifyLoginCode({
    required String email,
    required String code,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/api/auth/login-code/verify',
      body: {'email': email, 'code': code},
    );
    return UserOut.decode(json);
  }

  /// `GET /api/auth/me`. The cold-start session restore.
  Future<UserOut> me() async {
    final json = await _api.get<Map<String, dynamic>>('/api/auth/me');
    return UserOut.decode(json);
  }

  /// `POST /api/auth/logout`.
  ///
  /// **The server call is not optional.** It issues `delete_cookie` for both
  /// halves; clearing only locally leaves a live token until it expires. The
  /// local clear happens either way — a network failure must not strand someone
  /// on a device they are trying to sign out of.
  Future<void> logout() async {
    try {
      await _api.post<Map<String, dynamic>>('/api/auth/logout');
    } finally {
      await _api.clearSession();
    }
  }

  /// `POST /api/auth/logout-everywhere` — bumps `users.token_version`, which
  /// invalidates **every token already issued** on every device. There is no
  /// session table; this is the revocation mechanism.
  Future<void> logoutEverywhere() async {
    try {
      await _api.post<Map<String, dynamic>>('/api/auth/logout-everywhere');
    } finally {
      await _api.clearSession();
    }
  }

  /// `POST /api/auth/forgot-password`. Identical answer for every address —
  /// same rule as `/login-code`.
  Future<Message> forgotPassword(String email) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/api/auth/forgot-password',
      body: {'email': email},
    );
    return Message.decode(json);
  }

  /// `GET /api/auth/reset-password/{token}` — whose account the link is for, so
  /// the screen can say so before asking for a new password.
  Future<String> resetTarget(String token) async {
    final json = await _api.get<Map<String, dynamic>>('/api/auth/reset-password/$token');
    return (json['email'] ?? '').toString();
  }

  Future<Message> resetPassword({
    required String token,
    required String password,
    String? passwordConfirm,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/api/auth/reset-password/$token',
      body: {
        'password': password,
        'password_confirm': ?passwordConfirm,
      },
    );
    return Message.decode(json);
  }

  /// `POST /api/auth/change-password`. Also the screen `must_set_password`
  /// routes to — which is enforced in the auth dependency, not by this redirect.
  Future<Message> changePassword({
    required String currentPassword,
    required String password,
    String? passwordConfirm,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/api/auth/change-password',
      body: {
        'current_password': currentPassword,
        'password': password,
        'password_confirm': ?passwordConfirm,
      },
    );
    return Message.decode(json);
  }

  Future<Message> requestEmailVerification() async {
    final json =
        await _api.post<Map<String, dynamic>>('/api/auth/verify-email/request');
    return Message.decode(json);
  }

  Future<UserOut> verifyEmail(String code) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/api/auth/verify-email',
      body: {'code': code},
    );
    return UserOut.decode(json);
  }

  /// `GET /api/branding` — the site name and logo, which are admin settings.
  /// Falls back rather than failing: a branding call that 404s must not stop the
  /// app from starting.
  Future<Branding> branding() async {
    try {
      final json = await _api.get<Map<String, dynamic>>('/api/branding');
      return Branding.decode(json);
    } catch (_) {
      return Branding.fallback;
    }
  }
}
