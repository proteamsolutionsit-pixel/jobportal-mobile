/// The colour system's one piece of logic, and the assistant's wire and link
/// handling.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jobportal_mobile/core/theme/tokens.dart';
import 'package:jobportal_mobile/core/utils/format.dart';
import 'package:jobportal_mobile/data/models/assistant.dart';
import 'package:jobportal_mobile/data/models/wire.dart';
import 'package:jobportal_mobile/routing/router.dart';

void main() {
  group('toneOf matches the web', () {
    // Computed by running toneOf() from frontend/src/lib/format.ts on these
    // exact strings. If either side's hash changes, a skill or an employer
    // changes colour between the site and the app — this is what notices.
    const fixtures = {
      'Python': 8,
      'python': 8,
      '  Python ': 8,
      'Tally ERP': 5,
      'Accenture': 4,
      'Infosys': 7,
      'SAP FICO': 7,
      'Bengaluru': 1,
      '': 1,
      'Ünïcode': 6,
      'HR Scheduler': 3,
      'Customer Support Executive': 5,
    };
    fixtures.forEach((text, tone) {
      test('"$text" -> $tone', () => expect(toneOf(text), tone));
    });

    test('null is tone 1, like an empty string', () => expect(toneOf(null), 1));

    test('every tone exists in the palette', () {
      for (var n = 1; n <= 8; n++) {
        expect(Tones.of(n), Tones.all[n - 1]);
      }
    });
  });

  group('routeForAssistantLink', () {
    test('job and company links become their screens', () {
      expect(routeForAssistantLink('/jobs/41'), '/jobs/41');
      expect(routeForAssistantLink('/companies/7'), '/companies/7');
    });

    test('the seeker pages map to the app screens that hold them', () {
      expect(routeForAssistantLink('/seeker/applications'), Routes.applications);
      expect(routeForAssistantLink('/seeker/saved'), Routes.saved);
      expect(routeForAssistantLink('/seeker/profile'), Routes.profile);
      expect(routeForAssistantLink('/seeker/alerts'), Routes.alerts);
      expect(routeForAssistantLink('/seeker/viewers'), Routes.settings);
      expect(routeForAssistantLink('/upload-resume'), Routes.importCv);
      expect(routeForAssistantLink('/companies'), Routes.companies);
    });

    test('a filtered jobs link opens the Jobs tab', () {
      expect(routeForAssistantLink('/jobs?location=bengaluru'), Routes.jobs);
    });

    test('anything it does not know goes nowhere, never to a URL', () {
      expect(routeForAssistantLink('https://evil.example/jobs/1'), isNull);
      expect(routeForAssistantLink('/admin'), isNull);
      expect(routeForAssistantLink('/recruiter/search'), isNull);
      expect(routeForAssistantLink('/jobs/41/applicants'), isNull);
      expect(routeForAssistantLink(null), isNull);
      expect(routeForAssistantLink(''), isNull);
    });
  });

  group('jobQueryForAssistantLink', () {
    test('carries the filters the app can apply', () {
      final q = jobQueryForAssistantLink(
        '/jobs?q=python+django&location=bengaluru&work_mode=remote&job_type=full_time&exp=3',
      )!;
      expect(q.q, 'python django');
      expect(q.locations, ['bengaluru']);
      expect(q.workModes, ['remote']);
      expect(q.jobTypes, ['full_time']);
      expect(q.expMin, 3);
    });

    test('leaves out salary, whose unit the link does not state', () {
      final q = jobQueryForAssistantLink('/jobs?q=sap&min_salary=8')!;
      expect(q.minSalary, isNull);
      expect(q.q, 'sap');
    });

    test('a bare jobs link, or any other link, is not a search', () {
      expect(jobQueryForAssistantLink('/jobs'), isNull);
      expect(jobQueryForAssistantLink('/jobs/41'), isNull);
      expect(jobQueryForAssistantLink('/seeker/profile?x=1'), isNull);
    });
  });

  group('assistant models are strict', () {
    test('a real answer decodes', () {
      // Captured from the local server: "jobs in bangalore".
      final out = AskOut.decode({
        'question': 'jobs in bangalore',
        'answer': {
          'intent': 'find_jobs',
          'text': 'One open job matches in Bengaluru.',
          'items': [
            {
              'title': 'Senior PHP Developer',
              'meta': 'Acme · Bengaluru',
              'url': '/jobs/1',
              'tag': 'Experienced',
            },
          ],
          'facts': [],
          'chips': ['Create a job alert for this', 'Most in-demand skills'],
          'actions': [
            {'label': 'See all 1 on the jobs page', 'url': '/jobs?location=bengaluru'},
          ],
          'question': null,
          'context': {
            'intent': 'find_jobs',
            'filters': {'location': 'bengaluru'},
            'awaiting': null,
          },
        },
      });

      expect(out.answer.intent, 'find_jobs');
      expect(out.answer.items.single.url, '/jobs/1');
      expect(out.answer.actions.single.url, '/jobs?location=bengaluru');
      expect(out.answer.context!.filters, {'location': 'bengaluru'});
      // Sent back exactly as it came — that round trip is the memory.
      expect(out.answer.context!.toJson(), {
        'intent': 'find_jobs',
        'filters': {'location': 'bengaluru'},
        'awaiting': null,
      });
    });

    test('a missing text is an error, not a blank bubble', () {
      expect(
        () => AskOut.decode({
          'question': 'hi',
          'answer': {'intent': 'greeting'},
        }),
        throwsA(isA<WireFormatException>()),
      );
    });

    test('a wrapper that is not the declared shape is refused', () {
      // Rule 2: one shape. {data: {answer: ...}} is not tolerated.
      expect(
        () => AskOut.decode({
          'data': {'question': 'hi', 'answer': {'intent': 'x', 'text': 'y'}},
        }),
        throwsA(isA<WireFormatException>()),
      );
    });

    test('filters must be an object', () {
      expect(
        () => AssistantContext.fromWire(Wire.of({'filters': 'x'}, 'ctx')),
        throwsA(isA<WireFormatException>()),
      );
    });

    test('starter chips decode', () {
      final i = AssistantIntents.decode({
        'role': 'seeker',
        'chips': ['Recommend jobs for me', 'My applications'],
        'intents': ['greeting'],
      });
      expect(i.chips, ['Recommend jobs for me', 'My applications']);
    });
  });
}
