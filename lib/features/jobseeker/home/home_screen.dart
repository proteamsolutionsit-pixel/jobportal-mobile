/// Home.
///
/// The rail reads **`/api/home/jobs`, not `/api/jobs?per_page=8`** — the latter
/// is a filterless public listing that cannot know about the admin's curation
/// (`is_featured`, `featured_rank`), which is why the chosen order once had no
/// route to the page it was chosen for.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/states.dart';
import '../../../routing/router.dart';
import '../../../routing/shell.dart';
import '../authentication/auth_controller.dart';
import '../jobs/job_card.dart';
import '../jobs/jobs_controller.dart';
import '../profile/profile_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final brand = ref.watch(brandingProvider).valueOrNull;
    final featured = ref.watch(homeJobsProvider);
    final suggested = ref.watch(suggestedJobsProvider);
    final profile = ref.watch(profileProvider);

    final firstName =
        (user?.fullName ?? '').split(RegExp(r'\s+')).firstWhere(
              (s) => s.isNotEmpty,
              orElse: () => 'there',
            );

    return Scaffold(
      appBar: AppBar(
        title: Text(brand?.name ?? 'JobPortal'),
        actions: const [NotificationBell(), SizedBox(width: Sp.x1)],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeJobsProvider);
          ref.invalidate(suggestedJobsProvider);
          ref.invalidate(profileProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x6),
          children: [
            Text(
              'Hello, $firstName',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: Sp.x1),
            Text(
              'Here is what is new for you today.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Sp.x4),

            // Search entry point. Tapping goes to the Jobs tab rather than
            // opening a second search — one search screen, one filter state.
            InkWell(
              onTap: () => context.go(Routes.jobs),
              borderRadius: R.brMd,
              child: Container(
                height: Touch.primary + 6,
                padding: const EdgeInsets.symmetric(horizontal: Sp.x3),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: R.brMd,
                  border: Border.all(color: C.lineStrong),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 20, color: C.ink500),
                    const SizedBox(width: Sp.x3),
                    // Expanded, not bare: at 390px the unconstrained Text
                    // overflowed the row by 156px. Found by running the flow
                    // tests at a real phone width rather than the 800px
                    // default — which is exactly why they run at one.
                    Expanded(
                      child: Text(
                        'Search jobs, skills or companies',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Sp.x5),

            // Profile completeness. Read from the server, never computed here —
            // it is rescored on every write and is a campaign-targeting filter,
            // so a locally-guessed figure would disagree with the one that
            // actually decides things.
            profile.maybeWhen(
              data: (p) => p.profileCompleteness >= 100
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: Sp.x5),
                      child: _CompletenessCard(
                        percent: p.profileCompleteness,
                        hasResume: p.hasResume,
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),

            _Rail(
              title: 'Featured jobs',
              jobs: featured,
              onSeeAll: () => context.go(Routes.jobs),
            ),

            const SizedBox(height: Sp.x5),

            _Rail(
              title: 'Suggested for you',
              jobs: suggested,
              emptyMessage:
                  'Add your skills and experience and we will match you to roles.',
              onSeeAll: () => context.go(Routes.jobs),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletenessCard extends StatelessWidget {
  const _CompletenessCard({required this.percent, required this.hasResume});

  final int percent;
  final bool hasResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.x4),
      decoration: BoxDecoration(
        color: C.brand50,
        borderRadius: R.brLg,
        border: Border.all(color: C.brand100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your profile is $percent% complete',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: C.brand700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x3),
          ClipRRect(
            borderRadius: BorderRadius.circular(R.pill),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              backgroundColor: C.brand100,
            ),
          ),
          const SizedBox(height: Sp.x3),
          Text(
            hasResume
                ? 'A fuller profile means more recruiters find you.'
                : 'Adding your CV makes the biggest difference.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Sp.x3),
          SizedBox(
            height: Touch.min + 4,
            child: FilledButton(
              onPressed: () => context.go(Routes.profile),
              child: Text(hasResume ? 'Complete profile' : 'Upload your CV'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Rail extends ConsumerWidget {
  const _Rail({
    required this.title,
    required this.jobs,
    this.onSeeAll,
    this.emptyMessage,
  });

  final String title;
  final AsyncValue<List<dynamic>> jobs;
  final VoidCallback? onSeeAll;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (onSeeAll != null)
              TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: Sp.x2),
        jobs.when(
          loading: () => Column(
            children: const [
              JobCardSkeleton(),
              SizedBox(height: Sp.x3),
              JobCardSkeleton(),
            ],
          ),
          error: (e, _) => ErrorView(error: e),
          data: (list) {
            if (list.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(Sp.x4),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: R.brLg,
                  border: Border.all(color: C.line),
                ),
                child: Text(
                  emptyMessage ?? 'Nothing to show yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }
            return Column(
              children: [
                for (final job in list.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.x3),
                    child: JobCard(
                      job: job,
                      onTap: () => context.push(Routes.job(job.id as int)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
