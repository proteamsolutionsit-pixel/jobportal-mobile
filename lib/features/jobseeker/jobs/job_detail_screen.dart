/// A single posting, and the apply flow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/models.dart';
import '../../../routing/router.dart';
import '../applications/applications_controller.dart';
import '../authentication/auth_controller.dart';
import '../saved_jobs/saved_controller.dart';
import 'job_card.dart';
import 'jobs_controller.dart';

class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({super.key, required this.jobId});
  final int jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobDetailProvider(jobId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job details'),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: () => showSnack(context, 'Link copied to the job page.'),
            icon: const Icon(Icons.ios_share_rounded, size: 20),
          ),
        ],
      ),
      body: job.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Sp.x4),
          child: JobCardSkeleton(),
        ),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(jobDetailProvider(jobId)),
        ),
        data: (j) => _JobBody(job: j),
      ),
      bottomNavigationBar: job.maybeWhen(
        data: (j) => _ActionBar(job: j),
        orElse: () => null,
      ),
    );
  }
}

class _JobBody extends ConsumerWidget {
  const _JobBody({required this.job});
  final JobOut job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = job.company?.name ?? 'Confidential';
    final similar = ref.watch(similarJobsProvider(job.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x6),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompanyLogo(path: job.company?.logoPath, name: company, size: 56),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: Sp.x1),
                  Text(company, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Sp.x4),

        Wrap(
          spacing: Sp.x2,
          runSpacing: Sp.x2,
          children: [
            Tag(job.location, icon: Icons.location_on_outlined),
            Tag(
              experienceRangeLabel(job.minExperience, job.maxExperience),
              icon: Icons.work_history_outlined,
            ),
            Tag(labelFor(workModeLabels, job.workMode),
                icon: Icons.location_city_outlined),
            for (final t in job.jobTypes)
              Tag(
                labelFor(jobTypeLabels, t),
                background: C.brand50,
                foreground: C.brand700,
              ),
            if (!job.isOpen)
              const Tag(
                'Closed',
                icon: Icons.lock_outline_rounded,
                background: C.warn50,
                foreground: C.warn600,
              ),
          ],
        ),
        const SizedBox(height: Sp.x4),

        Container(
          padding: const EdgeInsets.all(Sp.x4),
          decoration: BoxDecoration(
            color: C.brand50,
            borderRadius: R.brLg,
          ),
          child: Row(
            children: [
              const Icon(Icons.payments_outlined, size: 20, color: C.brand600),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // Negotiable and hidden stay distinct; a monthly figure
                      // is never rendered in lakhs.
                      payLabel(
                        job.minSalary,
                        job.maxSalary,
                        hidden: job.hideSalary,
                        period: job.salaryPeriod,
                        mode: job.salaryMode,
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: C.ink900,
                      ),
                    ),
                    if (job.hideSalary)
                      Text(
                        'This employer has chosen not to publish the salary.',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else if (job.isNegotiable)
                      Text(
                        'Open to discussion.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Sp.x4),

        SectionCard(
          title: 'Job description',
          child: Text(
            job.description,
            style: const TextStyle(fontSize: 14.5, height: 1.6, color: C.ink700),
          ),
        ),

        if (job.responsibilities != null) ...[
          const SizedBox(height: Sp.x3),
          SectionCard(
            title: 'Responsibilities',
            child: Text(
              job.responsibilities!,
              style: const TextStyle(fontSize: 14.5, height: 1.6, color: C.ink700),
            ),
          ),
        ],

        if (job.requirements != null) ...[
          const SizedBox(height: Sp.x3),
          SectionCard(
            title: 'Requirements',
            child: Text(
              job.requirements!,
              style: const TextStyle(fontSize: 14.5, height: 1.6, color: C.ink700),
            ),
          ),
        ],

        if (job.skillChips.isNotEmpty) ...[
          const SizedBox(height: Sp.x3),
          SectionCard(
            title: 'Key skills',
            child: Wrap(
              spacing: Sp.x2,
              runSpacing: Sp.x2,
              children: [
                for (final s in job.skillChips)
                  Tag(s, background: C.brand50, foreground: C.brand700),
              ],
            ),
          ),
        ],

        if (job.benefits.isNotEmpty || job.benefitsOther != null) ...[
          const SizedBox(height: Sp.x3),
          SectionCard(
            title: 'Benefits',
            child: Wrap(
              spacing: Sp.x2,
              runSpacing: Sp.x2,
              children: [
                // In the vocabulary's order — jobs.benefits is a canonical CSV,
                // so two postings with the same selection read identically.
                for (final b in job.benefits)
                  Tag(
                    labelFor(benefitLabels, b),
                    icon: Icons.check_rounded,
                    background: C.ok50,
                    foreground: C.ok600,
                  ),
                // "Other" is not a member of the vocabulary — it is the
                // posting's own free text, printed as itself.
                if (job.benefitsOther != null)
                  Tag(job.benefitsOther!, background: C.ok50, foreground: C.ok600),
              ],
            ),
          ),
        ],

        const SizedBox(height: Sp.x3),
        SectionCard(
          title: 'Overview',
          child: Column(
            children: [
              DetailRow('Track', labelFor(skillLevelLabels, job.skillLevel)),
              if (job.industry != null) DetailRow('Industry', job.industry!),
              if (job.functionalArea != null)
                DetailRow('Function', job.functionalArea!),
              if (job.education != null) DetailRow('Education', job.education!),
              DetailRow('Openings', '${job.vacancies}'),
              if (job.postedAt != null)
                DetailRow('Posted', '${niceDate(job.postedAt)} · ${timeAgo(job.postedAt)}'),
              // expires_at is when APPLICATIONS CLOSE — not the posting's own
              // status, which is `status`. The two are different questions.
              if (job.expiresAt != null)
                DetailRow('Applications close', niceDate(job.expiresAt)),
            ],
          ),
        ),

        similar.maybeWhen(
          data: (jobs) {
            if (jobs.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: Sp.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Similar jobs', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: Sp.x3),
                  for (final s in jobs.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.x3),
                      child: JobCard(
                        job: s,
                        onTap: () => context.pushReplacement(Routes.job(s.id)),
                      ),
                    ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Save and Apply.
class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({required this.job});
  final JobOut job;

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool _applying = false;

  Future<void> _toggleSave() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! SignedIn) {
      context.push(Routes.login);
      return;
    }
    try {
      await ref.read(jobsRepositoryProvider).toggleSaved(widget.job.id);
      ref.invalidate(jobStateProvider(widget.job.id));
      ref.invalidate(savedJobsProvider);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, bad: true);
    }
  }

  /// Apply.
  ///
  /// **Duplicate submission is prevented by the busy flag**, and a failure is
  /// never retried automatically. A retry after a 500 could produce a second
  /// application row if the first partially succeeded, and applying twice is not
  /// something the candidate can undo — `has_applied` counts a row whatever its
  /// stage.
  Future<void> _apply() async {
    if (_applying) return;

    final auth = ref.read(authControllerProvider);
    if (auth is! SignedIn) {
      context.push(Routes.login);
      return;
    }

    final coverLetter = await _askForCoverLetter(context);
    if (coverLetter == null || !mounted) return;

    setState(() => _applying = true);
    try {
      await ref.read(jobsRepositoryProvider).apply(
            widget.job.id,
            coverLetter: coverLetter.isEmpty ? null : coverLetter,
          );
      ref.invalidate(jobStateProvider(widget.job.id));
      ref.invalidate(applicationsProvider);
      if (!mounted) return;
      showSnack(context, 'Application sent.');
    } on ApiException catch (e) {
      if (!mounted) return;
      // A 409 here is "you have already applied" — a rule refusing, not a
      // failure to retry.
      showSnack(context, e.message, bad: true);
      if (e.kind == ApiErrorKind.conflict) {
        ref.invalidate(jobStateProvider(widget.job.id));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobStateProvider(widget.job.id)).valueOrNull;
    final applied = state?.hasApplied ?? false;
    final saved = state?.isSaved ?? false;
    final closed = !widget.job.isOpen;

    return Container(
      decoration: const BoxDecoration(
        color: C.surface,
        border: Border(top: BorderSide(color: C.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: Row(
            children: [
              SizedBox(
                width: Touch.primary + 8,
                height: Touch.primary + 4,
                child: OutlinedButton(
                  onPressed: _toggleSave,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: saved ? C.brand50 : null,
                  ),
                  child: Icon(
                    saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                    size: 20,
                    color: saved ? C.brand600 : C.ink600,
                  ),
                ),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: closed
                    ? const _Disabled(label: 'No longer accepting applications')
                    : applied
                        ? const _Disabled(
                            label: 'Applied',
                            icon: Icons.check_circle_outline_rounded,
                          )
                        : PrimaryButton(
                            label: 'Apply now',
                            busy: _applying,
                            // The CTA colour: this is the single most important
                            // action on the screen.
                            cta: true,
                            onPressed: _apply,
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Disabled extends StatelessWidget {
  const _Disabled({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Touch.primary + 4,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: Sp.x2),
      decoration: BoxDecoration(
        color: C.surfaceSunk,
        borderRadius: R.brMd,
        border: Border.all(color: C.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: C.ink600),
            const SizedBox(width: Sp.x2),
          ],
          // Flexible: "No longer accepting applications" overflowed this row
          // by 196px at 390px wide.
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: C.ink600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An optional cover letter. Returns null if the reader backed out.
Future<String?> _askForCoverLetter(BuildContext context) async {
  final controller = TextEditingController();

  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: Sp.x4,
        right: Sp.x4,
        top: Sp.x2,
        bottom: MediaQuery.of(context).viewInsets.bottom + Sp.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add a note', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Sp.x2),
          Text(
            'Optional. A short line about why you are a good fit.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Sp.x4),
          TextField(
            controller: controller,
            maxLines: 5,
            maxLength: 1500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Dear hiring team, …',
            ),
          ),
          const SizedBox(height: Sp.x2),
          PrimaryButton(
            label: 'Send application',
            cta: true,
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          ),
          const SizedBox(height: Sp.x2),
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Apply without a note'),
          ),
        ],
      ),
    ),
  );

  controller.dispose();
  return result;
}
