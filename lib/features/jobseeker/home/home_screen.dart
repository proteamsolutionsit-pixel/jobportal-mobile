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
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../routing/router.dart';
import '../../../routing/shell.dart';
import '../authentication/auth_controller.dart';
import '../jobs/job_card.dart';
import '../jobs/jobs_controller.dart';
import '../profile/profile_controller.dart';

/// The stages that count as "shortlisted or further" — `AT_LEAST_SHORTLISTED`
/// in the web dashboard, itself the list the PHP passed to
/// count_for_candidate().
const atLeastShortlisted = {'shortlisted', 'interview', 'offered', 'hired'};

/// How many applications to read to derive the shortlisted tile. There is no
/// stage-count endpoint, so — exactly as the web dashboard does — it is counted
/// over one generous page. Never used for the Applications tile, which reads
/// the server's `total` (rule 5).
const _deriveLimit = 100;

typedef DashboardCounts = ({int applications, int shortlisted, bool shortlistedCapped, int saved});

final dashboardCountsProvider = FutureProvider.autoDispose<DashboardCounts>((ref) async {
  final repo = ref.watch(seekerRepositoryProvider);
  final (apps, saved) = await (
    repo.applications(page: 1, perPage: _deriveLimit),
    repo.saved(page: 1, perPage: 1),
  ).wait;
  return (
    applications: apps.total,
    shortlisted: apps.items.where((a) => atLeastShortlisted.contains(a.status)).length,
    // Past one page the derived figure is a floor, and says so (rule 5).
    shortlistedCapped: apps.total > apps.items.length,
    saved: saved.total,
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final brand = ref.watch(brandingProvider).valueOrNull;
    final featured = ref.watch(homeJobsProvider);
    final suggested = ref.watch(suggestedJobsProvider);
    final profile = ref.watch(profileProvider);

    // The first word that is a name rather than an initial: "A Tirumurthy"
    // is greeted as Tirumurthy, not "A". Initials-first is the common Indian
    // form, and the web's `split(' ')[0]` greets exactly that person as "Hi A".
    final words = (user?.fullName ?? '')
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final firstName = words.firstWhere(
      (w) => w.replaceAll('.', '').length > 1,
      orElse: () => words.isEmpty ? 'there' : words.first,
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
          ref.invalidate(dashboardCountsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x6),
          children: [
            // `.page-hero`: the web dashboard's greeting banner, with the
            // search entry inside it.
            GradientBanner(
              layers: Gradients.hero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $firstName',
                    style: const TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: Sp.x1),
                  Text(
                    'Here is what is new for you today.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: Sp.x4),

                  // Search entry point. Tapping goes to the Jobs tab rather
                  // than opening a second search — one search screen, one
                  // filter state.
                  Material(
                    color: C.surface,
                    borderRadius: R.brMd,
                    child: InkWell(
                      onTap: () => context.go(Routes.jobs),
                      borderRadius: R.brMd,
                      child: SizedBox(
                        height: Touch.primary + 6,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Sp.x3),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded, size: 20, color: C.brand500),
                              const SizedBox(width: Sp.x3),
                              // Expanded, not bare: at 390px the unconstrained
                              // Text overflowed the row by 156px. Found by
                              // running the flow tests at a real phone width.
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
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x4),

            _StatTiles(
              completeness: profile.valueOrNull?.profileCompleteness,
            ),
            const SizedBox(height: Sp.x4),

            const _AssistantCard(),
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

            const SizedBox(height: Sp.x5),

            // The directory is a browse surface, not a setting, so it
            // lives here rather than under Settings. There is no room for
            // a sixth bottom tab.
            _BrowseCompanies(),
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

/// Entry point to the employer directory.
///
/// A card rather than a bottom tab: the tab bar already carries five
/// destinations, and browsing companies is an occasional act, not one of the
/// five things a job seeker does every session.
class _BrowseCompanies extends StatelessWidget {
  const _BrowseCompanies();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Material(
      color: C.brand50,
      borderRadius: R.brLg,
      child: InkWell(
        borderRadius: R.brLg,
        onTap: () => context.push(Routes.companies),
        child: Container(
          padding: const EdgeInsets.all(Sp.x4),
          decoration: BoxDecoration(
            borderRadius: R.brLg,
            border: Border.all(color: C.brand100),
          ),
          child: Row(
            children: [
              ToneBadge(icon: Icons.domain_rounded, tone: Tones.sky),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Browse companies', style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'See who is hiring and what they have open',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: C.brand600),
            ],
          ),
        ),
      ),
    );
  }
}

/// The web dashboard's four `.tile`s: brand, ok, violet, teal. Each opens the
/// screen its figure comes from.
class _StatTiles extends ConsumerWidget {
  const _StatTiles({required this.completeness});

  final int? completeness;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(dashboardCountsProvider).valueOrNull;
    final tiles = [
      StatTile(
        label: 'Applications',
        value: counts == null ? null : groupIndian(counts.applications),
        icon: Icons.send_rounded,
        tone: Tones.brand,
        onTap: () => context.go(Routes.applications),
      ),
      StatTile(
        label: 'Shortlisted or further',
        value: counts == null
            ? null
            : '${groupIndian(counts.shortlisted)}${counts.shortlistedCapped ? '+' : ''}',
        icon: Icons.verified_rounded,
        tone: Tones.ok,
        onTap: () => context.go(Routes.applications),
      ),
      StatTile(
        label: 'Saved jobs',
        value: counts == null ? null : groupIndian(counts.saved),
        icon: Icons.bookmark_rounded,
        tone: Tones.violet,
        onTap: () => context.go(Routes.saved),
      ),
      StatTile(
        label: 'Profile strength',
        value: completeness == null ? null : '$completeness%',
        icon: Icons.insights_rounded,
        tone: Tones.teal,
        note: completeness == null
            ? null
            : completeness! >= 80
                ? 'Looking strong'
                : 'Room to grow',
        onTap: () => context.go(Routes.profile),
      ),
    ];

    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: Sp.x3),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[row * 2]),
                const SizedBox(width: Sp.x3),
                Expanded(child: tiles[row * 2 + 1]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The way into the assistant: a violet-tinted card, since it is the one
/// thing on this screen that talks back.
class _AssistantCard extends StatelessWidget {
  const _AssistantCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = Tones.violet;

    return Material(
      color: t.wash,
      borderRadius: R.brLg,
      child: InkWell(
        borderRadius: R.brLg,
        onTap: () => context.push(Routes.assistant),
        child: Container(
          padding: const EdgeInsets.all(Sp.x4),
          decoration: BoxDecoration(
            borderRadius: R.brLg,
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              ToneBadge(icon: Icons.auto_awesome_rounded, tone: t),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ask the assistant', style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Find jobs, check your profile, track applications',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: t.ink),
            ],
          ),
        ),
      ),
    );
  }
}
