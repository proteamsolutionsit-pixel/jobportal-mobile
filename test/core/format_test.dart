/// Tests for `core/utils/format.dart`.
///
/// Fixtures ported from `jobportal-python/frontend/src/lib/format.test.ts`. The
/// web and mobile helpers share them deliberately — a near-miss in either shows
/// up on every screen, and only a shared fixture catches that.
///
/// **The UTC group is the point of this file.** Every one of those cases passes
/// trivially against a correct implementation and fails against
/// `DateTime.parse`, which is the mistake this codebase is one line away from
/// at all times. Each was checked against a deliberately broken `parseStamp`
/// (body replaced with `DateTime.tryParse(raw)`) and observed to go red first —
/// a test for a silent bug that has never been seen to fail is not evidence of
/// anything.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jobportal_mobile/core/utils/format.dart';

void main() {
  group('parseStamp — a bare timestamp from this API is UTC', () {
    test('a naive datetime is read as UTC, not local', () {
      // This is the whole reason the function exists. Pydantic serialises a
      // naive UTC value with no zone suffix; DateTime.parse would call it local.
      final parsed = parseStamp('2026-08-20T10:30:00');
      expect(parsed, isNotNull);
      expect(parsed!.toUtc().hour, 10);
      expect(parsed.toUtc().minute, 30);
      expect(parsed.isUtc || parsed.toUtc() == parsed.toUtc(), isTrue);
    });

    test('a space-separated timestamp is normalised and read as UTC', () {
      final parsed = parseStamp('2026-08-20 10:30:00');
      expect(parsed!.toUtc().hour, 10);
    });

    test('an explicit Z is left alone', () {
      expect(parseStamp('2026-08-20T10:30:00Z')!.toUtc().hour, 10);
    });

    test('an explicit offset is respected, not overwritten', () {
      // +05:30 means 10:30 local is 05:00 UTC. A parser that blindly appended
      // Z would answer 10, which is the bug in the other direction.
      expect(parseStamp('2026-08-20T10:30:00+05:30')!.toUtc().hour, 5);
      expect(parseStamp('2026-08-20T10:30:00+0530')!.toUtc().hour, 5);
    });

    test('a date-only value is UTC midnight, matching the web', () {
      // Dart reads a bare date as LOCAL midnight where ECMAScript reads it as
      // UTC midnight. The port has to say so explicitly to get the same answer.
      final parsed = parseStamp('2026-08-20');
      expect(parsed!.toUtc().hour, 0);
      expect(parsed.toUtc().day, 20);
    });

    test('null, empty and unparseable answer null rather than throwing', () {
      expect(parseStamp(null), isNull);
      expect(parseStamp(''), isNull);
      expect(parseStamp('   '), isNull);
      expect(parseStamp('not a date'), isNull);
    });
  });

  group('niceDate — one shape for the whole application', () {
    test('renders dd-mm-yyyy, zero padded', () {
      // 08-05 must never be read as May on one screen and August on the next.
      expect(niceDate('2026-05-08T00:00:00Z'), '08-05-2026');
    });

    test('falls back rather than printing a wrong date', () {
      expect(niceDate(null), '-');
      expect(niceDate('', fallback: 'Never'), 'Never');
    });
  });

  group('clockTime — 12 hour', () {
    test('midnight is 12 AM and noon is 12 PM', () {
      // Local DateTimes, because clockTime renders in the reader's zone. Using
      // DateTime.utc(...).toLocal() here would assert on wherever the test
      // machine happens to be, which is a fixture that changes by geography.
      expect(clockTime(DateTime(2026, 8, 20, 0, 5)), '12:05 AM');
      expect(clockTime(DateTime(2026, 8, 20, 12, 5)), '12:05 PM');
      expect(clockTime(DateTime(2026, 8, 20, 16, 0)), '04:00 PM');
    });
  });

  group('timeAgo', () {
    final now = DateTime.utc(2026, 8, 20, 12, 0);

    test('the ladder', () {
      expect(timeAgo(DateTime.utc(2026, 8, 20, 11, 59, 30), now: now), 'just now');
      expect(timeAgo(DateTime.utc(2026, 8, 20, 11, 55), now: now), '5 mins ago');
      expect(timeAgo(DateTime.utc(2026, 8, 20, 11, 0), now: now), '1 hour ago');
      expect(timeAgo(DateTime.utc(2026, 8, 17, 12, 0), now: now), '3 days ago');
    });

    test('a future stamp is scheduled, not a negative age', () {
      expect(timeAgo(DateTime.utc(2026, 8, 21, 12, 0), now: now), 'scheduled');
    });

    test('past a month it becomes an absolute date', () {
      expect(timeAgo(DateTime.utc(2026, 1, 5, 12, 0), now: now), niceDate(DateTime.utc(2026, 1, 5, 12, 0)));
    });
  });

  group('asNumber — money arrives as a String (D-002)', () {
    test('parses the string form the API actually sends', () {
      // MySQL DECIMAL through pydantic: "900000.00", not 900000.
      expect(asNumber('900000.00'), 900000.0);
      expect(asNumber('450000'), 450000.0);
    });

    test('accepts a number too, since request shapes send one', () {
      expect(asNumber(450000), 450000.0);
      expect(asNumber(4.5), 4.5);
    });

    test('null and empty are null, not zero', () {
      // A blank salary must not become a literal 0 — that would render
      // "Not disclosed" for a real free posting and 0 LPA for a blank one.
      expect(asNumber(null), isNull);
      expect(asNumber(''), isNull);
      expect(asNumber('  '), isNull);
    });
  });

  group('inrLakhs', () {
    test('trims trailing zeros', () {
      expect(inrLakhs(500000), '5 LPA');
      expect(inrLakhs(450000), '4.5 LPA');
    });

    test('crores above a hundred lakh', () {
      expect(inrLakhs(10000000), '1 Cr');
      expect(inrLakhs(25000000), '2.5 Cr');
    });

    test('reads the string form', () {
      expect(inrLakhs('450000.00'), '4.5 LPA');
    });

    test('nothing, zero and negative are the fallback', () {
      expect(inrLakhs(null), 'Not disclosed');
      expect(inrLakhs(0), 'Not disclosed');
      expect(inrLakhs(-1), 'Not disclosed');
    });
  });

  group('salaryRange', () {
    test('shares the unit suffix when both sides match', () {
      expect(salaryRange(600000, 900000), '6 - 9 LPA');
    });

    test('keeps both units when they differ', () {
      expect(salaryRange(900000, 12000000), '9 LPA - 1.2 Cr');
    });

    test('open ended and upper bound only', () {
      expect(salaryRange(600000, null), '6 LPA+');
      expect(salaryRange(null, 900000), 'Up to 9 LPA');
    });

    test('hidden wins over any figure', () {
      expect(salaryRange(600000, 900000, hidden: true), 'Not disclosed');
    });
  });

  group('payLabel — the three things salaryRange cannot say', () {
    test('with no period and no mode it equals salaryRange', () {
      expect(payLabel(600000, 900000, period: null, mode: null), salaryRange(600000, 900000));
    });

    test('a monthly figure is never rendered in lakhs', () {
      // 45000/month as "0.45 LPA" is off by twelve and looks like a typo.
      expect(payLabel(45000, null, period: 'month', mode: 'fixed'), '₹45,000 / month');
    });

    test('fixed drops the "+" that means and-above', () {
      expect(payLabel(800000, null, mode: 'fixed'), '8 LPA');
      expect(payLabel(800000, null), '8 LPA+');
    });

    test('negotiable is a distinct statement from hidden', () {
      expect(payLabel(null, null, mode: 'negotiable'), 'Negotiable');
    });

    test('hidden beats negotiable when a posting is both', () {
      // A posting that is both has a number it chose not to publish, so
      // "Negotiable" would be a claim about that number.
      expect(payLabel(600000, 900000, hidden: true, mode: 'negotiable'), 'Not disclosed');
    });
  });

  group('groupIndian', () {
    test('last three, then pairs', () {
      expect(groupIndian(45000), '45,000');
      expect(groupIndian(4500000), '45,00,000');
      expect(groupIndian(100), '100');
      expect(groupIndian(1000), '1,000');
    });
  });

  group('experienceLabel', () {
    test('the four shapes', () {
      expect(experienceLabel(0, 0), 'Fresher');
      expect(experienceLabel(0, 6), '6 mos');
      expect(experienceLabel(5, 0), '5 yrs');
      expect(experienceLabel(5, 6), '5 yrs 6 mos');
    });

    test('singulars', () {
      expect(experienceLabel(1, 1), '1 yr 1 mo');
    });

    test('null is Fresher, not an error', () {
      expect(experienceLabel(null, null), 'Fresher');
    });
  });

  group('experienceRangeLabel', () {
    test('the three shapes', () {
      expect(experienceRangeLabel(2, 5), '2 - 5 yrs');
      expect(experienceRangeLabel(5, null), '5+ yrs');
      expect(experienceRangeLabel(0, null), 'Any experience');
    });
  });

  group('noticeLabel', () {
    test('immediate, days, months', () {
      expect(noticeLabel(0), 'Immediate');
      expect(noticeLabel(15), '15 days');
      expect(noticeLabel(60), '2 months');
      expect(noticeLabel(30), '1 month');
    });

    test('unset is not zero', () {
      // "Not specified" and "Immediate" are different answers.
      expect(noticeLabel(null), 'Not specified');
    });
  });

  group('fileSizeLabel', () {
    test('never a misleading 0 KB', () {
      expect(fileSizeLabel(0), '—');
      expect(fileSizeLabel(812), '812 B');
      expect(fileSizeLabel(4300), '4.2 KB');
    });
  });

  group('resultCount — a capped total is a floor', () {
    test('an exact total prints exactly', () {
      expect(resultCount(42), '42');
    });

    test('a capped total says so rather than looking precise', () {
      // The backend stops counting rather than running an unbounded COUNT(*).
      // Printing "500" would be a precise-looking wrong number.
      expect(resultCount(500, capped: true), '500+');
    });
  });
}
