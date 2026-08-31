/// Saved jobs.
///
/// A saved posting can close while it sits here, which is why `SavedJobOut`
/// carries `is_open` separately from the job. The card says so rather than
/// offering an Apply that would be refused.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../routing/router.dart';
import '../../../routing/shell.dart';
import '../jobs/job_card.dart';
import '../jobs/jobs_controller.dart';
import 'saved_controller.dart';

class SavedJobsScreen extends ConsumerWidget {
  const SavedJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedJobsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved jobs'),
        actions: const [NotificationBell(), SizedBox(width: Sp.x1)],
      ),
      body: saved.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(Sp.x4),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(height: Sp.x3),
          itemBuilder: (_, _) => const JobCardSkeleton(),
        ),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(savedJobsProvider)),
        data: (list) {
          if (list.items.isEmpty) {
            return EmptyState(
              icon: Icons.bookmark_outline_rounded,
              title: 'Nothing saved yet',
              message: 'Tap the bookmark on any job to keep it here for later.',
              actionLabel: 'Browse jobs',
              onAction: () => context.go(Routes.jobs),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(savedJobsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(Sp.x4),
              itemCount: list.items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: Sp.x3),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Sp.x1),
                    child: Text(
                      '${list.total} saved',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                final entry = list.items[i - 1];
                return JobCard(
                  job: entry.job,
                  saved: true,
                  closed: !entry.isOpen,
                  onTap: () => context.push(Routes.job(entry.job.id)),
                  onToggleSave: () async {
                    try {
                      await ref
                          .read(jobsRepositoryProvider)
                          .toggleSaved(entry.job.id);
                      ref.invalidate(savedJobsProvider);
                      ref.invalidate(jobStateProvider(entry.job.id));
                      if (context.mounted) {
                        showSnack(context, 'Removed from saved.');
                      }
                    } on ApiException catch (e) {
                      if (context.mounted) showSnack(context, e.message, bad: true);
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
