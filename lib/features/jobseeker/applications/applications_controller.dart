/// Application history.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/models/models.dart';

class ApplicationsPage {
  const ApplicationsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<MyApplicationOut> items;

  /// From the payload, never `items.length`.
  final int total;

  final int page;
  final bool hasMore;
  final bool loadingMore;

  ApplicationsPage copyWith({
    List<MyApplicationOut>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      ApplicationsPage(
        items: items ?? this.items,
        total: total,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class ApplicationsController extends AutoDisposeAsyncNotifier<ApplicationsPage> {
  static const _perPage = 20;

  @override
  Future<ApplicationsPage> build() async {
    final result = await ref
        .watch(seekerRepositoryProvider)
        .applications(page: 1, perPage: _perPage);

    return ApplicationsPage(
      items: result.items,
      total: result.total,
      page: 1,
      hasMore: result.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref.read(seekerRepositoryProvider).applications(
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
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  /// Withdraw.
  ///
  /// **Permanent, and the caller must have confirmed that in those words.**
  /// `has_applied` counts an application row whatever its stage, so a withdrawn
  /// application still blocks re-applying, and a recruiter cannot reverse it
  /// either — `set_stage` refuses `withdrawn` with a 409. Nothing in the product
  /// can undo this.
  ///
  /// The list is re-fetched rather than patched in place: `jobs.application_count`
  /// is **recomputed** server-side on withdrawal rather than decremented, and
  /// adjusting anything client-side would re-invent the drift that fix removed.
  Future<void> withdraw(int applicationId) async {
    await ref.read(seekerRepositoryProvider).withdraw(applicationId);
    ref.invalidateSelf();
    await future;
  }
}

final applicationsProvider =
    AsyncNotifierProvider.autoDispose<ApplicationsController, ApplicationsPage>(
  ApplicationsController.new,
);
