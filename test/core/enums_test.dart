/// Guards `core/constants/enums.dart` against the server it copies.
///
/// The vocabularies in that file are a **copy**; the authority is
/// `jobportal-python/backend/app/models/__init__.py`. A copy with no check is a
/// copy that drifts, and the drift is silent — a member added on the server just
/// never appears in a mobile filter, and a member spelled wrong here is rejected
/// by MySQL at the far end of a save the user thought worked.
///
/// So this test parses the Python tuples out of the real file and compares them,
/// **member for member and in order**.
///
/// It **skips** when the sibling repository is not present (a CI runner that
/// checked out only the app), and says so rather than passing quietly — a check
/// that cannot fail is worthless, and one that silently did not run is worse.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jobportal_mobile/core/constants/enums.dart';

/// `<repo>/jobportal-python/backend/app/models/__init__.py`, relative to the
/// Flutter package root that `flutter test` runs from.
final _modelsFile = File(
  '../jobportal-python/backend/app/models/__init__.py',
);

/// Pull `NAME = ("a", "b", ...)` out of the source, single- or multi-line.
List<String>? _tuple(String source, String name) {
  final match = RegExp(
    '^$name\\s*=\\s*\\((.*?)\\)',
    multiLine: true,
    dotAll: true,
  ).firstMatch(source);
  if (match == null) return null;

  return RegExp('["\']([^"\']+)["\']')
      .allMatches(match.group(1)!)
      .map((m) => m.group(1)!)
      .toList(growable: false);
}

void main() {
  late String source;
  late bool available;

  setUpAll(() {
    available = _modelsFile.existsSync();
    source = available ? _modelsFile.readAsStringSync() : '';
  });

  group('the Dart vocabularies match the server', () {
    // Every pair the seeker app renders. Recruiter-only vocabularies
    // (MANDATE_STATUSES, IMPORT_*, CAMPAIGN_*, MAIL_*) are deliberately absent
    // from enums.dart and so are absent here.
    final pairs = <String, List<String>>{
      'ROLES': roleValues,
      'USER_STATUSES': userStatusValues,
      'CANDIDATE_STATUSES': candidateStatusValues,
      'CANDIDATE_SOURCES': candidateSourceValues,
      'JOB_STATUSES': jobStatusValues,
      'SKILL_LEVELS': skillLevelValues,
      'JOB_TYPES': jobTypeValues,
      'WORK_MODES': workModeValues,
      'SALARY_MODES': salaryModeValues,
      'SALARY_PERIODS': salaryPeriodValues,
      'BENEFITS': jobBenefits,
      'DESCRIPTION_FORMATS': descriptionFormatValues,
      'APPLICATION_STAGES': applicationStageValues,
      'ALERT_FREQUENCIES': alertFrequencyValues,
      'LOCATION_KINDS': locationKindValues,
      'NOTIFY_CHANNELS': notifyChannelValues,
      'LOGIN_CODE_PURPOSES': loginCodePurposeValues,
    };

    pairs.forEach((pythonName, dartValues) {
      test(pythonName, () {
        if (!available) {
          markTestSkipped(
            'jobportal-python is not checked out beside this package, so the '
            'vocabulary could not be verified against its authority.',
          );
          return;
        }

        final serverValues = _tuple(source, pythonName);
        expect(
          serverValues,
          isNotNull,
          reason: '$pythonName is no longer in models/__init__.py under that '
              'name. It was renamed or removed — find out which before '
              'changing this test.',
        );

        // ORDER MATTERS on at least BENEFITS (a canonical CSV) and
        // LOCATION_KINDS / NOTIFY_CHANNELS (MySQL sorts an ENUM by declaration
        // order, and the switch renders in it). Comparing as ordered lists
        // rather than sets costs nothing and catches a reorder too.
        expect(
          dartValues,
          orderedEquals(serverValues!),
          reason: 'enums.dart has drifted from models/__init__.py. The Python '
              'file is the authority — update the Dart copy, never the other '
              'way round, and remember a member is APPENDED, never reordered.',
        );
      });
    });
  });

  group('every label map covers its vocabulary', () {
    // A missing label is not a crash — labelFor falls back to the slug — but it
    // renders 'full_time' at a user, which is the kind of defect that ships.
    void coversAll(String what, List<String> values, Map<String, String> labels) {
      test(what, () {
        expect(
          values.where((v) => !labels.containsKey(v)),
          isEmpty,
          reason: 'these members would render as their raw slug',
        );
        expect(
          labels.keys.where((k) => !values.contains(k)),
          isEmpty,
          reason: 'these labels name a member the vocabulary does not have',
        );
      });
    }

    coversAll('skill levels', skillLevelValues, skillLevelLabels);
    coversAll('job types', jobTypeValues, jobTypeLabels);
    coversAll('work modes', workModeValues, workModeLabels);
    coversAll('benefits', jobBenefits, benefitLabels);
    coversAll('application stages', applicationStageValues, applicationStageLabels);
    coversAll('notify channels', notifyChannelValues, notifyChannelLabels);
  });

  group('labelFor', () {
    test('renders the label, not the wire value', () {
      expect(labelFor(workModeLabels, 'field'), 'On the Road / Field Work');
      expect(labelFor(jobTypeLabels, 'temporary'), 'Temporary');
    });

    test('falls back to the slug rather than blanking the field', () {
      // A member added on the server and not yet mirrored here should be ugly
      // and visibly a gap, not invisible.
      expect(labelFor(workModeLabels, 'submarine'), 'submarine');
    });

    test('null and empty render as empty', () {
      expect(labelFor(workModeLabels, null), '');
      expect(labelFor(workModeLabels, ''), '');
    });
  });

  group('canonicalise — the CSV order is the vocabulary order', () {
    test('reorders a selection into the canonical order', () {
      // jobs.benefits is a canonical CSV, so two postings with the same
      // selection must hold the same string.
      expect(
        canonicalise(jobBenefits, ['paid_leave', 'esi', 'provident_fund']),
        ['provident_fund', 'esi', 'paid_leave'],
      );
    });

    test('drops an unknown member rather than trusting it', () {
      // The server's own read-side rule: a stale value narrows a search, it
      // does not crash a facet.
      expect(
        canonicalise(jobTypeValues, ['contract', 'zeppelin_pilot']),
        ['contract'],
      );
    });

    test('null and empty are empty, not an error', () {
      expect(canonicalise(jobBenefits, null), isEmpty);
      expect(canonicalise(jobBenefits, const []), isEmpty);
    });

    test('deduplicates', () {
      expect(canonicalise(jobTypeValues, ['contract', 'contract']), ['contract']);
    });
  });
}
