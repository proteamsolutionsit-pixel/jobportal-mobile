/// The seeker's profile.
///
/// **Card-shaped because the API is.** `PATCH /api/seeker/profile` takes a
/// required `section`, so the profile is saved a card at a time and the server
/// decides which fields each section may write (`docs/decisions.md` D-003).
/// One long form with a single Save is not something this endpoint can express.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/seeker_repository.dart';
import '../../../routing/router.dart';
import '../../../routing/shell.dart';
import '../authentication/auth_controller.dart';
import 'profile_controller.dart';
import 'profile_sections.dart';
import 'resume_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(profileProvider)),
        data: (p) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(profileProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x6),
            children: [
              _Header(profile: p, verified: user?.isEmailVerified ?? false),
              const SizedBox(height: Sp.x4),

              _CompletenessBar(percent: p.profileCompleteness),
              const SizedBox(height: Sp.x4),

              const ResumeCard(),
              const SizedBox(height: Sp.x3),

              SectionCard(
                title: 'About you',
                icon: Icons.person_outline_rounded,
                actionLabel: 'Edit',
                onAction: () => showBasicsSheet(context, ref, p),
                child: Column(
                  children: [
                    DetailRow('Headline', p.headline ?? 'Not added'),
                    DetailRow('Phone', p.phone ?? 'Not added'),
                    DetailRow('Location', p.currentLocation ?? 'Not added'),
                    if (p.summary != null && p.summary!.isNotEmpty) ...[
                      const SizedBox(height: Sp.x2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          p.summary!,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: C.ink700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Sp.x3),

              SectionCard(
                title: 'Current role',
                icon: Icons.work_outline_rounded,
                actionLabel: 'Edit',
                onAction: () => showCareerSheet(context, ref, p),
                child: Column(
                  children: [
                    DetailRow('Designation', p.currentDesignation ?? 'Not added'),
                    DetailRow('Company', p.currentCompany ?? 'Not added'),
                    DetailRow(
                      'Experience',
                      experienceLabel(p.experienceYears, p.experienceMonths),
                    ),
                    DetailRow('Current CTC', inrLakhs(p.currentCtc, fallback: 'Not added')),
                    DetailRow('Expected CTC', inrLakhs(p.expectedCtc, fallback: 'Not added')),
                    DetailRow('Notice period', noticeLabel(p.noticePeriodDays)),
                  ],
                ),
              ),
              const SizedBox(height: Sp.x3),

              SectionCard(
                title: 'Skills',
                icon: Icons.bolt_outlined,
                actionLabel: p.skills.isEmpty ? 'Add' : 'Edit',
                onAction: () => context.push(Routes.skills),
                child: p.skills.isEmpty
                    ? Text(
                        'Recruiters search by skill. Adding yours is the single '
                        'quickest way to be found.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    : Wrap(
                        spacing: Sp.x2,
                        runSpacing: Sp.x2,
                        children: [
                          for (final s in p.skills)
                            Tag(s.name, background: C.brand50, foreground: C.brand700),
                        ],
                      ),
              ),
              const SizedBox(height: Sp.x3),

              _HistoryCard(
                kind: HistoryKind.employment,
                icon: Icons.business_center_outlined,
                empty: 'Add the roles you have held.',
              ),
              const SizedBox(height: Sp.x3),
              _HistoryCard(
                kind: HistoryKind.education,
                icon: Icons.school_outlined,
                empty: 'Add your qualifications.',
              ),
              const SizedBox(height: Sp.x3),
              _HistoryCard(
                kind: HistoryKind.certifications,
                icon: Icons.workspace_premium_outlined,
                empty: 'Add any certifications you hold.',
              ),
              const SizedBox(height: Sp.x3),

              _LinksCard(),
              const SizedBox(height: Sp.x3),

              SectionCard(
                title: 'Preferences',
                icon: Icons.tune_rounded,
                actionLabel: 'Edit',
                onAction: () => showPreferencesSheet(context, ref, p),
                child: Column(
                  children: [
                    DetailRow(
                      'Preferred locations',
                      p.preferredLocationList.isEmpty
                          ? 'Not added'
                          : p.preferredLocationList.join(', '),
                    ),
                    DetailRow('Highest education', p.highestEducation ?? 'Not added'),
                  ],
                ),
              ),
              const SizedBox(height: Sp.x3),

              _VisibilityCard(profile: p),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.profile, required this.verified});

  final SeekerProfileOut profile;
  final bool verified;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Stack(
          children: [
            Avatar(path: profile.photoPath, name: profile.fullName, size: 68),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: C.brand500,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => uploadPhoto(context, ref),
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Icons.camera_alt_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: Sp.x4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.fullName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(profile.email, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: Sp.x2),
              // The badge means something now: registration leaves
              // email_verified_at NULL, and signing in with an emailed code is
              // what stamps it. Filling in a form proves nothing about the
              // address in it.
              verified
                  ? const Tag(
                      'Email verified',
                      icon: Icons.verified_rounded,
                      background: C.ok50,
                      foreground: C.ok600,
                    )
                  : InkWell(
                      onTap: () => _verifyEmail(context, ref),
                      borderRadius: R.brPill,
                      child: const Tag(
                        'Verify your email',
                        icon: Icons.error_outline_rounded,
                        background: C.warn50,
                        foreground: C.warn600,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _verifyEmail(BuildContext context, WidgetRef ref) async {
  try {
    final message = await ref.read(authRepositoryProvider).requestEmailVerification();
    if (context.mounted) showSnack(context, message.detail);
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.message, bad: true);
  }
}

class _CompletenessBar extends StatelessWidget {
  const _CompletenessBar({required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.x4),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: R.brLg,
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Profile completeness',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: percent >= 80 ? C.ok600 : C.brand700,
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
              backgroundColor: C.surfaceSunk,
              valueColor:
                  AlwaysStoppedAnimation(percent >= 80 ? C.ok500 : C.brand500),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({
    required this.kind,
    required this.icon,
    required this.empty,
  });

  final HistoryKind kind;
  final IconData icon;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(historyProvider(kind));

    return SectionCard(
      title: kind.label,
      icon: icon,
      actionLabel: 'Manage',
      onAction: () => context.push(Routes.history(kind)),
      child: entries.when(
        loading: () => const Skeleton(height: 40),
        error: (_, _) => Text(
          'Could not load right now.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        data: (list) {
          if (list.isEmpty) {
            return Text(empty, style: Theme.of(context).textTheme.bodyMedium);
          }
          return Column(
            // In the order received. history.py's *_order() helpers decide it,
            // each ending id.desc(); re-sorting here would make this screen and
            // the resume disagree about the same rows.
            children: [
              for (final e in list.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.x2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, size: 6, color: C.ink400),
                      ),
                      const SizedBox(width: Sp.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: C.ink800,
                              ),
                            ),
                            if (e.organisation != null)
                              Text(
                                e.organisation!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (list.length > 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '+ ${list.length - 3} more',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LinksCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(linksProvider);

    return SectionCard(
      title: 'Online presence',
      icon: Icons.link_rounded,
      actionLabel: 'Manage',
      onAction: () => context.push(Routes.links),
      child: links.when(
        loading: () => const Skeleton(height: 32),
        error: (_, _) => Text(
          'Could not load right now.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        data: (list) => list.isEmpty
            ? Text(
                'Add your LinkedIn, GitHub or portfolio.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            : Wrap(
                spacing: Sp.x2,
                runSpacing: Sp.x2,
                children: [
                  for (final l in list)
                    Tag(l.label ?? l.url, icon: Icons.open_in_new_rounded),
                ],
              ),
      ),
    );
  }
}

class _VisibilityCard extends ConsumerWidget {
  const _VisibilityCard({required this.profile});
  final SeekerProfileOut profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> set({bool? searchable, bool? public}) async {
      try {
        await ref.read(seekerRepositoryProvider).updatePrivacy(
              isSearchable: searchable,
              isPublic: public,
            );
        ref.invalidate(profileProvider);
      } on ApiException catch (e) {
        if (context.mounted) showSnack(context, e.message, bad: true);
      }
    }

    return SectionCard(
      title: 'Visibility',
      icon: Icons.visibility_outlined,
      padding: EdgeInsets.zero,
      // Material between the card's coloured Container and the tiles: a
      // ListTile inside a DecoratedBox that paints a background asserts,
      // because its own ink splashes would be invisible underneath.
      child: Material(
        color: Colors.transparent,
        child: Column(
        children: [
          SwitchListTile(
            value: profile.isSearchable,
            onChanged: (v) => set(searchable: v),
            title: const Text('Let recruiters find me'),
            subtitle: const Text('Your profile appears in recruiter searches.'),
            contentPadding: const EdgeInsets.symmetric(horizontal: Sp.x4),
          ),
          const Divider(height: 1),
          SwitchListTile(
            value: profile.isPublic,
            onChanged: (v) => set(public: v),
            title: const Text('Public profile page'),
            subtitle: const Text('Anyone with the link can view your profile.'),
            contentPadding: const EdgeInsets.symmetric(horizontal: Sp.x4),
          ),
        ],
        ),
      ),
    );
  }
}
