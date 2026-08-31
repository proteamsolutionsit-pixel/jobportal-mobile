/// The job card.
///
/// The salary line is what these mostly guard. It is the field with the most
/// ways to be quietly wrong: hidden and negotiable are different statements, a
/// monthly figure rendered in lakhs is off by twelve, and a fixed figure shown
/// as "and above" is a claim the posting never made.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobportal_mobile/core/theme/app_theme.dart';
import 'package:jobportal_mobile/data/models/models.dart';
import 'package:jobportal_mobile/features/jobseeker/jobs/job_card.dart';

JobOut job({Map<String, dynamic> overrides = const {}}) => JobOut.decode({
      'id': 41,
      'title': 'Senior Accountant',
      'slug': 'senior-accountant',
      'description': 'A description.',
      'location': 'Bengaluru',
      'min_experience': 3,
      'max_experience': 6,
      'hide_salary': false,
      'skill_level': 'experienced',
      'job_type': 'full_time',
      'work_mode': 'onsite',
      'vacancies': 2,
      'status': 'active',
      'min_salary': '600000.00',
      'max_salary': '900000.00',
      'salary_period': 'year',
      'salary_mode': 'range',
      'company': {'id': 2, 'name': 'Acme Ltd'},
      ...overrides,
    });

Future<void> pumpCard(
  WidgetTester tester,
  JobOut j, {
  bool? saved,
  VoidCallback? onToggleSave,
  bool closed = false,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: JobCard(
        job: j,
        onTap: () {},
        saved: saved,
        onToggleSave: onToggleSave,
        closed: closed,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows title, company, location and experience', (tester) async {
    await pumpCard(tester, job());

    expect(find.text('Senior Accountant'), findsOneWidget);
    expect(find.text('Acme Ltd'), findsOneWidget);
    expect(find.text('Bengaluru'), findsOneWidget);
    expect(find.text('3 - 6 yrs'), findsOneWidget);
  });

  testWidgets('a job with no company reads "Confidential", not blank',
      (tester) async {
    await pumpCard(tester, job(overrides: {'company': null}));
    expect(find.text('Confidential'), findsOneWidget);
  });

  group('the salary line', () {
    testWidgets('an annual range shares its unit', (tester) async {
      await pumpCard(tester, job());
      expect(find.text('6 - 9 LPA'), findsOneWidget);
    });

    testWidgets('hidden reads "Not disclosed" — the figures are already blank',
        (tester) async {
      // hide_salary is informational: the router blanked min/max before
      // serialising. The card must never re-derive a number from something it
      // was told not to show.
      await pumpCard(
        tester,
        job(overrides: {
          'hide_salary': true,
          'min_salary': null,
          'max_salary': null,
        }),
      );
      expect(find.text('Not disclosed'), findsOneWidget);
    });

    testWidgets('negotiable is its own statement, not "Not disclosed"',
        (tester) async {
      // Negotiable says there is no number yet; hidden says there is one and it
      // is not being published. Collapsing them loses real information.
      await pumpCard(
        tester,
        job(overrides: {
          'salary_mode': 'negotiable',
          'min_salary': null,
          'max_salary': null,
        }),
      );
      expect(find.text('Negotiable'), findsOneWidget);
      expect(find.text('Not disclosed'), findsNothing);
    });

    testWidgets('a monthly figure is never rendered in lakhs', (tester) async {
      // 45000/month as "0.45 LPA" is off by twelve and reads as a typo.
      await pumpCard(
        tester,
        job(overrides: {
          'min_salary': '45000.00',
          'max_salary': null,
          'salary_period': 'month',
          'salary_mode': 'fixed',
        }),
      );
      expect(find.text('₹45,000 / month'), findsOneWidget);
    });

    testWidgets('a fixed annual figure drops the "and above" plus',
        (tester) async {
      await pumpCard(
        tester,
        job(overrides: {
          'min_salary': '800000.00',
          'max_salary': null,
          'salary_mode': 'fixed',
        }),
      );
      expect(find.text('8 LPA'), findsOneWidget);
    });

    testWidgets('an open-ended range keeps the plus', (tester) async {
      await pumpCard(
        tester,
        job(overrides: {'min_salary': '800000.00', 'max_salary': null}),
      );
      expect(find.text('8 LPA+'), findsOneWidget);
    });
  });

  testWidgets('work mode "field" reads as what people call it', (tester) async {
    // Humanising the column would give "Field", which is not the thing's name.
    await pumpCard(tester, job(overrides: {'work_mode': 'field'}));
    expect(find.text('On the Road / Field Work'), findsOneWidget);
  });

  testWidgets('multiple job types render, primary first', (tester) async {
    await pumpCard(
      tester,
      job(overrides: {
        'job_type': 'contract',
        'job_types': 'temporary,contract',
      }),
    );
    expect(find.text('Contract'), findsOneWidget);
    // 'temporary' is NOT a second spelling of 'contract' — both show.
    expect(find.text('Temporary'), findsOneWidget);
  });

  testWidgets('a closed posting says so instead of inviting an application',
      (tester) async {
    await pumpCard(tester, job(), closed: true);
    expect(find.text('No longer accepting applications'), findsOneWidget);
  });

  group('the save control', () {
    testWidgets('is absent when no handler is given', (tester) async {
      await pumpCard(tester, job());
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('reflects saved state and fires', (tester) async {
      var tapped = false;
      await pumpCard(
        tester,
        job(),
        saved: true,
        onToggleSave: () => tapped = true,
      );

      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      expect(tapped, isTrue);
    });

    testWidgets('meets the 44px primary touch floor', (tester) async {
      // Not arbitrary: the web's equivalent pill sat at 29px for the life of
      // the project because the audit's selector excluded a bare <a>.
      await pumpCard(tester, job(), saved: false, onToggleSave: () {});

      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });
}
