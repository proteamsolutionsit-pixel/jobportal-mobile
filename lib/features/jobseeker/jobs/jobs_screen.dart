/// Job search.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/autosuggest.dart';
import '../../../core/widgets/states.dart';
import '../../../routing/router.dart';
import '../../../routing/shell.dart';
import 'filter_sheet.dart';
import 'job_card.dart';
import 'jobs_controller.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(jobQueryProvider).q ?? '';
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Infinite scroll. The controller guards re-entry — this fires on every
  /// frame near the end, and one flick would otherwise issue a dozen identical
  /// requests.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      ref.read(jobSearchProvider.notifier).loadMore();
    }
  }

  void _submitSearch(String value) {
    ref.read(jobQueryProvider.notifier).state =
        ref.read(jobQueryProvider).copyWith(q: value);
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(jobSearchProvider);
    final query = ref.watch(jobQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find jobs'),
        actions: const [NotificationBell(), SizedBox(width: Sp.x1)],
      ),
      body: Column(
        children: [
          Container(
            color: C.surface,
            padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x3),
            child: Row(
              children: [
                Expanded(
                  child: Autosuggest(
                    controller: _search,
                    hint: 'Job title, skill or company',
                    prefixIcon: Icons.search_rounded,
                    fetch: (term) =>
                        ref.read(jobsRepositoryProvider).suggestTitles(term),
                    // Whatever is typed searches, chosen from the list or not.
                    onSubmitted: _submitSearch,
                  ),
                ),
                const SizedBox(width: Sp.x2),
                _FilterButton(count: query.filterCount),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: results.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(Sp.x4),
                itemCount: 6,
                separatorBuilder: (_, _) => const SizedBox(height: Sp.x3),
                itemBuilder: (_, _) => const JobCardSkeleton(),
              ),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(jobSearchProvider),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No jobs matched',
                    message: query.hasFilters
                        ? 'Try removing a filter or widening the location.'
                        : 'Try a different job title or skill.',
                    actionLabel: query.hasFilters ? 'Clear filters' : null,
                    onAction: query.hasFilters
                        ? () => ref.read(jobQueryProvider.notifier).state =
                            query.copyWith(clearFilters: true)
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(jobSearchProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.all(Sp.x4),
                    itemCount: page.items.length + 2,
                    separatorBuilder: (_, _) => const SizedBox(height: Sp.x3),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Sp.x1),
                          child: Text(
                            // The payload's total, never items.length — and
                            // when the backend capped its count, "500+" rather
                            // than a precise-looking wrong number.
                            '${resultCount(page.total, capped: page.totalCapped)} '
                            '${page.total == 1 ? 'job' : 'jobs'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      }
                      if (i == page.items.length + 1) {
                        if (page.loadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(Sp.x4),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4),
                              ),
                            ),
                          );
                        }
                        return const SizedBox(height: Sp.x5);
                      }

                      final job = page.items[i - 1];
                      return JobCard(
                        job: job,
                        onTap: () => context.push(Routes.job(job.id)),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: count > 0 ? 'Filters, $count applied' : 'Filters',
      button: true,
      child: SizedBox(
        height: Touch.primary + 4,
        child: OutlinedButton(
          onPressed: () => showJobFilterSheet(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: Sp.x3),
            backgroundColor: count > 0 ? C.brand50 : null,
            side: BorderSide(color: count > 0 ? C.brand200 : C.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune_rounded, size: 18),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Text('$count'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
