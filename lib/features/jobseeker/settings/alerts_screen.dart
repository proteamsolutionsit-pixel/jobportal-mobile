/// Job alerts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/autosuggest.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../profile/profile_controller.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Job alerts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAlertSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New alert'),
      ),
      body: alerts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(alertsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_active_outlined,
              title: 'No alerts yet',
              message: 'Tell us what you are looking for and we will email you '
                  'when matching jobs are posted.',
              actionLabel: 'Create an alert',
              onAction: () => _showAlertSheet(context, ref),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: Sp.x3),
            itemBuilder: (context, i) {
              final alert = list[i];
              return Container(
                padding: const EdgeInsets.all(Sp.x4),
                decoration: BoxDecoration(
                  color: C.surface,
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
                            alert.keyword.isEmpty ? 'All jobs' : alert.keyword,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: Sp.x2),
                          Wrap(
                            spacing: Sp.x2,
                            runSpacing: Sp.x2,
                            children: [
                              if (alert.location != null)
                                Tag(alert.location!,
                                    icon: Icons.location_on_outlined),
                              Tag(
                                alert.frequency == 'daily' ? 'Daily' : 'Weekly',
                                icon: Icons.schedule_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: alert.isActive,
                      onChanged: (_) async {
                        try {
                          await ref
                              .read(seekerRepositoryProvider)
                              .toggleAlert(alert.id);
                          ref.invalidate(alertsProvider);
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            showSnack(context, e.message, bad: true);
                          }
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete alert',
                      onPressed: () async {
                        try {
                          await ref
                              .read(seekerRepositoryProvider)
                              .deleteAlert(alert.id);
                          ref.invalidate(alertsProvider);
                          if (context.mounted) {
                            showSnack(context, 'Alert deleted.');
                          }
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            showSnack(context, e.message, bad: true);
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> _showAlertSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AlertSheet(),
  );
}

class _AlertSheet extends ConsumerStatefulWidget {
  const _AlertSheet();

  @override
  ConsumerState<_AlertSheet> createState() => _AlertSheetState();
}

class _AlertSheetState extends ConsumerState<_AlertSheet> {
  final _keyword = TextEditingController();
  final _location = TextEditingController();

  String _frequency = alertFrequencyValues.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _keyword.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_keyword.text.trim().isEmpty) {
      setState(() => _error = 'Enter a job title or skill.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(seekerRepositoryProvider).createAlert(
            keyword: _keyword.text.trim(),
            location: _location.text.trim().isEmpty
                ? null
                : _location.text.trim(),
            frequency: _frequency,
          );
      ref.invalidate(alertsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, 'Alert created.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Text('New job alert', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Sp.x4),
          if (_error != null) ...[
            InlineError(_error!),
            const SizedBox(height: Sp.x4),
          ],

          Autosuggest(
            controller: _keyword,
            label: 'Job title or skill',
            prefixIcon: Icons.work_outline_rounded,
            textInputAction: TextInputAction.next,
            fetch: (term) => ref.read(jobsRepositoryProvider).suggestTitles(term),
          ),
          const SizedBox(height: Sp.x4),

          Autosuggest(
            controller: _location,
            label: 'Location (optional)',
            prefixIcon: Icons.location_on_outlined,
            textInputAction: TextInputAction.done,
            fetch: (term) =>
                ref.read(jobsRepositoryProvider).suggestLocations(term),
          ),
          const SizedBox(height: Sp.x4),

          Align(
            alignment: Alignment.centerLeft,
            child: Text('How often', style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: Sp.x2),
          Row(
            children: [
              for (final f in alertFrequencyValues)
                Padding(
                  padding: const EdgeInsets.only(right: Sp.x2),
                  child: ChoiceChip(
                    label: Text(f == 'daily' ? 'Daily' : 'Weekly'),
                    selected: _frequency == f,
                    onSelected: (_) => setState(() => _frequency = f),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Sp.x5),

          PrimaryButton(label: 'Create alert', busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}
