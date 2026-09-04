/// Who is signed in, and everything that changes that.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../data/models/models.dart';

/// The session, as the shell needs to see it.
sealed class AuthState {
  const AuthState();
}

/// Before the cold-start `/api/auth/me` has answered. The splash holds here.
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn(this.user);
  final UserOut user;

  /// **Enforced in the auth dependency, not by this redirect.** A client that
  /// ignored it would still be refused server-side; honouring it is the right
  /// UX, not the control.
  bool get mustSetPassword => user.mustSetPassword;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // A 401 anywhere in the app drops the session here too, so no screen is
    // left rendering a signed-in shell over a dead cookie.
    ref.listen(sessionExpiredProvider, (previous, next) {
      if (previous != null && next > previous) state = const SignedOut();
    });
    return const AuthUnknown();
  }

  /// Cold start. Cheap when there is no cookie at all; a round trip otherwise.
  ///
  /// **A stored cookie is not proof of a valid session** — the token can be
  /// expired, or its `tv` claim can no longer match `users.token_version` after
  /// a "sign out everywhere". Only the server can answer that, and it answers
  /// with a 401.
  Future<void> restore() async {
    final api = ref.read(apiClientProvider);
    if (!await api.hasStoredSession()) {
      state = const SignedOut();
      return;
    }
    try {
      state = SignedIn(await ref.read(authRepositoryProvider).me());
    } on ApiException {
      // Including the 401, which the client has already used to clear the jar.
      state = const SignedOut();
    }
  }

  Future<UserOut> login({required String email, required String password}) async {
    final user = await ref.read(authRepositoryProvider).login(
          email: email,
          password: password,
        );
    state = SignedIn(user);
    return user;
  }

  /// Sign in with Google.
  ///
  /// Two steps, and the split matters: the SDK produces a token, and the SERVER
  /// decides whether it means anything. Nothing here inspects the token or
  /// trusts a single claim in it.
  Future<UserOut> loginWithGoogle(String idToken) async {
    final user =
        await ref.read(authRepositoryProvider).loginWithGoogle(idToken);
    state = SignedIn(user);
    return user;
  }

  Future<UserOut> verifyLoginCode({
    required String email,
    required String code,
  }) async {
    final user = await ref.read(authRepositoryProvider).verifyLoginCode(
          email: email,
          code: code,
        );
    state = SignedIn(user);
    return user;
  }

  Future<UserOut> register({
    required String fullName,
    required String email,
    required String password,
    String? passwordConfirm,
    String? phone,
  }) async {
    final user = await ref.read(authRepositoryProvider).register(
          fullName: fullName,
          email: email,
          password: password,
          passwordConfirm: passwordConfirm,
          phone: phone,
        );
    state = SignedIn(user);
    return user;
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const SignedOut();
  }

  /// Bumps `users.token_version`, killing every token already issued on every
  /// device. There is no session table; this is the revocation mechanism.
  Future<void> logoutEverywhere() async {
    await ref.read(authRepositoryProvider).logoutEverywhere();
    state = const SignedOut();
  }

  /// Drop the session locally without calling the server.
  ///
  /// For the one case where the server has already ended it: deleting the
  /// account. Calling `/api/auth/logout` afterwards would be a request from an
  /// account that no longer exists.
  void markSignedOut() => state = const SignedOut();

  /// After a password change or an email verification, so the shell picks up
  /// `must_set_password` clearing and the verified badge.
  Future<void> refresh() async {
    try {
      state = SignedIn(await ref.read(authRepositoryProvider).me());
    } on ApiException {
      state = const SignedOut();
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// The signed-in user, or null. For screens that only need the identity.
final currentUserProvider = Provider<UserOut?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is SignedIn ? state.user : null;
});
