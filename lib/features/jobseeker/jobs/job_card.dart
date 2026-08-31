/// The job card, used on home, search, saved and the similar rail.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';

class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    this.saved,
    this.onToggleSave,
    this.closed = false,
    this.trailing,
  });

  final JobOut job;
  final VoidCallback onTap;
  final bool? saved;
  final VoidCallback? onToggleSave;

  /// A saved posting can close. The card says so rather than offering Apply.
  final bool closed;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final company = job.company?.name ?? 'Confidential';

    return Material(
      color: C.surface,
      borderRadius: R.brLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: R.brLg,
        child: Container(
          padding: const EdgeInsets.all(Sp.x4),
          decoration: BoxDecoration(
            borderRadius: R.brLg,
            border: Border.all(color: C.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompanyLogo(path: job.company?.logoPath, name: company),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          company,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (onToggleSave != null)
                    IconButton(
                      tooltip: saved == true ? 'Remove from saved' : 'Save this job',
                      constraints: const BoxConstraints(
                        minWidth: Touch.primary,
                        minHeight: Touch.primary,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onToggleSave,
                      icon: Icon(
                        saved == true
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        size: 21,
                        color: saved == true ? C.brand600 : C.ink400,
                      ),
                    ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: Sp.x3),

              Wrap(
                spacing: Sp.x2,
                runSpacing: Sp.x2,
                children: [
                  Tag(
                    job.location.isEmpty ? 'Location not stated' : job.location,
                    icon: Icons.location_on_outlined,
                  ),
                  Tag(
                    experienceRangeLabel(job.minExperience, job.maxExperience),
                    icon: Icons.work_history_outlined,
                  ),
                  // work_mode: 'field' renders as "On the Road / Field Work",
                  // which is what people call it — not the column's value.
                  Tag(
                    labelFor(workModeLabels, job.workMode),
                    icon: Icons.location_city_outlined,
                  ),
                ],
              ),
              const SizedBox(height: Sp.x3),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      // hide_salary is informational — the figures are already
                      // blank. payLabel keeps "Negotiable" and "Not disclosed"
                      // distinct, and never renders a monthly figure in lakhs.
                      payLabel(
                        job.minSalary,
                        job.maxSalary,
                        hidden: job.hideSalary,
                        period: job.salaryPeriod,
                        mode: job.salaryMode,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: C.ink900,
                      ),
                    ),
                  ),
                  if (job.postedAt != null)
                    Text(
                      timeAgo(job.postedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),

              if (job.jobTypes.length > 1) ...[
                const SizedBox(height: Sp.x3),
                Wrap(
                  spacing: Sp.x2,
                  runSpacing: Sp.x2,
                  children: [
                    // Rendered in the order received — primary first, then the
                    // vocabulary's order. Re-sorting would make two reads of
                    // the same posting disagree.
                    for (final t in job.jobTypes)
                      Tag(
                        labelFor(jobTypeLabels, t),
                        background: C.brand50,
                        foreground: C.brand700,
                      ),
                  ],
                ),
              ],

              if (closed) ...[
                const SizedBox(height: Sp.x3),
                const Tag(
                  'No longer accepting applications',
                  icon: Icons.lock_outline_rounded,
                  background: C.warn50,
                  foreground: C.warn600,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
