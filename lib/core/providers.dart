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
import '../data/repositories/jobs_repository.dart';
import '../data/repositories/seeker_repository.dart';
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

/// Site name and logo. Server-supplied settings, not constants — an uploaded
/// logo overrides the bundled one, so hardcoding either would leave the app
/// showing something the product has moved on from.
final brandingProvider = FutureProvider<Branding>((ref) async {
  return ref.watch(authRepositoryProvider).branding();
});
