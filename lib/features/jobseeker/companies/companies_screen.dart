/// The company directory.
///
/// Public: a signed-out reader can browse employers, the same as they can
/// browse jobs. Mirrors the web application's Companies page.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/models.dart';
import '../../../routing/router.dart';

class CompaniesScreen extends ConsumerStatefulWidget {
  const CompaniesScreen({super.key});

  @override
  ConsumerState<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends ConsumerState<CompaniesScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Debounced, because the provider is keyed by the query string: without it
  /// every keystroke starts a request and keeps its own cache entry.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(companyDirectoryProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('Companies')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x4, Sp.x2),
            child: TextField(
              controller: _search,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search employers',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _search.clear();
                          _onChanged('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: directory.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(Sp.x4),
                itemCount: 6,
                itemBuilder: (_, _) => const Padding(
                  padding: EdgeInsets.only(bottom: Sp.x3),
                  child: JobCardSkeleton(),
                ),
              ),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(companyDirectoryProvider(_query)),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return EmptyState(
                    icon: Icons.domain_outlined,
                    title: _query.isEmpty
                        ? 'No companies yet'
                        : 'No employers match “$_query”',
                    message: _query.isEmpty
                        ? 'Employers appear here once they post a role.'
                        : 'Try a shorter or differently spelled name.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(companyDirectoryProvider(_query)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, Sp.x6),
                    // +1 for the count header.
                    itemCount: page.items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: Sp.x3),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Sp.x1),
                          child: Text(
                            // The server's `total`, never items.length — the
                            // list is one page.
                            page.total == 1
                                ? '1 company'
                                : '${page.total} companies',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      }
                      return _CompanyCard(company: page.items[i - 1]);
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

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.company});

  final CompanyOut company;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle = [
      if (company.industry != null && company.industry!.isNotEmpty)
        company.industry!,
      if (company.city != null && company.city!.isNotEmpty) company.city!,
    ].join(' · ');

    return Material(
      color: C.surface,
      borderRadius: R.brLg,
      child: InkWell(
        borderRadius: R.brLg,
        onTap: () => context.push('${Routes.companies}/${company.id}'),
        child: Container(
          padding: const EdgeInsets.all(Sp.x4),
          decoration: BoxDecoration(
            borderRadius: R.brLg,
            border: Border.all(color: C.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyLogo(path: company.logoPath, name: company.name, size: 44),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            company.name,
                            style: text.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (company.isVerified) ...[
                          const SizedBox(width: Sp.x1),
                          const Icon(Icons.verified_rounded,
                              size: 16, color: C.brand500),
                        ],
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (company.jobCount != null && company.jobCount! > 0) ...[
                      const SizedBox(height: Sp.x2),
                      Tag(
                        company.jobCount == 1
                            ? '1 open role'
                            : '${company.jobCount} open roles',
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: C.ink400),
            ],
          ),
        ),
      ),
    );
  }
}
