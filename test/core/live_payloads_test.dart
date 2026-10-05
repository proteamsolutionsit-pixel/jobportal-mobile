/// Real server payloads through the real decoders.
///
/// The fixtures under `test/fixtures/live/` were captured from the running
/// API (`/api/applications/mine`, `/api/seeker/saved`, `/api/jobs`, …), not
/// written by hand. Hand-written fixtures are how this app shipped decoding
/// `benefits` and `job_types` as comma-separated strings while the server
/// sends arrays: every hand fixture left them out, so every test passed, and
/// the Applied and Saved tabs showed "Something went wrong" on a real phone.
///
/// Recapture when the API changes; never edit one to make a test pass.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jobportal_mobile/data/models/models.dart';

Object? _load(String name) =>
    jsonDecode(File('test/fixtures/live/$name.json').readAsStringSync());

void main() {
  test('applications (the Applied tab) decode', () {
    final out = MyApplicationListOut.decode(_load('applications_mine'));
    expect(out.items, isNotEmpty);
    expect(out.total, out.items.length);
  });

  test('saved jobs (the Saved tab) decode', () {
    final out = SavedJobListOut.decode(_load('seeker_saved'));
    expect(out.items, isNotEmpty);
    expect(out.items.first.job.title, isNotEmpty);
  });

  test('job search decodes', () {
    final out = JobListOut.decode(_load('jobs_search'));
    expect(out.items, isNotEmpty);
  });

  test('job detail decodes, list fields as lists', () {
    final job = JobOut.decode(_load('job_detail'));
    expect(job.jobTypes, contains('full_time'));
    expect(job.benefits, isA<List<String>>());
  });

  test('home, suggested and similar rails decode', () {
    for (final name in ['home_jobs', 'suggested', 'similar']) {
      final raw = _load(name);
      final list = raw is Map ? raw['items'] as List : raw as List;
      for (final j in list) {
        JobOut.decode(j);
      }
    }
  });

  test('identity, branding and job state decode', () {
    UserOut.decode(_load('auth_me'));
    Branding.decode(_load('branding'));
    final st = JobStateOut.decode(_load('job_state'));
    expect(st.hasApplied, isTrue);
  });

  test('the profile and its history decode', () {
    final p = SeekerProfileOut.decode(_load('seeker_profile'));
    expect(p.fullName, isNotEmpty);
    for (final name in ['employment', 'education', 'certifications']) {
      HistoryEntry.decodeList(_load(name));
    }
    expect(HistoryEntry.decodeList(_load('employment')).single.title, 'Store Assistant');
    expect(LinkEntry.decodeList(_load('links')), isNotEmpty);
  });

  test('alerts decode, keywords included', () {
    final a = JobAlert.decodeList(_load('alerts')).single;
    expect(a.name, 'warehouse in Mumbai');
    expect(a.keyword, 'warehouse');
  });

  test('notifications and their preferences decode', () {
    NotificationListOut.decode(_load('notifications'));
    NotificationPrefs.decode(_load('notification_prefs'));
  });

  test('companies and suggestions decode', () {
    expect(CompanyListOut.decode(_load('companies')).items, isNotEmpty);
    CompanyDetailOut.decode(_load('company_detail'));
    expect(Suggestion.decodeList(_load('suggest_titles')), isNotEmpty);
    expect(Suggestion.decodeList(_load('suggest_locations')), isNotEmpty);
  });
}
