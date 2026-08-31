/// The section edit sheets.
///
/// **Every sheet sends back the whole section, not just what changed.**
/// `PATCH /api/seeker/profile` takes a required `section` and the server writes
/// the fields that section owns; omitting one that the reader did not touch
/// writes NULL over it. That is not hypothetical — `education`,
/// `functional_area` and `expires_at` were once absent from `JobOut`, so the
/// edit form prefilled `''` and a normal save wrote NULL over all three,
/// meaning changing a job's title dropped the date applications closed on it.
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
import 'profile_controller.dart';

/// Name, headline, phone, location, summary.
Future<void> showBasicsSheet(
  BuildContext context,
  WidgetRef ref,
  SeekerProfileOut p,
) {
  final name = TextEditingController(text: p.fullName);
  final headline = TextEditingController(text: p.headline ?? '');
  final phone = TextEditingController(text: p.phone ?? '');
  final location = TextEditingController(text: p.currentLocation ?? '');
  final summary = TextEditingController(text: p.summary ?? '');

  return _sheet(
    context: context,
    ref: ref,
    title: 'About you',
    section: 'basic',
    // Every field of the section, whether or not it was touched.
    build: () => {
      'full_name': name.text.trim(),
      'headline': headline.text.trim(),
      'phone': phone.text.trim(),
      'current_location': location.text.trim(),
      'summary': summary.text.trim(),
    },
    dispose: () {
      name.dispose();
      headline.dispose();
      phone.dispose();
      location.dispose();
      summary.dispose();
    },
    fields: (errors) => [
      _Field(
        controller: name,
        label: 'Full name',
        error: errors['full_name'],
        capitalization: TextCapitalization.words,
      ),
      _Field(
        controller: headline,
        label: 'Headline',
        hint: 'Senior Accountant · 6 years in manufacturing',
        error: errors['headline'],
      ),
      _Field(
        controller: phone,
        label: 'Mobile number',
        keyboard: TextInputType.phone,
        error: errors['phone'],
      ),
      _Field(
        controller: location,
        label: 'Current location',
        error: errors['current_location'],
      ),
      _Field(
        controller: summary,
        label: 'About you',
        maxLines: 5,
        error: errors['summary'],
        capitalization: TextCapitalization.sentences,
      ),
    ],
  );
}

/// Current role, experience, CTC, notice.
Future<void> showCareerSheet(
  BuildContext context,
  WidgetRef ref,
  SeekerProfileOut p,
) {
  final designation = TextEditingController(text: p.currentDesignation ?? '');
  final company = TextEditingController(text: p.currentCompany ?? '');
  final years = TextEditingController(text: numVal(p.experienceYears));
  final months = TextEditingController(text: numVal(p.experienceMonths));
  final currentCtc = TextEditingController(text: numVal(p.currentCtc));
  final expectedCtc = TextEditingController(text: numVal(p.expectedCtc));
  final notice = TextEditingController(text: numVal(p.noticePeriodDays));

  return _sheet(
    context: context,
    ref: ref,
    title: 'Current role',
    section: 'career',
    build: () => {
      'current_designation': designation.text.trim(),
      'current_company': company.text.trim(),
      'experience_years': int.tryParse(years.text.trim()) ?? 0,
      'experience_months': int.tryParse(months.text.trim()) ?? 0,
      // Money goes back as a NUMBER even though it arrived as a string —
      // docs/decisions.md D-002.
      'current_ctc': double.tryParse(currentCtc.text.trim()),
      'expected_ctc': double.tryParse(expectedCtc.text.trim()),
      'notice_period_days': int.tryParse(notice.text.trim()),
    },
    dispose: () {
      designation.dispose();
      company.dispose();
      years.dispose();
      months.dispose();
      currentCtc.dispose();
      expectedCtc.dispose();
      notice.dispose();
    },
    fields: (errors) => [
      _Field(
        controller: designation,
        label: 'Designation',
        error: errors['current_designation'],
        capitalization: TextCapitalization.words,
      ),
      _Field(
        controller: company,
        label: 'Company',
        error: errors['current_company'],
        capitalization: TextCapitalization.words,
      ),
      Row(
        children: [
          Expanded(
            child: _Field(
              controller: years,
              label: 'Years',
              keyboard: TextInputType.number,
              error: errors['experience_years'],
            ),
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: _Field(
              controller: months,
              label: 'Months',
              keyboard: TextInputType.number,
              error: errors['experience_months'],
            ),
          ),
        ],
      ),
      _Field(
        controller: currentCtc,
        label: 'Current CTC (per year, in rupees)',
        hint: '450000',
        keyboard: TextInputType.number,
        error: errors['current_ctc'],
      ),
      _Field(
        controller: expectedCtc,
        label: 'Expected CTC (per year, in rupees)',
        keyboard: TextInputType.number,
        error: errors['expected_ctc'],
      ),
      _Field(
        controller: notice,
        label: 'Notice period (days)',
        keyboard: TextInputType.number,
        error: errors['notice_period_days'],
      ),
    ],
  );
}

/// Preferred locations and highest education.
Future<void> showPreferencesSheet(
  BuildContext context,
  WidgetRef ref,
  SeekerProfileOut p,
) {
  final locations =
      TextEditingController(text: p.preferredLocationList.join(', '));
  final education = TextEditingController(text: p.highestEducation ?? '');

  return _sheet(
    context: context,
    ref: ref,
    title: 'Preferences',
    section: 'preferences',
    build: () => {
      'preferred_locations': locations.text.trim(),
      'highest_education': education.text.trim(),
    },
    dispose: () {
      locations.dispose();
      education.dispose();
    },
    fields: (errors) => [
      _Field(
        controller: locations,
        label: 'Preferred locations',
        hint: 'Bengaluru, Pune, Remote',
        error: errors['preferred_locations'],
      ),
      _Field(
        controller: education,
        label: 'Highest education',
        hint: 'B.Com',
        error: errors['highest_education'],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------

typedef _FieldsBuilder = List<Widget> Function(Map<String, String> errors);

Future<void> _sheet({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String section,
  required Map<String, dynamic> Function() build,
  required _FieldsBuilder fields,
  required VoidCallback dispose,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SectionSheet(
      title: title,
      section: section,
      build: build,
      fields: fields,
    ),
  );
  dispose();
}

class _SectionSheet extends ConsumerStatefulWidget {
  const _SectionSheet({
    required this.title,
    required this.section,
    required this.build,
    required this.fields,
  });

  final String title;
  final String section;
  final Map<String, dynamic> Function() build;
  final _FieldsBuilder fields;

  @override
  ConsumerState<_SectionSheet> createState() => _SectionSheetState();
}

class _SectionSheetState extends ConsumerState<_SectionSheet> {
  bool _busy = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });

    try {
      await ref.read(seekerRepositoryProvider).updateProfile(
            section: widget.section,
            fields: widget.build(),
          );
      ref.invalidate(profileProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, 'Saved.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // Server wording, attached to fields by `loc`.
        _error = e.fieldErrors.isEmpty ? e.message : null;
        _fieldErrors = e.fieldErrors;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, Sp.x2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
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
                ...widget.fields(_fieldErrors),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.error,
    this.maxLines = 1,
    this.keyboard,
    this.capitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? error;
  final int maxLines;
  final TextInputType? keyboard;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x4),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        textCapitalization: capitalization,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
        ),
      ),
    );
  }
}
