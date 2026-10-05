/// Job search.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/autosuggest.dart';
import '../../../core/widgets/common.dart';
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

  /// Search as you type. Results used to change only on the keyboard's
  /// search key, so typing and tapping away searched nothing and the tab
  /// looked broken. Debounced, and only from two letters (or an empty box),
  /// so a word is not searched letter by letter — the API's LIKE path is a
  /// scan on a miss, which is exactly what a half-typed word is.
  Timer? _typing;

  void _onTyped() {
    _typing?.cancel();
    final text = _search.text.trim();
    if (text.isNotEmpty && text.length < 2) return;
    _typing = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if ((ref.read(jobQueryProvider).q ?? '') != text) _submitSearch(text);
    });
  }

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(jobQueryProvider).q ?? '';
    _search.addListener(_onTyped);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _typing?.cancel();
    _search.removeListener(_onTyped);
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
    _typing?.cancel();
    ref.read(jobQueryProvider.notifier).state =
        ref.read(jobQueryProvider).copyWith(q: value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(jobSearchProvider);
    final query = ref.watch(jobQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle('Find jobs'),
        actions: const [NotificationBell(), SizedBox(width: Sp.x1)],
      ),
      body: Column(
        children: [
          // The search lives on the brand gradient, as the web's hero does.
          DecoratedBox(
            decoration: const BoxDecoration(gradient: Gradients.hero0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, Sp.x3),
              child: Column(
                children: [
                  Row(
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
                  const SizedBox(height: Sp.x3),
                  _WorkModeChips(selected: query.workModes),
                ],
              ),
            ),
          ),

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
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Sp.x3,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Tones.ok.wash,
                                borderRadius: R.brPill,
                                border: Border.all(color: Tones.ok.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.work_rounded, size: 14, color: Tones.ok.ink),
                                  const SizedBox(width: 6),
                                  Text(
                                    // The payload's total, never items.length —
                                    // and when the backend capped its count,
                                    // "500+" rather than a precise-looking
                                    // wrong number.
                                    '${resultCount(page.total, capped: page.totalCapped)} '
                                    '${page.total == 1 ? 'job' : 'jobs'} open now',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Tones.ok.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

/// One-tap work-mode filter: the most common narrowing, kept out of the
/// sheet. It writes the same `work_modes` the filter sheet does, so the two
/// never disagree.
class _WorkModeChips extends ConsumerWidget {
  const _WorkModeChips({required this.selected});
  final List<String> selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void pick(List<String> modes) {
      final q = ref.read(jobQueryProvider);
      ref.read(jobQueryProvider.notifier).state = q.copyWith(workModes: modes);
    }

    Widget chip(String label, IconData icon, List<String> modes) {
      final on = modes.isEmpty
          ? selected.isEmpty
          : selected.length == 1 && selected.first == modes.first;
      return Padding(
        padding: const EdgeInsets.only(right: Sp.x2),
        child: Material(
          color: on ? Colors.white : Colors.white.withValues(alpha: 0.16),
          borderRadius: R.brPill,
          child: InkWell(
            borderRadius: R.brPill,
            onTap: () => pick(modes),
            child: Container(
              constraints: const BoxConstraints(minHeight: Touch.min + 2),
              padding: const EdgeInsets.symmetric(horizontal: Sp.x3),
              decoration: BoxDecoration(
                borderRadius: R.brPill,
                border: Border.all(color: Colors.white.withValues(alpha: on ? 1 : 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: on ? C.brand600 : Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: on ? C.brand700 : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: Touch.min + 2,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('All jobs', Icons.apps_rounded, const []),
          chip(labelFor(workModeLabels, 'remote'), Icons.home_work_outlined, const ['remote']),
          chip(labelFor(workModeLabels, 'hybrid'), Icons.sync_alt_rounded, const ['hybrid']),
          chip(labelFor(workModeLabels, 'onsite'), Icons.apartment_rounded, const ['onsite']),
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
            backgroundColor: Colors.white,
            foregroundColor: C.brand600,
            side: BorderSide(color: count > 0 ? C.brand300 : Colors.white),
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
