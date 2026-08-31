/// The filter sheet.
///
/// **Only the plural filter parameters are sent.** `GET /api/jobs` declares both
/// `location` and `locations[]`, `work_mode` and `work_modes[]`, and so on; the
/// plurals are the newer multi-select forms. Sending both families in one
/// request is untested and the precedence is undocumented — MOB-B-002 asks the
/// backend to state it. Until then this sends exactly one family.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/autosuggest.dart';
import '../../../core/widgets/common.dart';
import '../../../data/repositories/jobs_repository.dart';
import 'jobs_controller.dart';

Future<void> showJobFilterSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late JobQuery _draft;
  final _location = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = ref.read(jobQueryProvider);
  }

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  void _apply() {
    ref.read(jobQueryProvider.notifier).state = _draft;
    Navigator.of(context).pop();
  }

  void _clear() {
    setState(() {
      _draft = _draft.copyWith(clearFilters: true);
      _location.clear();
    });
  }

  void _toggle(List<String> current, String value, void Function(List<String>) set) {
    final next = [...current];
    next.contains(value) ? next.remove(value) : next.add(value);
    set(next);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.94,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x2, Sp.x2),
            child: Row(
              children: [
                Expanded(
                  child: Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                ),
                if (_draft.hasFilters)
                  TextButton(onPressed: _clear, child: const Text('Clear all')),
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
                Sp.x4 + media.viewInsets.bottom,
              ),
              children: [
                _Group(
                  title: 'Location',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Autosuggest(
                        controller: _location,
                        hint: 'City, district or state',
                        prefixIcon: Icons.location_on_outlined,
                        textInputAction: TextInputAction.done,
                        fetch: (term) =>
                            ref.read(jobsRepositoryProvider).suggestLocations(term),
                        // Submit is never swallowed: whatever was typed is
                        // added, chosen from the list or not.
                        onSubmitted: (value) {
                          if (value.isEmpty) return;
                          setState(() {
                            _draft = _draft.copyWith(
                              locations: {..._draft.locations, value}.toList(),
                            );
                            _location.clear();
                          });
                        },
                      ),
                      if (_draft.locations.isNotEmpty) ...[
                        const SizedBox(height: Sp.x3),
                        Wrap(
                          spacing: Sp.x2,
                          runSpacing: Sp.x2,
                          children: [
                            for (final loc in _draft.locations)
                              InputChip(
                                label: Text(loc),
                                onDeleted: () => setState(() {
                                  _draft = _draft.copyWith(
                                    locations:
                                        _draft.locations.where((l) => l != loc).toList(),
                                  );
                                }),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                _Group(
                  title: 'Work mode',
                  child: _Choices(
                    values: workModeValues,
                    labels: workModeLabels,
                    selected: _draft.workModes,
                    onToggle: (v) => _toggle(
                      _draft.workModes,
                      v,
                      (next) => setState(
                        () => _draft = _draft.copyWith(workModes: next),
                      ),
                    ),
                  ),
                ),

                _Group(
                  title: 'Employment type',
                  child: _Choices(
                    values: jobTypeValues,
                    labels: jobTypeLabels,
                    selected: _draft.jobTypes,
                    onToggle: (v) => _toggle(
                      _draft.jobTypes,
                      v,
                      (next) => setState(() => _draft = _draft.copyWith(jobTypes: next)),
                    ),
                  ),
                ),

                _Group(
                  title: 'Track',
                  child: _Choices(
                    values: skillLevelValues,
                    labels: skillLevelLabels,
                    selected: _draft.skillLevels,
                    onToggle: (v) => _toggle(
                      _draft.skillLevels,
                      v,
                      (next) =>
                          setState(() => _draft = _draft.copyWith(skillLevels: next)),
                    ),
                  ),
                ),

                _Group(
                  title: 'Experience',
                  subtitle: _draft.expMin == null && _draft.expMax == null
                      ? 'Any experience'
                      : experienceRangeLabel(_draft.expMin, _draft.expMax),
                  child: RangeSlider(
                    values: RangeValues(
                      (_draft.expMin ?? 0).toDouble(),
                      (_draft.expMax ?? 20).toDouble(),
                    ),
                    min: 0,
                    max: 20,
                    divisions: 20,
                    labels: RangeLabels(
                      '${_draft.expMin ?? 0} yrs',
                      '${_draft.expMax ?? 20} yrs',
                    ),
                    onChanged: (r) => setState(() {
                      _draft = _draft.copyWith(
                        expMin: r.start.round(),
                        expMax: r.end.round(),
                      );
                    }),
                  ),
                ),

                _Group(
                  title: 'Minimum salary',
                  subtitle: _draft.minSalary == null
                      ? 'Any'
                      : '${inrLakhs(_draft.minSalary)} and above',
                  child: Slider(
                    value: (_draft.minSalary ?? 0) / 100000,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    label: _draft.minSalary == null
                        ? 'Any'
                        : inrLakhs(_draft.minSalary),
                    onChanged: (v) => setState(() {
                      _draft = _draft.copyWith(
                        minSalary: v <= 0 ? null : v * 100000,
                      );
                    }),
                  ),
                ),

                _Group(
                  title: 'Posted within',
                  child: Wrap(
                    spacing: Sp.x2,
                    runSpacing: Sp.x2,
                    children: [
                      for (final option in const [
                        (1, 'Last 24 hours'),
                        (3, 'Last 3 days'),
                        (7, 'Last week'),
                        (30, 'Last month'),
                      ])
                        ChoiceChip(
                          label: Text(option.$2),
                          selected: _draft.postedWithin == option.$1,
                          onSelected: (on) => setState(() {
                            _draft = JobQuery(
                              q: _draft.q,
                              locations: _draft.locations,
                              workModes: _draft.workModes,
                              jobTypes: _draft.jobTypes,
                              skillLevels: _draft.skillLevels,
                              skills: _draft.skills,
                              companyIds: _draft.companyIds,
                              expMin: _draft.expMin,
                              expMax: _draft.expMax,
                              minSalary: _draft.minSalary,
                              maxSalary: _draft.maxSalary,
                              postedWithin: on ? option.$1 : null,
                              sort: _draft.sort,
                            );
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: PrimaryButton(label: 'Show results', onPressed: _apply),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: Sp.x3),
          child,
        ],
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.labels,
    required this.selected,
    required this.onToggle,
  });

  final List<String> values;
  final Map<String, String> labels;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Sp.x2,
      runSpacing: Sp.x2,
      children: [
        for (final v in values)
          FilterChip(
            label: Text(labelFor(labels, v)),
            selected: selected.contains(v),
            onSelected: (_) => onToggle(v),
          ),
      ],
    );
  }
}
