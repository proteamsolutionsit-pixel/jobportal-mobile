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
        title: const Text('My applications'),
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Sp.x1),
                    child: Text(
                      '${page.total} ${page.total == 1 ? 'application' : 'applications'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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

class _ApplicationCard extends ConsumerWidget {
  const _ApplicationCard({required this.application});
  final MyApplicationOut application;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = application.job;
    final company = job?.company?.name ?? 'Confidential';

    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: R.brLg,
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push(Routes.job(application.jobId)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(R.lg)),
            child: Padding(
              padding: const EdgeInsets.all(Sp.x4),
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
                        const SizedBox(height: Sp.x3),
                        Row(
                          children: [
                            Tag.stage(
                              application.status,
                              labelFor(applicationStageLabels, application.status),
                            ),
                            const SizedBox(width: Sp.x2),
                            Expanded(
                              child: Text(
                                'Applied ${timeAgo(application.appliedAt)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (application.recruiterNote != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: Container(
                padding: const EdgeInsets.all(Sp.x3),
                decoration: BoxDecoration(
                  color: C.surfaceSunk,
                  borderRadius: R.brMd,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 16, color: C.ink500),
                    const SizedBox(width: Sp.x2),
                    Expanded(
                      // Untrusted text from a recruiter. Rendered as PLAIN
                      // TEXT — never as markup.
                      child: Text(
                        application.recruiterNote!,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: C.ink700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (application.isActive) ...[
            const Divider(height: 1),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Sp.x2,
                  vertical: Sp.x1,
                ),
                child: TextButton.icon(
                  onPressed: () => _confirmWithdraw(context, ref, application),
                  icon: const Icon(Icons.undo_rounded, size: 17),
                  label: const Text('Withdraw'),
                  style: TextButton.styleFrom(foregroundColor: C.ink600),
                ),
              ),
            ),
          ],
        ],
      ),
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
