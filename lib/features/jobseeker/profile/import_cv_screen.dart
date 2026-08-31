/// Fill your profile from your CV.
///
/// Typing a profile on a phone is the worst part of this product, and the
/// parser already exists — so this is the highest-value screen in the app for
/// the effort it costs.
///
/// **It shows the reading back and applies nothing without a tick.** Extraction
/// is heuristic. The web build's parser once reported 80 of 530 CVs as B.Tech
/// because `b\.?\s?e\b` matched the English word "be", and 63 of those stated a
/// real lower qualification that should have won. A wrong value written
/// silently into a profile is worse than a blank one: a blank invites
/// correction, a wrong one does not.
///
/// **Applying is section-scoped**, because `PATCH /api/seeker/profile` is. Each
/// section is sent once, carrying **every** field of that section — the stored
/// value where the reader did not tick, the parsed value where they did.
/// Sending only the ticked fields would write NULL over the rest.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/models.dart';
import '../../../data/models/resume_parse.dart';
import 'profile_controller.dart';

const _resumeExtensions = ['pdf', 'doc', 'docx', 'rtf', 'txt'];
const _maxResumeBytes = 5 * 1024 * 1024;

class ImportCvScreen extends ConsumerStatefulWidget {
  const ImportCvScreen({super.key});

  @override
  ConsumerState<ImportCvScreen> createState() => _ImportCvScreenState();
}

class _ImportCvScreenState extends ConsumerState<ImportCvScreen> {
  ResumeParse? _parsed;

  /// Which readings the reader has kept. Everything starts ticked **except**
  /// the low-confidence ones — the default should be the safe direction, and a
  /// field the parser is unsure about is one it is most likely wrong about.
  final _keep = <String>{};
  bool _keepSkills = true;

  bool _busy = false;
  String? _error;
  double? _progress;

  Future<void> _pickAndParse() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _resumeExtensions,
      withData: false,
    );
    final file = picked?.files.singleOrNull;
    if (file == null || file.path == null) return;

    if (file.size > _maxResumeBytes) {
      setState(() => _error =
          'That file is ${fileSizeLabel(file.size)}. The limit is 5 MB.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
      _parsed = null;
    });

    try {
      final json = await ref.read(seekerRepositoryProvider).parseResume(
            filePath: file.path!,
            fileName: file.name,
          );
      final parsed = ResumeParse.decode(json);

      setState(() {
        _parsed = parsed;
        _keep
          ..clear()
          ..addAll(parsed.fields.where((f) => !f.isLowConfidence).map((f) => f.key));
        _keepSkills = parsed.skills.isNotEmpty;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  /// Apply the ticked readings, one call per affected section.
  Future<void> _apply() async {
    final parsed = _parsed;
    if (parsed == null) return;

    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) {
      setState(() => _error = 'Your profile could not be read. Try again.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(seekerRepositoryProvider);

    // Group the kept fields by the section that owns them.
    final bySection = <String, Map<String, dynamic>>{};
    for (final field in parsed.fields) {
      if (!_keep.contains(field.key)) continue;
      final section = ResumeParse.sectionFor[field.key];
      if (section == null) continue;
      bySection.putIfAbsent(section, () => {})[field.key] = field.value;
    }

    try {
      for (final entry in bySection.entries) {
        // Start from what is stored, then overlay the kept readings. Sending
        // only the parsed fields would write NULL over everything else in the
        // section — the failure that once dropped the date applications closed
        // on a job when somebody changed its title.
        final body = _sectionBody(entry.key, profile)..addAll(entry.value);
        await repo.updateProfile(section: entry.key, fields: body);
      }

      // Skills are a separate call: they are set by id, and the server writes
      // two stores plus a completeness rescore. The parser returns names, so
      // each is looked up in the controlled vocabulary and anything it does not
      // recognise is dropped rather than invented.
      if (_keepSkills && parsed.skills.isNotEmpty) {
        final ids = <int>{...profile.skills.map((s) => s.id)};
        for (final name in parsed.skills) {
          final matches = await repo.lookupSkills(name);
          final hit = matches.where(
            (s) => s.name.toLowerCase() == name.toLowerCase(),
          );
          if (hit.isNotEmpty) ids.add(hit.first.id);
        }
        if (ids.isNotEmpty) await repo.setSkills(ids.toList());
      }

      ref.invalidate(profileProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, 'Profile updated from your CV.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The stored value of every field a section owns.
  Map<String, dynamic> _sectionBody(String section, SeekerProfileOut p) {
    return switch (section) {
      'basic' => {
          'full_name': p.fullName,
          'headline': p.headline ?? '',
          'phone': p.phone ?? '',
          'current_location': p.currentLocation ?? '',
          'summary': p.summary ?? '',
        },
      'career' => {
          'current_designation': p.currentDesignation ?? '',
          'current_company': p.currentCompany ?? '',
          'experience_years': p.experienceYears ?? 0,
          'experience_months': p.experienceMonths ?? 0,
          'current_ctc': p.currentCtc,
          'expected_ctc': p.expectedCtc,
          'notice_period_days': p.noticePeriodDays,
        },
      'preferences' => {
          'preferred_locations': p.preferredLocations ?? '',
          'highest_education': p.highestEducation ?? '',
        },
      _ => <String, dynamic>{},
    };
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;

    return Scaffold(
      appBar: AppBar(title: const Text('Fill from your CV')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Sp.x4),
          children: [
            if (_error != null) ...[
              InlineError(_error!),
              const SizedBox(height: Sp.x4),
            ],

            if (parsed == null) ...[
              Text(
                'Save yourself the typing',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: Sp.x2),
              Text(
                'Upload your CV and we will read what we can out of it. '
                'You choose what to keep — nothing is saved until you say so.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Sp.x5),
              if (_progress != null) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: Sp.x4),
              ],
              PrimaryButton(
                label: 'Choose your CV',
                icon: Icons.upload_file_rounded,
                busy: _busy,
                onPressed: _pickAndParse,
              ),
              const SizedBox(height: Sp.x3),
              Text(
                'PDF or Word, up to 5 MB.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (parsed.textError != null) ...[
              // The file was unreadable — an image-only scan, most likely. Said
              // plainly rather than shown as an empty result, which would read
              // as "your CV contains nothing".
              InlineError(
                'We could not read any text out of ${parsed.fileName}. '
                'If it is a scan, a PDF exported from Word usually works.',
              ),
              const SizedBox(height: Sp.x4),
              OutlinedButton(
                onPressed: () => setState(() => _parsed = null),
                child: const Text('Try another file'),
              ),
            ] else if (parsed.isEmpty) ...[
              InlineNotice(
                'We read ${parsed.fileName} but could not pick out anything we '
                'were confident about. Filling the profile in by hand will be '
                'quicker than guessing.',
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: Sp.x4),
              OutlinedButton(
                onPressed: () => setState(() => _parsed = null),
                child: const Text('Try another file'),
              ),
            ] else ...[
              Text(
                'Here is what we read',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: Sp.x2),
              Text(
                'From ${parsed.fileName}. Untick anything that is wrong — this '
                'is a best guess, not a fact.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Sp.x4),

              Container(
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: R.brLg,
                  border: Border.all(color: C.line),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < parsed.fields.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _FieldTile(
                        field: parsed.fields[i],
                        checked: _keep.contains(parsed.fields[i].key),
                        onChanged: (on) => setState(() {
                          on
                              ? _keep.add(parsed.fields[i].key)
                              : _keep.remove(parsed.fields[i].key);
                        }),
                      ),
                    ],
                  ],
                ),
              ),

              if (parsed.skills.isNotEmpty) ...[
                const SizedBox(height: Sp.x3),
                Container(
                  decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: R.brLg,
                    border: Border.all(color: C.line),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _keepSkills,
                          onChanged: (on) =>
                              setState(() => _keepSkills = on ?? false),
                          title: Text('${parsed.skills.length} skills'),
                          subtitle: const Text('Added to what you already have'),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              Sp.x4, 0, Sp.x4, Sp.x4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: Sp.x2,
                              runSpacing: Sp.x2,
                              children: [
                                for (final s in parsed.skills)
                                  Tag(s,
                                      background: C.brand50,
                                      foreground: C.brand700),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: Sp.x5),
              PrimaryButton(
                label: _keep.isEmpty && !_keepSkills
                    ? 'Nothing selected'
                    : 'Apply ${_keep.length + (_keepSkills ? 1 : 0)} '
                        'change${_keep.length + (_keepSkills ? 1 : 0) == 1 ? '' : 's'}',
                busy: _busy,
                onPressed: _keep.isEmpty && !_keepSkills ? null : _apply,
              ),
              const SizedBox(height: Sp.x3),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : () => setState(() => _parsed = null),
                  child: const Text('Try another file'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.field,
    required this.checked,
    required this.onChanged,
  });

  final ParsedField field;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        value: checked,
        onChanged: (on) => onChanged(on ?? false),
        title: Text(field.label, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              field.value,
              style: const TextStyle(fontSize: 14, color: C.ink800, height: 1.4),
            ),
            if (field.isLowConfidence) ...[
              const SizedBox(height: Sp.x2),
              // Unticked by default, and told why. The parser being unsure is
              // exactly when it is most likely wrong.
              const Tag(
                'We are not sure about this one',
                icon: Icons.help_outline_rounded,
                background: C.warn50,
                foreground: C.warn600,
              ),
            ],
          ],
        ),
        isThreeLine: field.isLowConfidence,
      ),
    );
  }
}
