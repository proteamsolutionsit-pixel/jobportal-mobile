/// `ResumeParseOut` — what the parser read out of a CV.
///
/// **Nothing here is applied without the reader confirming it.** Extraction is
/// heuristic, and the web build's resume intake follows the same rule for a
/// reason it paid for: the parser once reported 80 of 530 CVs as B.Tech because
/// `b\.?\s?e\b` matched the English word "be", and 63 of those stated a real
/// lower qualification that should have won.
///
/// So the screen shows the reading back field by field and the reader ticks
/// what to keep. A wrong value silently written into a profile is worse than a
/// blank one, because a blank invites correction and a wrong one does not.
library;

import 'wire.dart';

/// One field the parser filled in, with its confidence.
class ParsedField {
  const ParsedField({
    required this.key,
    required this.label,
    required this.value,
    this.confidence,
  });

  /// The `SeekerProfileIn` field name this maps to.
  final String key;

  final String label;
  final String value;

  /// 0–1 where the server offered one. Shown as a hint, never as a gate: the
  /// reader decides, and a confident wrong answer is exactly the failure mode.
  final double? confidence;

  bool get isLowConfidence => confidence != null && confidence! < 0.6;
}

class ResumeParse {
  const ResumeParse({
    required this.fileName,
    required this.fileSize,
    required this.fields,
    this.skills = const [],
    this.photoFound = false,
    this.textError,
    this.textLength = 0,
  });

  final String fileName;
  final int fileSize;

  /// Only the fields that actually came back with something. A parser that
  /// found nothing must say so plainly rather than presenting empty boxes.
  final List<ParsedField> fields;

  final List<String> skills;
  final bool photoFound;

  /// Set when the file could not be read at all — an image-only PDF, say.
  final String? textError;
  final int textLength;

  bool get isEmpty => fields.isEmpty && skills.isEmpty;

  /// The mapping from parsed field to the profile section that owns it.
  ///
  /// `PATCH /api/seeker/profile` is section-scoped, so applying a reading means
  /// one call per section — and each call must carry **every** field of that
  /// section, which is why the caller merges into the stored profile rather
  /// than sending the parsed fields alone.
  static const sectionFor = <String, String>{
    'full_name': 'basic',
    'phone': 'basic',
    'headline': 'basic',
    'summary': 'basic',
    'current_location': 'basic',
    'current_company': 'career',
    'current_designation': 'career',
    'experience_years': 'career',
    'experience_months': 'career',
    'current_ctc': 'career',
    'expected_ctc': 'career',
    'notice_period_days': 'career',
    'preferred_locations': 'preferences',
    'highest_education': 'preferences',
  };

  static const _labels = <String, String>{
    'full_name': 'Full name',
    'phone': 'Mobile number',
    'headline': 'Headline',
    'summary': 'About you',
    'current_location': 'Current location',
    'current_company': 'Current company',
    'current_designation': 'Designation',
    'experience_years': 'Years of experience',
    'experience_months': 'Months of experience',
    'current_ctc': 'Current CTC',
    'expected_ctc': 'Expected CTC',
    'notice_period_days': 'Notice period (days)',
    'preferred_locations': 'Preferred locations',
    'highest_education': 'Highest education',
  };

  factory ResumeParse.fromWire(Wire w) {
    final raw = w.json['fields'];
    final fieldMap = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    final confidenceRaw = w.json['confidence'];
    final confidence =
        confidenceRaw is Map ? Map<String, dynamic>.from(confidenceRaw) : const {};

    final found = <ParsedField>[];
    // Iterated over the LABEL map, not the payload, so the order is ours and
    // stable — a reader ticking boxes should not see them reshuffle between two
    // uploads of the same CV.
    for (final entry in _labels.entries) {
      final value = fieldMap[entry.key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty) continue;

      final c = confidence[entry.key];
      found.add(ParsedField(
        key: entry.key,
        label: entry.value,
        value: text,
        confidence: c is num ? c.toDouble() : null,
      ));
    }

    return ResumeParse(
      fileName: w.strOrNull('file_name') ?? 'your CV',
      fileSize: w.intOrNull('file_size') ?? 0,
      fields: found,
      skills: w.stringsOrEmpty('skills'),
      photoFound: w.boolean('photo_found', orElse: false),
      textError: w.strOrNull('text_error'),
      textLength: w.intOrNull('text_length') ?? 0,
    );
  }

  static ResumeParse decode(Object? json) =>
      ResumeParse.fromWire(Wire.of(json, 'ResumeParseOut'));
}
