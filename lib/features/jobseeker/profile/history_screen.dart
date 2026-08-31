/// Employment, education and certifications.
///
/// **Rendered in the order received.** `history.py`'s three `*_order()` helpers
/// decide it and each ends `id.desc()` — that tiebreak is load-bearing, because
/// without it two rows sharing a start date reorder themselves between two
/// identical requests. Re-sorting here would make this screen and the generated
/// resume disagree about the same rows.
///
/// **These sections feed completeness through columns, not weights.**
/// `COMPLETENESS_WEIGHTS` totals exactly 100 and matches the CodeIgniter build
/// so a score means the same on both sides; instead `sync_denormalised()` writes
/// `current_company`, `current_designation` and `highest_education`, which are
/// already weighted. **It sets and never clears** — deleting your only current
/// role does not blank those columns, deliberately, because that is far more
/// often a correction in progress than a statement of unemployment.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/seeker_repository.dart';
import 'profile_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key, required this.kind});
  final HistoryKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(historyProvider(kind));

    return Scaffold(
      appBar: AppBar(title: Text(kind.label)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEntrySheet(context, ref, kind, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(historyProvider(kind)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: switch (kind) {
                HistoryKind.employment => Icons.business_center_outlined,
                HistoryKind.education => Icons.school_outlined,
                HistoryKind.certifications => Icons.workspace_premium_outlined,
              },
              title: 'Nothing added yet',
              message: switch (kind) {
                HistoryKind.employment =>
                  'Adding the roles you have held fills in your current company '
                      'and designation, which recruiters filter by.',
                HistoryKind.education =>
                  'Your highest qualification is one of the things recruiters '
                      'filter by.',
                HistoryKind.certifications =>
                  'Certifications help you stand out for specialist roles.',
              },
              actionLabel: 'Add the first one',
              onAction: () => _showEntrySheet(context, ref, kind, null),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(historyProvider(kind)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, 96),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: Sp.x3),
              itemBuilder: (context, i) => _EntryCard(
                kind: kind,
                entry: list[i],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.kind, required this.entry});

  final HistoryKind kind;
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = [
      if (entry.startDate != null) niceDate(entry.startDate),
      if (entry.isCurrent)
        'Present'
      else if (entry.endDate != null)
        niceDate(entry.endDate),
    ].join(' – ');

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (entry.organisation != null) ...[
                      const SizedBox(height: 2),
                      Text(entry.organisation!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (value) async {
                  if (value == 'edit') {
                    _showEntrySheet(context, ref, kind, entry);
                  } else {
                    await _confirmDelete(context, ref, kind, entry);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (period.isNotEmpty) ...[
            const SizedBox(height: Sp.x2),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: C.ink400),
                const SizedBox(width: 6),
                Text(period, style: Theme.of(context).textTheme.bodySmall),
                if (entry.isCurrent) ...[
                  const SizedBox(width: Sp.x2),
                  const Tag('Current', background: C.ok50, foreground: C.ok600),
                ],
              ],
            ),
          ],
          if (entry.description != null && entry.description!.isNotEmpty) ...[
            const SizedBox(height: Sp.x3),
            Text(
              entry.description!,
              style: const TextStyle(fontSize: 13.5, height: 1.5, color: C.ink700),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  HistoryKind kind,
  HistoryEntry entry,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete "${entry.title}"?'),
      content: const Text('This removes it from your profile and your resume.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: C.bad500),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true) return;

  try {
    await ref.read(seekerRepositoryProvider).deleteHistory(kind, entry.id);
    ref.invalidate(historyProvider(kind));
    ref.invalidate(profileProvider);
    if (context.mounted) showSnack(context, 'Deleted.');
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.message, bad: true);
  }
}

Future<void> _showEntrySheet(
  BuildContext context,
  WidgetRef ref,
  HistoryKind kind,
  HistoryEntry? existing,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EntrySheet(kind: kind, existing: existing),
  );
}

class _EntrySheet extends ConsumerStatefulWidget {
  const _EntrySheet({required this.kind, this.existing});

  final HistoryKind kind;
  final HistoryEntry? existing;

  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _org =
      TextEditingController(text: widget.existing?.organisation ?? '');
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _credential =
      TextEditingController(text: widget.existing?.credentialId ?? '');

  late DateTime? _start = widget.existing?.startDate;
  late DateTime? _end = widget.existing?.endDate;
  late bool _current = widget.existing?.isCurrent ?? false;

  bool _busy = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _title.dispose();
    _org.dispose();
    _description.dispose();
    _credential.dispose();
    super.dispose();
  }

  ({String title, String org}) get _labels => switch (widget.kind) {
        HistoryKind.employment => (title: 'Designation', org: 'Company'),
        HistoryKind.education => (title: 'Degree', org: 'Institution'),
        HistoryKind.certifications => (title: 'Certification', org: 'Issued by'),
      };

  /// The field names each endpoint expects.
  Map<String, dynamic> _body() {
    final base = switch (widget.kind) {
      HistoryKind.employment => {
          'designation': _title.text.trim(),
          'company_name': _org.text.trim(),
          'is_current': _current,
        },
      HistoryKind.education => {
          'degree': _title.text.trim(),
          'institution': _org.text.trim(),
        },
      HistoryKind.certifications => {
          'name': _title.text.trim(),
          'issuer': _org.text.trim(),
          if (_credential.text.trim().isNotEmpty)
            'credential_id': _credential.text.trim(),
        },
    };

    return {
      ...base,
      if (_start != null) 'start_date': dateInputValue(_start),
      // An end date is only meaningful when the entry is not current. Sending
      // both would be two contradictory claims about the same row.
      if (!_current && _end != null) 'end_date': dateInputValue(_end),
      if (_description.text.trim().isNotEmpty)
        'description': _description.text.trim(),
    };
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Enter a ${_labels.title.toLowerCase()}.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });

    try {
      final repo = ref.read(seekerRepositoryProvider);
      if (widget.existing == null) {
        await repo.addHistory(widget.kind, _body());
      } else {
        await repo.editHistory(widget.kind, widget.existing!.id, _body());
      }
      ref.invalidate(historyProvider(widget.kind));
      // sync_denormalised() may have moved current_company / highest_education,
      // so the profile card is stale until this is re-read.
      ref.invalidate(profileProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, 'Saved.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.fieldErrors.isEmpty ? e.message : null;
        _fieldErrors = e.fieldErrors;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? now,
      firstDate: DateTime(1960),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labels;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, Sp.x2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing == null
                        ? 'Add ${widget.kind.label.toLowerCase()}'
                        : 'Edit entry',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                Sp.x4,
                Sp.x4,
                Sp.x4,
                Sp.x4 + MediaQuery.of(context).viewInsets.bottom,
              ),
              children: [
                if (_error != null) ...[
                  InlineError(_error!),
                  const SizedBox(height: Sp.x4),
                ],
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: labels.title,
                    errorText: _fieldErrors['designation'] ??
                        _fieldErrors['degree'] ??
                        _fieldErrors['name'],
                  ),
                ),
                const SizedBox(height: Sp.x4),
                TextField(
                  controller: _org,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: labels.org,
                    errorText: _fieldErrors['company_name'] ??
                        _fieldErrors['institution'] ??
                        _fieldErrors['issuer'],
                  ),
                ),
                const SizedBox(height: Sp.x4),

                if (widget.kind == HistoryKind.certifications) ...[
                  TextField(
                    controller: _credential,
                    decoration: const InputDecoration(
                      labelText: 'Credential ID (optional)',
                    ),
                  ),
                  const SizedBox(height: Sp.x4),
                ],

                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Start',
                        value: _start,
                        onTap: () => _pickDate(start: true),
                      ),
                    ),
                    const SizedBox(width: Sp.x3),
                    Expanded(
                      child: _DateField(
                        label: 'End',
                        value: _end,
                        enabled: !_current,
                        onTap: () => _pickDate(start: false),
                      ),
                    ),
                  ],
                ),

                if (widget.kind == HistoryKind.employment)
                  CheckboxListTile(
                    value: _current,
                    onChanged: (v) => setState(() => _current = v ?? false),
                    title: const Text('I currently work here'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),

                const SizedBox(height: Sp.x2),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: PrimaryButton(label: 'Save', busy: _busy, onPressed: _save),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: R.brMd,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 17),
        ),
        child: Text(
          value == null ? 'Not set' : niceDate(value),
          style: TextStyle(
            fontSize: 14.5,
            color: enabled ? C.ink800 : C.ink400,
          ),
        ),
      ),
    );
  }
}
