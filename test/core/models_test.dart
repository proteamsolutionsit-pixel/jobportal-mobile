/// Strict decoding.
///
/// The point of every test here is that the models **throw** rather than yield
/// a silent null. The web build lost four screens to a client that accepted two
/// shapes: four routes declared `{record, extras}` and answered with the bare
/// record, nothing threw, and `/api/admin/candidates/{id}` printed
/// *"Account: None"* for every candidate on the platform for weeks.
///
/// So a malformed payload must be loud. That is the behaviour under test, and
/// it is easy to lose by adding one `??`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jobportal_mobile/core/constants/enums.dart';
import 'package:jobportal_mobile/data/models/models.dart';
import 'package:jobportal_mobile/data/models/wire.dart';

/// A minimal valid JobOut, as the server actually sends one.
Map<String, dynamic> jobJson({Map<String, dynamic> overrides = const {}}) => {
      'id': 41,
      'title': 'Senior Accountant',
      'slug': 'senior-accountant',
      'description': 'A description.',
      'location': 'Bengaluru',
      'min_experience': 3,
      'hide_salary': false,
      'skill_level': 'experienced',
      'job_type': 'full_time',
      'work_mode': 'onsite',
      'vacancies': 2,
      'status': 'active',
      // Money as the server sends it: a STRING, because it is a SQL DECIMAL.
      'min_salary': '600000.00',
      'max_salary': '900000.00',
      'salary_period': 'year',
      'salary_mode': 'range',
      'posted_at': '2026-08-20T10:30:00',
      ...overrides,
    };

void main() {
  group('JobOut', () {
    test('decodes a well-formed payload', () {
      final job = JobOut.decode(jobJson());
      expect(job.id, 41);
      expect(job.title, 'Senior Accountant');
      expect(job.isOpen, isTrue);
    });

    test('money arrives as a String and becomes a double', () {
      final job = JobOut.decode(jobJson());
      expect(job.minSalary, 600000.0);
      expect(job.maxSalary, 900000.0);
    });

    test('a null salary stays null rather than becoming zero', () {
      // 0 and "not stated" are different answers: one renders "Not disclosed",
      // the other would render "0 LPA".
      final job = JobOut.decode(
        jobJson(overrides: {'min_salary': null, 'max_salary': null}),
      );
      expect(job.minSalary, isNull);
      expect(job.maxSalary, isNull);
    });

    test('a bare posted_at is read as UTC, not local', () {
      final job = JobOut.decode(jobJson());
      expect(job.postedAt!.toUtc().hour, 10);
    });

    test('empty job_types means "just the primary"', () {
      // The read-side fallback is the whole backward-compatibility story: the
      // importer, seed.py and the CodeIgniter migration all set only job_type.
      final job = JobOut.decode(jobJson(overrides: {'job_types': ''}));
      expect(job.jobTypes, ['full_time']);
    });

    test('job_types comes back primary-first, then vocabulary order', () {
      final job = JobOut.decode(jobJson(overrides: {
        'job_type': 'contract',
        'job_types': 'temporary,full_time,contract',
      }));
      // Primary first, then the rest in JOB_TYPES order (full_time before
      // temporary) — so two reads of the same posting never disagree.
      expect(job.jobTypes, ['contract', 'full_time', 'temporary']);
    });

    test('an unknown job type is dropped, not trusted', () {
      // The server's own read-side rule: a stale value narrows a search, it
      // does not crash a facet.
      final job = JobOut.decode(jobJson(overrides: {
        'job_types': 'full_time,zeppelin_pilot',
      }));
      expect(job.jobTypes, ['full_time']);
    });

    test('benefits come back in the canonical CSV order', () {
      final job = JobOut.decode(jobJson(overrides: {
        'benefits': 'paid_leave,esi,provident_fund',
      }));
      expect(job.benefits, ['provident_fund', 'esi', 'paid_leave']);
    });

    test('key_skills splits into chips', () {
      final job = JobOut.decode(jobJson(overrides: {
        'key_skills': 'Tally, GST , ',
      }));
      expect(job.skillChips, ['Tally', 'GST']);
    });

    group('throws rather than yielding a silent null', () {
      test('a missing required field', () {
        final json = jobJson()..remove('title');
        expect(() => JobOut.decode(json), throwsA(isA<WireFormatException>()));
      });

      test('a required field explicitly null', () {
        expect(
          () => JobOut.decode(jobJson(overrides: {'title': null})),
          throwsA(isA<WireFormatException>()),
        );
      });

      test('a required field of the wrong type', () {
        expect(
          () => JobOut.decode(jobJson(overrides: {'min_experience': 'three'})),
          throwsA(isA<WireFormatException>()),
        );
      });

      test('a payload that is not an object at all', () {
        expect(() => JobOut.decode('nope'), throwsA(isA<WireFormatException>()));
        expect(() => JobOut.decode(null), throwsA(isA<WireFormatException>()));
      });

      test('the error names the field, so it is diagnosable', () {
        try {
          JobOut.decode(jobJson()..remove('location'));
          fail('expected a throw');
        } on WireFormatException catch (e) {
          expect(e.field, contains('location'));
          expect(e.toString(), contains('JobOut'));
        }
      });
    });

    test('an integer that arrives as 1.0 is accepted', () {
      // JSON has one number type; a whole value can round-trip as a double.
      final job = JobOut.decode(jobJson(overrides: {'min_experience': 3.0}));
      expect(job.minExperience, 3);
    });
  });

  group('JobListOut — the total is the payload\'s, not the list\'s', () {
    test('reads total, page, per_page', () {
      final list = JobListOut.decode({
        'items': [jobJson()],
        'total': 500,
        'page': 1,
        'per_page': 20,
      });
      // One item, five hundred results. Printing items.length here is the
      // "3 views" bug.
      expect(list.items.length, 1);
      expect(list.total, 500);
      expect(list.hasMore, isTrue);
    });

    test('total_capped is carried through, not dropped', () {
      final list = JobListOut.decode({
        'items': const [],
        'total': 500,
        'page': 1,
        'per_page': 20,
        'total_capped': true,
      });
      expect(list.totalCapped, isTrue);
    });

    test('total_capped defaults to false when absent', () {
      final list = JobListOut.decode({
        'items': const [],
        'total': 3,
        'page': 1,
        'per_page': 20,
      });
      expect(list.totalCapped, isFalse);
    });

    test('hasMore is false on the last page', () {
      final list = JobListOut.decode({
        'items': const [],
        'total': 20,
        'page': 1,
        'per_page': 20,
      });
      expect(list.hasMore, isFalse);
    });
  });

  group('UserOut', () {
    Map<String, dynamic> userJson({Map<String, dynamic> overrides = const {}}) => {
          'id': 7,
          'email': 'a@b.com',
          'full_name': 'A B',
          'role': 'seeker',
          'status': 'active',
          ...overrides,
        };

    test('decodes and reports the seeker role', () {
      final user = UserOut.decode(userJson());
      expect(user.isSeeker, isTrue);
      expect(user.mustSetPassword, isFalse);
    });

    test('email_verified_at absent means unverified', () {
      // Registration leaves it NULL — filling in a form proves nothing about
      // the address in it. Only the emailed code stamps it.
      expect(UserOut.decode(userJson()).isEmailVerified, isFalse);
    });

    test('email_verified_at present means verified', () {
      final user = UserOut.decode(
        userJson(overrides: {'email_verified_at': '2026-08-29T09:00:00'}),
      );
      expect(user.isEmailVerified, isTrue);
      expect(user.emailVerifiedAt!.toUtc().hour, 9);
    });

    test('must_set_password is read', () {
      final user =
          UserOut.decode(userJson(overrides: {'must_set_password': true}));
      expect(user.mustSetPassword, isTrue);
    });

    test('a seeker with no candidate record yet decodes fine', () {
      expect(UserOut.decode(userJson()).candidateId, isNull);
    });
  });

  group('SeekerProfileOut', () {
    Map<String, dynamic> profileJson({Map<String, dynamic> overrides = const {}}) => {
          'id': 3,
          'full_name': 'A B',
          'email': 'a@b.com',
          'is_searchable': true,
          'is_public': false,
          'source': 'self_signup',
          'status': 'active',
          'profile_completeness': 62,
          ...overrides,
        };

    test('CTC arrives as a String and becomes a double', () {
      final p = SeekerProfileOut.decode(profileJson(overrides: {
        'current_ctc': '450000.00',
        'expected_ctc': '600000.00',
      }));
      expect(p.currentCtc, 450000.0);
      expect(p.expectedCtc, 600000.0);
    });

    test('preferred locations split on commas', () {
      final p = SeekerProfileOut.decode(
        profileJson(overrides: {'preferred_locations': 'Pune, Bengaluru ,'}),
      );
      expect(p.preferredLocationList, ['Pune', 'Bengaluru']);
    });

    test('completeness is required — it decides who gets emailed', () {
      final json = profileJson()..remove('profile_completeness');
      expect(
        () => SeekerProfileOut.decode(json),
        throwsA(isA<WireFormatException>()),
      );
    });
  });

  group('MyApplicationOut', () {
    Map<String, dynamic> appJson({String status = 'applied'}) => {
          'id': 9,
          'job_id': 41,
          'status': status,
          'applied_at': '2026-08-20T10:30:00',
        };

    test('a withdrawn application is not active', () {
      final a = MyApplicationOut.decode(appJson(status: withdrawnStage));
      expect(a.isWithdrawn, isTrue);
      expect(a.isActive, isFalse);
    });

    test('a rejected application is not active either', () {
      expect(MyApplicationOut.decode(appJson(status: 'rejected')).isActive, isFalse);
    });

    test('an applied application is active', () {
      expect(MyApplicationOut.decode(appJson()).isActive, isTrue);
    });

    test('applied_at is required and read as UTC', () {
      expect(MyApplicationOut.decode(appJson()).appliedAt.toUtc().hour, 10);
    });
  });

  group('SavedJobOut — is_open is separate from the job', () {
    test('a saved posting that has closed says so', () {
      final list = SavedJobListOut.decode({
        'items': [
          {'job': jobJson(overrides: {'status': 'closed'}), 'is_open': false},
        ],
        'total': 1,
        'page': 1,
        'per_page': 20,
      });
      expect(list.items.single.isOpen, isFalse);
    });

    test('is_open defaults to true when absent', () {
      final list = SavedJobListOut.decode({
        'items': [
          {'job': jobJson()},
        ],
        'total': 1,
        'page': 1,
        'per_page': 20,
      });
      expect(list.items.single.isOpen, isTrue);
    });
  });

  group('NotificationListOut — unread is the badge, not items.length', () {
    test('reads unread separately from the list', () {
      final list = NotificationListOut.decode({
        'items': [
          {
            'id': 1,
            'kind': 'application.stage',
            'title': 'Moved forward',
            'read': false,
            'created_at': '2026-08-20T10:30:00',
          },
        ],
        'unread': 12,
        'more': true,
      });
      expect(list.items.length, 1);
      expect(list.unread, 12);
      expect(list.more, isTrue);
    });
  });

  group('LinkEntry — the scheme is re-checked client-side', () {
    LinkEntry link(String url) =>
        LinkEntry.decodeList([{'id': 1, 'url': url}]).single;

    test('http and https are safe', () {
      expect(link('https://linkedin.com/in/x').isSafe, isTrue);
      expect(link('http://example.com').isSafe, isTrue);
    });

    test('javascript: is not — that is stored XSS on the admin page', () {
      expect(link('javascript:alert(1)').isSafe, isFalse);
    });

    test('other schemes are refused too', () {
      expect(link('data:text/html,<script>').isSafe, isFalse);
      expect(link('file:///etc/passwd').isSafe, isFalse);
      expect(link('not a url at all').isSafe, isFalse);
    });
  });

  group('compact — never send a null over a stored value', () {
    test('drops nulls', () {
      expect(compact({'a': 1, 'b': null, 'c': 'x'}), {'a': 1, 'c': 'x'});
    });

    test('keeps an empty string, which is how a field is deliberately cleared', () {
      expect(compact({'a': ''}), {'a': ''});
    });

    test('keeps false and zero', () {
      // `if (v != null)` and `if (v)` are very different filters, and the
      // second would silently drop every "no" the reader chose.
      expect(compact({'a': false, 'b': 0}), {'a': false, 'b': 0});
    });
  });

  group('Branding', () {
    test('decodes the server settings', () {
      final b = Branding.decode({
        'name': 'Jobsflood',
        'logo_path': 'uploads/logos/site.png',
      });
      expect(b.name, 'Jobsflood');
      expect(b.logoPath, 'uploads/logos/site.png');
    });

    test('falls back to a name rather than throwing', () {
      // A branding call that answers oddly must not stop the app starting.
      expect(Branding.decode(const <String, dynamic>{}).name, 'JobPortal');
    });
  });
  group('CompanyOut reads the names the server actually sends', () {
    // Both of these were wrong in the shipped app, and nothing caught it: the
    // fields are optional, so a misspelt name is indistinguishable from an
    // absent value and every company silently had no location and no job count.
    // Payloads below are copied from live /api/companies and /api/jobs.

    test('hq_location becomes city, open_jobs becomes jobCount', () {
      final c = CompanyOut.fromWire(Wire.of({
        'id': 145,
        'name': '3M India',
        'slug': '3m-india',
        'logo_path': 'uploads/logos/co_145_581dff4cef3e.png',
        'industry': null,
        'hq_location': 'Bengaluru',
        'size_bucket': '1000+',
        'is_verified': true,
        'open_jobs': 39,
        'about': null,
      }, 'CompanyOut'));

      expect(c.city, 'Bengaluru');
      expect(c.jobCount, 39);
      expect(c.sizeBucket, '1000+');
      expect(c.isVerified, isTrue);
    });

    test('the company nested in a job carries no count, and that is fine', () {
      final c = CompanyOut.fromWire(Wire.of({
        'id': 145,
        'name': '3M India',
        'hq_location': 'Gurugram',
        'is_verified': false,
      }, 'CompanyOut'));

      expect(c.city, 'Gurugram');
      expect(c.jobCount, isNull);
      expect(c.isVerified, isFalse);
    });

    test('a field under the OLD name is ignored, not silently accepted', () {
      final c = CompanyOut.fromWire(Wire.of({
        'id': 1,
        'name': 'X',
        'city': 'Pune',
        'job_count': 7,
      }, 'CompanyOut'));

      // If this ever starts passing, someone has reverted the field names.
      expect(c.city, isNull);
      expect(c.jobCount, isNull);
    });
  });

}
