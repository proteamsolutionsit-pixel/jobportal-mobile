/// Skills.
///
/// **Set through `PATCH /api/seeker/profile` with `skill_ids`, never by writing
/// a store directly.** Two stores hold a candidate's skills — `candidates.key_skills`
/// (a denormalised CSV the cards print) and `candidate_skills` (the link table
/// recruiter search joins on) — and the server writes both plus a completeness
/// rescore. Writing one leaves a candidate findable by a skill their card does
/// not show, or showing a skill nobody can search for.
///
/// The vocabulary is **controlled**: the parser and this picker can only ever
/// return a term the platform already knows. That is deliberate here, unlike job
/// titles, because a skill has one canonical spelling and search depends on it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/models.dart';
import 'profile_controller.dart';

class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key});

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen> {
  final _search = TextEditingController();

  List<SkillOut> _selected = [];
  List<SkillOut> _results = const [];
  Timer? _debounce;
  int _requestId = 0;
  bool _searching = false;
  bool _busy = false;
  bool _loaded = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String term) {
    _debounce?.cancel();
    if (term.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () => _lookup(term));
  }

  Future<void> _lookup(String term) async {
    final id = ++_requestId;
    setState(() => _searching = true);
    try {
      final found = await ref.read(seekerRepositoryProvider).lookupSkills(term);
      if (!mounted || id != _requestId) return;
      setState(() => _results = found);
    } catch (_) {
      if (mounted && id == _requestId) setState(() => _results = const []);
    } finally {
      if (mounted && id == _requestId) setState(() => _searching = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(seekerRepositoryProvider)
          .setSkills(_selected.map((s) => s.id).toList());
      ref.invalidate(profileProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, 'Skills updated.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    // Seed from the stored profile once, then the local list is the draft.
    profile.whenData((p) {
      if (!_loaded) {
        _loaded = true;
        _selected = [...p.skills];
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Skills')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(profileProvider)),
        data: (_) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search skills',
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),

            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: Sp.x2,
                    runSpacing: Sp.x2,
                    children: [
                      for (final s in _selected)
                        InputChip(
                          label: Text(s.name),
                          onDeleted: () =>
                              setState(() => _selected.remove(s)),
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: Sp.x3),
            const Divider(height: 1),

            Expanded(
              child: _results.isEmpty
                  ? EmptyState(
                      icon: Icons.bolt_outlined,
                      title: _search.text.trim().length < 2
                          ? 'Search for a skill'
                          : 'No matches',
                      message: _search.text.trim().length < 2
                          ? 'Type at least two letters. Recruiters search by '
                              'skill, so this is the quickest way to be found.'
                          : 'Try a different spelling — we match against a '
                              'known list of skills.',
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final skill = _results[i];
                        final chosen = _selected.any((s) => s.id == skill.id);
                        return CheckboxListTile(
                          value: chosen,
                          onChanged: (on) => setState(() {
                            on == true
                                ? _selected.add(skill)
                                : _selected.removeWhere((s) => s.id == skill.id);
                          }),
                          title: Text(skill.name),
                          subtitle: skill.category == null
                              ? null
                              : Text(skill.category!),
                        );
                      },
                    ),
            ),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Sp.x4),
                child: PrimaryButton(
                  label: 'Save ${_selected.length} '
                      '${_selected.length == 1 ? 'skill' : 'skills'}',
                  busy: _busy,
                  onPressed: _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
