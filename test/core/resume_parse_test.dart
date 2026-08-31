/// The CV parse reading.
///
/// The behaviour under test is **caution**. Extraction is heuristic — the web
/// build's parser once reported 80 of 530 CVs as B.Tech because `b\.?\s?e\b`
/// matched the English word "be", and 63 of those stated a real lower
/// qualification that should have won. So a low-confidence reading must arrive
/// flagged and must not be applied by default.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jobportal_mobile/data/models/resume_parse.dart';

Map<String, dynamic> parseJson({
  Map<String, dynamic> fields = const {},
  Map<String, dynamic> confidence = const {},
  List<String> skills = const [],
  Map<String, dynamic> overrides = const {},
}) =>
    {
      'file_name': 'asha-rao.pdf',
      'file_type': 'application/pdf',
      'file_size': 184320,
      'text_length': 4200,
      'fields': fields,
      'confidence': confidence,
      'skills': skills,
      'photo_found': false,
      ...overrides,
    };

void main() {
  group('what came back', () {
    test('only fields with a value are offered', () {
      final parse = ResumeParse.decode(parseJson(fields: {
        'full_name': 'Asha Rao',
        'phone': '9876543210',
        'headline': null,
        'summary': '',
        'current_ctc': '   ',
      }));

      expect(parse.fields.map((f) => f.key), ['full_name', 'phone']);
    });

    test('fields come back in a stable order, not the payload\'s', () {
      // A reader ticking boxes must not see them reshuffle between two uploads
      // of the same CV.
      final a = ResumeParse.decode(parseJson(fields: {
        'current_company': 'Acme',
        'full_name': 'Asha Rao',
        'phone': '9876543210',
      }));
      final b = ResumeParse.decode(parseJson(fields: {
        'phone': '9876543210',
        'full_name': 'Asha Rao',
        'current_company': 'Acme',
      }));

      expect(a.fields.map((f) => f.key), b.fields.map((f) => f.key));
      expect(a.fields.first.key, 'full_name');
    });

    test('labels are human, not column names', () {
      final parse = ResumeParse.decode(parseJson(fields: {
        'notice_period_days': 30,
        'current_ctc': '450000',
      }));

      expect(
        parse.fields.map((f) => f.label),
        containsAll(['Current CTC', 'Notice period (days)']),
      );
    });

    test('a numeric field is carried across as text for display', () {
      final parse =
          ResumeParse.decode(parseJson(fields: {'experience_years': 5}));
      expect(parse.fields.single.value, '5');
    });

    test('skills come through', () {
      final parse = ResumeParse.decode(parseJson(skills: ['Tally', 'GST']));
      expect(parse.skills, ['Tally', 'GST']);
    });
  });

  group('confidence — the caution the parser has earned', () {
    test('a low-confidence reading is flagged', () {
      final parse = ResumeParse.decode(parseJson(
        fields: {'highest_education': 'B.Tech'},
        confidence: {'highest_education': 0.4},
      ));
      expect(parse.fields.single.isLowConfidence, isTrue);
    });

    test('a confident reading is not flagged', () {
      final parse = ResumeParse.decode(parseJson(
        fields: {'full_name': 'Asha Rao'},
        confidence: {'full_name': 0.95},
      ));
      expect(parse.fields.single.isLowConfidence, isFalse);
    });

    test('no confidence at all is treated as fine, not as suspect', () {
      // The server does not score every field. Flagging an unscored field would
      // untick most of the form and make the feature useless.
      final parse =
          ResumeParse.decode(parseJson(fields: {'full_name': 'Asha Rao'}));
      expect(parse.fields.single.confidence, isNull);
      expect(parse.fields.single.isLowConfidence, isFalse);
    });
  });

  group('the empty and broken cases are distinguishable', () {
    test('a readable file with nothing in it is empty, not an error', () {
      final parse = ResumeParse.decode(parseJson());
      expect(parse.isEmpty, isTrue);
      expect(parse.textError, isNull);
    });

    test('an unreadable file carries its error', () {
      // An image-only scan. Saying so beats showing an empty result, which
      // reads as "your CV contains nothing".
      final parse = ResumeParse.decode(parseJson(
        overrides: {'text_error': 'No text layer found.'},
      ));
      expect(parse.textError, 'No text layer found.');
    });

    test('a file with content is not empty', () {
      final parse =
          ResumeParse.decode(parseJson(fields: {'full_name': 'Asha Rao'}));
      expect(parse.isEmpty, isFalse);
    });

    test('skills alone count as content', () {
      final parse = ResumeParse.decode(parseJson(skills: ['Tally']));
      expect(parse.isEmpty, isFalse);
    });
  });

  group('sectionFor — applying is section-scoped because the API is', () {
    test('every offered field maps to a section', () {
      // A field with no section could be ticked and then silently not applied,
      // which is the worst outcome available here.
      final parse = ResumeParse.decode(parseJson(fields: {
        'full_name': 'Asha Rao',
        'phone': '9876543210',
        'headline': 'Accountant',
        'summary': 'Six years in manufacturing.',
        'current_location': 'Bengaluru',
        'current_company': 'Acme',
        'current_designation': 'Accountant',
        'experience_years': 5,
        'experience_months': 6,
        'current_ctc': '450000',
        'expected_ctc': '600000',
        'notice_period_days': 30,
        'preferred_locations': 'Pune',
        'highest_education': 'B.Com',
      }));

      expect(parse.fields, isNotEmpty);
      for (final field in parse.fields) {
        expect(
          ResumeParse.sectionFor[field.key],
          isNotNull,
          reason: '${field.key} is offered but maps to no profile section',
        );
      }
    });

    test('the three sections are the ones the profile screen edits', () {
      expect(
        ResumeParse.sectionFor.values.toSet(),
        {'basic', 'career', 'preferences'},
      );
    });
  });
}
