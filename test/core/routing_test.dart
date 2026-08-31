/// The notification-link mapping.
///
/// **A notification's `link` becomes a ROUTE, never a URL.** Handing a
/// server-supplied string to a URL launcher would make navigation a
/// server-controlled primitive — one compromised or mistaken row and every
/// reader who taps it leaves the app.
///
/// The server sends *web* paths (`/seeker/applications`, `/jobs/41`), so they
/// are translated rather than followed, and anything unrecognised lands on a
/// known screen rather than a guess.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jobportal_mobile/routing/router.dart';

void main() {
  group('routeForNotificationLink', () {
    test('a job link becomes the job route', () {
      expect(routeForNotificationLink('/jobs/41'), '/jobs/41');
      expect(routeForNotificationLink('/job/41'), '/jobs/41');
      expect(routeForNotificationLink('jobs/41'), '/jobs/41');
    });

    test('a job link with a trailing segment still resolves', () {
      expect(routeForNotificationLink('/jobs/41/apply'), '/jobs/41');
    });

    test('the web seeker paths map to their mobile tabs', () {
      expect(routeForNotificationLink('/seeker/applications'), '/applications');
      expect(routeForNotificationLink('/seeker/saved'), '/saved');
      expect(routeForNotificationLink('/seeker/profile'), '/profile');
    });

    test('the bare mobile paths map to themselves', () {
      expect(routeForNotificationLink('/applications'), '/applications');
      expect(routeForNotificationLink('/saved'), '/saved');
    });

    test('a job listing link goes to the jobs tab', () {
      expect(routeForNotificationLink('/jobs'), '/jobs');
    });

    group('refuses anything that is not an in-app destination', () {
      test('an absolute URL is refused whatever host it names', () {
        // Including our own — a link that names a host is not an in-app route,
        // and following one would be the URL-launcher behaviour this exists to
        // prevent.
        expect(
          routeForNotificationLink('https://jobsflood.com/jobs/41'),
          '/notifications',
        );
        expect(
          routeForNotificationLink('https://evil.example/steal'),
          '/notifications',
        );
        expect(
          routeForNotificationLink('javascript://%0aalert(1)'),
          '/notifications',
        );
      });

      test('an unknown path falls back to a known screen', () {
        expect(routeForNotificationLink('/admin/settings'), '/notifications');
        expect(routeForNotificationLink('/some/thing'), '/notifications');
      });

      test('null and empty fall back', () {
        expect(routeForNotificationLink(null), '/notifications');
        expect(routeForNotificationLink(''), '/notifications');
      });
    });
  });
}
