/// Dependency graph.
///
/// Riverpod because a provider is **overridable without a global**: a widget
/// test substitutes the API client by wrapping the tree in a `ProviderScope`
/// with one override, and the repository layer is testable with no widget tree
/// at all. That testability is the reason for the choice — recorded in
/// `docs/decisions.md` D-004.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/companies_repository.dart';
import '../data/repositories/jobs_repository.dart';
import '../data/repositories/seeker_repository.dart';
import 'auth/google_sign_in_service.dart';
import 'network/api_client.dart';

/// The session-expiry signal.
///
/// The client cannot route by itself — routing is the shell's job — so a 401
/// flips this and the router redirects. Kept as a counter rather than a bool so
/// two expiries in a row are two events, not one swallowed by equality.
final sessionExpiredProvider = StateProvider<int>((ref) => 0);

/// **Overridden in tests** with a client over a mock adapter. Nothing else in
/// the app constructs an `ApiClient`.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.create(
    onSessionExpired: () {
      ref.read(sessionExpiredProvider.notifier).state++;
    },
  );
});

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));

final jobsRepositoryProvider =
    Provider<JobsRepository>((ref) => JobsRepository(ref.watch(apiClientProvider)));

final seekerRepositoryProvider =
    Provider<SeekerRepository>((ref) => SeekerRepository(ref.watch(apiClientProvider)));

final companiesRepositoryProvider = Provider<CompaniesRepository>(
    (ref) => CompaniesRepository(ref.watch(apiClientProvider)));

/// One page of the company directory, keyed by the search text.
///
/// `autoDispose` with a family: without it every distinct query the reader
/// types would keep its own result alive for the life of the app.
final companyDirectoryProvider =
    FutureProvider.autoDispose.family<CompanyListOut, String>((ref, q) async {
  return ref.watch(companiesRepositoryProvider).list(q: q);
});

final companyDetailProvider =
    FutureProvider.autoDispose.family<CompanyDetailOut, int>((ref, id) async {
  return ref.watch(companiesRepositoryProvider).detail(id);
});

/// Site name and logo. Server-supplied settings, not constants — an uploaded
/// logo overrides the bundled one, so hardcoding either would leave the app
/// showing something the product has moved on from.
/// Whether the SERVER has Google sign-in configured.
///
/// The button is rendered only when this is true, mirroring the web client.
/// Asked rather than assumed: offering a door the server cannot open is a
/// worse failure than not offering it.
final googleAvailableProvider = FutureProvider<bool>((ref) async {
  return ref.watch(authRepositoryProvider).googleAvailable();
});

/// The native Google SDK wrapper. Overridden in tests.
final googleSignInServiceProvider =
    Provider<GoogleSignInService>((ref) => GoogleSignInService());

final brandingProvider = FutureProvider<Branding>((ref) async {
  return ref.watch(authRepositoryProvider).branding();
});
