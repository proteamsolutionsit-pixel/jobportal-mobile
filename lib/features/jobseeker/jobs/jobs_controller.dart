/// Search state: the query, the pages, and the saved-state cache.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/jobs_repository.dart';

/// The live filter set. Held above the screen so the filter sheet and the list
/// cannot disagree about it.
final jobQueryProvider = StateProvider<JobQuery>((ref) => const JobQuery());

class JobsPage {
  const JobsPage({
    required this.items,
    required this.total,
    required this.totalCapped,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<JobOut> items;

  /// From the payload. **Never `items.length`.**
  final int total;

  /// When true the total is a floor — the backend stopped counting rather than
  /// running an unbounded `COUNT(*)`. Rendered as "500+".
  final bool totalCapped;

  final int page;
  final bool hasMore;
  final bool loadingMore;

  JobsPage copyWith({
    List<JobOut>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      JobsPage(
        items: items ?? this.items,
        total: total,
        totalCapped: totalCapped,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Paged search results for the current query.
///
/// Keyed on the query, so changing a filter starts a fresh page 1 rather than
/// appending onto results for a different question.
class JobSearchController extends AutoDisposeAsyncNotifier<JobsPage> {
  static const _perPage = 20;

  @override
  Future<JobsPage> build() async {
    final query = ref.watch(jobQueryProvider);
    final result =
        await ref.watch(jobsRepositoryProvider).search(query, page: 1, perPage: _perPage);

    return JobsPage(
      items: result.items,
      total: result.total,
      totalCapped: result.totalCapped,
      page: 1,
      hasMore: result.hasMore,
    );
  }

  /// Append the next page.
  ///
  /// Guarded against re-entry: an infinite-scroll callback fires on every scroll
  /// frame near the end, and without the guard one flick issues a dozen
  /// identical requests.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));

    try {
      final query = ref.read(jobQueryProvider);
      final next = await ref.read(jobsRepositoryProvider).search(
            query,
            page: current.page + 1,
            perPage: _perPage,
          );

      state = AsyncData(current.copyWith(
        items: [...current.items, ...next.items],
        page: current.page + 1,
        hasMore: next.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      // Keep what is already on screen. Replacing a full list with an error
      // because page 4 failed loses everything the reader was looking at.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> refresh() => ref.refresh(jobSearchProvider.future);
}

final jobSearchProvider =
    AsyncNotifierProvider.autoDispose<JobSearchController, JobsPage>(
  JobSearchController.new,
);

/// The home rail — curated, so it reads `/api/home/jobs`.
final homeJobsProvider = FutureProvider.autoDispose<List<JobOut>>((ref) {
  return ref.watch(jobsRepositoryProvider).homeJobs();
});

final suggestedJobsProvider = FutureProvider.autoDispose<List<JobOut>>((ref) {
  return ref.watch(seekerRepositoryProvider).suggested();
});

/// Per-job applied/saved state.
final jobStateProvider =
    FutureProvider.autoDispose.family<JobStateOut, int>((ref, jobId) {
  return ref.watch(jobsRepositoryProvider).state(jobId);
});

final jobDetailProvider =
    FutureProvider.autoDispose.family<JobOut, int>((ref, jobId) {
  return ref.watch(jobsRepositoryProvider).detail(jobId);
});

final similarJobsProvider =
    FutureProvider.autoDispose.family<List<JobOut>, int>((ref, jobId) {
  return ref.watch(jobsRepositoryProvider).similar(jobId);
});
