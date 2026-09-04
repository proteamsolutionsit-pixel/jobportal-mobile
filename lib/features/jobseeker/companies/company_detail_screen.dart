/// One employer, and the roles it has open.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/models.dart';
import '../../../routing/router.dart';

class CompanyDetailScreen extends ConsumerWidget {
  const CompanyDetailScreen({super.key, required this.companyId});

  final int companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(companyDetailProvider(companyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Company')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(companyDetailProvider(companyId)),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(companyDetailProvider(companyId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x6),
            children: [
              _Header(company: d.company),
              if (d.company.about != null && d.company.about!.trim().isNotEmpty) ...[
                const SizedBox(height: Sp.x5),
                SectionCard(
                  title: 'About',
                  // Plain Text, never markup. Employer-supplied copy is
                  // untrusted, and this is the same rule the job description
                  // and the recruiter note follow.
                  child: Text(
                    d.company.about!.trim(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
              const SizedBox(height: Sp.x5),
              Text(
                d.jobs.isEmpty
                    ? 'Open roles'
                    : d.jobs.length == 1
                        ? '1 open role'
                        : '${d.jobs.length} open roles',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Sp.x3),
              if (d.jobs.isEmpty)
                const EmptyState(
                  icon: Icons.work_outline_rounded,
                  title: 'Nothing open right now',
                  message: 'This employer has no live postings today.',
                )
              else
                ...d.jobs.map(
                  (j) => Padding(
                    padding: const EdgeInsets.only(bottom: Sp.x3),
                    child: _RoleRow(job: j),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.company});

  final CompanyOut company;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final facts = <String>[
      if (company.industry != null && company.industry!.isNotEmpty)
        company.industry!,
      if (company.city != null && company.city!.isNotEmpty) company.city!,
      if (company.sizeBucket != null && company.sizeBucket!.isNotEmpty)
        '${company.sizeBucket} employees',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompanyLogo(path: company.logoPath, name: company.name, size: 64),
        const SizedBox(width: Sp.x4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(company.name, style: text.headlineSmall),
                  ),
                  if (company.isVerified) ...[
                    const SizedBox(width: Sp.x2),
                    const Icon(Icons.verified_rounded,
                        size: 18, color: C.brand500),
                  ],
                ],
              ),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: Sp.x1),
                Text(facts.join(' · '), style: text.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({required this.job});

  final JobBriefOut job;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Material(
      color: C.surface,
      borderRadius: R.brLg,
      child: InkWell(
        borderRadius: R.brLg,
        onTap: () => context.push('${Routes.jobs}/${job.id}'),
        child: Container(
          padding: const EdgeInsets.all(Sp.x4),
          decoration: BoxDecoration(
            borderRadius: R.brLg,
            border: Border.all(color: C.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: text.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (job.location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(job.location, style: text.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Sp.x2),
              const Icon(Icons.chevron_right_rounded, size: 20, color: C.ink400),
            ],
          ),
        ),
      ),
    );
  }
}
