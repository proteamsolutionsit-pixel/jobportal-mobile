/// Applications I have sent.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/models.dart';
import '../../../routing/router.dart';
import '../../../routing/shell.dart';
import 'applications_controller.dart';

class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) {
        ref.read(applicationsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final applications = ref.watch(applicationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle('My applications'),
        actions: const [NotificationBell(), SizedBox(width: Sp.x1)],
      ),
      body: applications.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(Sp.x4),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(height: Sp.x3),
          itemBuilder: (_, _) => const JobCardSkeleton(),
        ),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(applicationsProvider),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return EmptyState(
              icon: Icons.description_outlined,
              title: 'No applications yet',
              message: 'Jobs you apply to will appear here so you can track them.',
              actionLabel: 'Find jobs',
              onAction: () => context.go(Routes.jobs),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(applicationsProvider),
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.all(Sp.x4),
              itemCount: page.items.length + 2,
              separatorBuilder: (_, _) => const SizedBox(height: Sp.x3),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return PageHero(
                    title: 'Your applications',
                    subtitle: 'Track every job you have applied to, '
                        'stage by stage.',
                    icon: Icons.rocket_launch_rounded,
                    pills: [
                      // The server's total (rule 5), never items.length.
                      (
                        icon: Icons.send_rounded,
                        text: '${page.total} '
                            '${page.total == 1 ? 'application' : 'applications'}',
                      ),
                    ],
                  );
                }
                if (i == page.items.length + 1) {
                  return page.loadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(Sp.x4),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          ),
                        )
                      : const SizedBox(height: Sp.x5);
                }
                return _ApplicationCard(application: page.items[i - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

/// The stages a successful application moves through, in order. `hired`
/// lands on the last step; `rejected` and `withdrawn` leave the track.
const _track = ['applied', 'viewed', 'shortlisted', 'interview', 'offered'];
const _trackLabels = ['Applied', 'Viewed', 'Shortlisted', 'Interview', 'Offer'];

Tone _stageTone(String stage) => switch (stage) {
      'hired' || 'offered' => Tones.ok,
      'interview' => Tones.violet,
      'shortlisted' => Tones.brand,
      'viewed' => Tones.sky,
      'rejected' || 'withdrawn' =>
        (wash: C.surfaceSunk, border: C.line, ink: C.ink600, solid: C.ink400),
      _ => Tones.amber,
    };

class _ApplicationCard extends ConsumerWidget {
  const _ApplicationCard({required this.application});
  final MyApplicationOut application;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = application.job;
    final company = job?.company?.name ?? 'Confidential';
    final tone = _stageTone(application.status);

    return Material(
      color: C.surface,
      borderRadius: R.brLg,
      clipBehavior: Clip.antiAlias,
      child: Container(
        // Filled: a shadow under an unfilled box shows through it, which is
        // what made these cards render grey.
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: R.brLg,
          border: Border.all(color: C.line),
          boxShadow: Shadows.sm,
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: tone.solid),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => context.push(Routes.job(application.jobId)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Sp.x4 + 4, Sp.x4, Sp.x4, Sp.x3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CompanyLogo(path: job?.company?.logoPath, name: company),
                        const SizedBox(width: Sp.x3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job?.title ?? 'Job #${application.jobId}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(company, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const SizedBox(width: Sp.x2),
                        Tag(
                          labelFor(applicationStageLabels, application.status),
                          background: tone.wash,
                          foreground: tone.ink,
                          border: tone.border,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.x4 + 4, 0, Sp.x4, Sp.x3),
                  child: _StageTracker(status: application.status),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.x4 + 4, 0, Sp.x2, Sp.x2),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_rounded, size: 15, color: C.ink400),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Applied ${timeAgo(application.appliedAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (application.isActive)
                        TextButton.icon(
                          onPressed: () => _confirmWithdraw(context, ref, application),
                          icon: const Icon(Icons.undo_rounded, size: 16),
                          label: const Text('Withdraw'),
                          style: TextButton.styleFrom(foregroundColor: C.ink500),
                        ),
                    ],
                  ),
                ),
                if (application.recruiterNote != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Sp.x4 + 4, 0, Sp.x4, Sp.x4),
                    child: Container(
                      padding: const EdgeInsets.all(Sp.x3),
                      decoration: BoxDecoration(
                        color: Tones.sky.wash,
                        borderRadius: R.brMd,
                        border: Border.all(color: Tones.sky.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Tones.sky.ink),
                          const SizedBox(width: Sp.x2),
                          Expanded(
                            // Untrusted text from a recruiter. Rendered as PLAIN
                            // TEXT — never as markup.
                            child: Text(
                              application.recruiterNote!,
                              style: const TextStyle(fontSize: 13.5, height: 1.45, color: C.ink700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Where an application has got to, as five steps. Off the track (rejected,
/// withdrawn) it says so plainly instead of drawing a stalled bar.
class _StageTracker extends StatelessWidget {
  const _StageTracker({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    if (status == 'rejected' || status == 'withdrawn') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x2),
        decoration: BoxDecoration(color: C.surfaceSunk, borderRadius: R.brMd),
        child: Text(
          status == 'withdrawn'
              ? 'You withdrew this application.'
              : 'Not taken forward this time — keep going, the right role is out there.',
          style: const TextStyle(fontSize: 12.5, color: C.ink600, height: 1.4),
        ),
      );
    }

    final reached = status == 'hired' ? _track.length - 1 : _track.indexOf(status);
    final tone = _stageTone(status);

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < _track.length; i++) ...[
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= reached ? tone.solid : C.surface,
                  border: Border.all(color: i <= reached ? tone.solid : C.lineStrong, width: 2),
                ),
                child: i <= reached
                    ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                    : null,
              ),
              if (i < _track.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    color: i < reached ? tone.solid : C.line,
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // An equal share each, shrunk only if they must: at a large
        // accessibility font or a narrow phone the five labels overflowed
        // the card by 89px when laid out at their natural width.
        Row(
          children: [
            for (var i = 0; i < _track.length; i++)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: i == 0
                      ? Alignment.centerLeft
                      : i == _track.length - 1
                          ? Alignment.centerRight
                          : Alignment.center,
                  child: Text(
                    status == 'hired' && i == _track.length - 1 ? 'Hired' : _trackLabels[i],
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: i == reached ? FontWeight.w700 : FontWeight.w500,
                      color: i <= reached ? tone.ink : C.ink400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The confirmation.
///
/// **It says the action is permanent, in those words**, because it is:
/// `has_applied` counts an application row whatever its stage, so withdrawing
/// blocks re-applying for good, and no recruiter can reverse it. Nothing in the
/// product can undo it, and a dialog that says only "Are you sure?" would be
/// hiding that.
Future<void> _confirmWithdraw(
  BuildContext context,
  WidgetRef ref,
  MyApplicationOut application,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Withdraw this application?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            application.job?.title ?? 'Job #${application.jobId}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Sp.x3),
          const Text(
            'This cannot be undone. You will not be able to apply to this job '
            'again, and the recruiter cannot reverse it either.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep it'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: C.bad500),
          child: const Text('Withdraw permanently'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(applicationsProvider.notifier).withdraw(application.id);
    if (context.mounted) showSnack(context, 'Application withdrawn.');
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.message, bad: true);
  }
}
