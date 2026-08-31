/// Navigation.
///
/// Declarative routing rather than imperative pushes, for one specific reason
/// beyond taste: **a notification carries a `link`, and it must become a route,
/// never a URL.** Handing a server-supplied string to a URL launcher would make
/// navigation a server-controlled primitive. [routeForNotificationLink] does the
/// mapping, and anything it does not recognise goes to the notifications list
/// rather than anywhere surprising.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/jobseeker/applications/applications_screen.dart';
import '../features/jobseeker/authentication/auth_controller.dart';
import '../features/jobseeker/authentication/change_password_screen.dart';
import '../features/jobseeker/authentication/forgot_password_screen.dart';
import '../features/jobseeker/authentication/login_code_screen.dart';
import '../features/jobseeker/authentication/login_screen.dart';
import '../features/jobseeker/authentication/register_screen.dart';
import '../features/jobseeker/home/home_screen.dart';
import '../features/jobseeker/jobs/job_detail_screen.dart';
import '../features/jobseeker/jobs/jobs_screen.dart';
import '../features/jobseeker/notifications/notifications_screen.dart';
import '../features/jobseeker/profile/history_screen.dart';
import '../features/jobseeker/profile/import_cv_screen.dart';
import '../features/jobseeker/profile/links_screen.dart';
import '../features/jobseeker/profile/profile_screen.dart';
import '../features/jobseeker/profile/skills_screen.dart';
import '../features/jobseeker/saved_jobs/saved_jobs_screen.dart';
import '../features/jobseeker/settings/alerts_screen.dart';
import '../features/jobseeker/settings/notification_prefs_screen.dart';
import '../features/jobseeker/settings/settings_screen.dart';
import '../data/repositories/seeker_repository.dart';
import 'shell.dart';
import 'splash.dart';

abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const loginCode = '/login/code';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const changePassword = '/change-password';

  static const home = '/home';
  static const jobs = '/jobs';
  static const applications = '/applications';
  static const saved = '/saved';
  static const profile = '/profile';
  static const notifications = '/notifications';
  static const settings = '/settings';
  static const alerts = '/settings/alerts';
  static const notificationPrefs = '/settings/notifications';
  static const skills = '/profile/skills';
  static const links = '/profile/links';
  static const importCv = '/profile/import-cv';

  static String job(int id) => '/jobs/$id';
  static String history(HistoryKind kind) => '/profile/history/${kind.name}';
}

/// Which paths a signed-out reader may see.
///
/// Job search and job detail are **public on the server** — the listing and the
/// detail endpoints take an optional session — so they are public here too. A
/// job board that demands a sign-in before showing a single advert is a job
/// board nobody browses.
const _publicPaths = {
  Routes.splash,
  Routes.login,
  Routes.loginCode,
  Routes.register,
  Routes.forgotPassword,
};

bool _isPublic(String location) {
  if (_publicPaths.contains(location)) return true;
  return location == Routes.jobs || location.startsWith('${Routes.jobs}/');
}

final routerProvider = Provider<GoRouter>((ref) {
  final rootKey = GlobalKey<NavigatorState>();
  final shellKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.splash,
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final here = state.matchedLocation;

      // Hold on the splash until /api/auth/me has answered. Redirecting before
      // that would flash the login screen at somebody who is signed in.
      if (auth is AuthUnknown) return here == Routes.splash ? null : Routes.splash;

      if (auth is SignedOut) {
        // The splash is public, but it is not a DESTINATION — it exists only
        // to hold while /api/auth/me answers. Letting a signed-out reader stay
        // there left the app on a spinner for ever, because the redirect saw a
        // public path and did nothing. Found by the flow tests.
        if (here == Routes.splash) return Routes.login;
        return _isPublic(here) ? null : Routes.login;
      }

      // Signed in.
      // must_set_password is enforced in the auth dependency; this redirect is
      // the courtesy, not the control. Everything else is blocked until it is
      // done, or the reader lands on screens whose writes will all be refused.
      if (auth is SignedIn && auth.mustSetPassword && here != Routes.changePassword) {
        return Routes.changePassword;
      }
      if (here == Routes.splash || _publicPaths.contains(here)) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Routes.loginCode,
        builder: (_, state) => LoginCodeScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.changePassword,
        builder: (_, _) => const ChangePasswordScreen(),
      ),

      // The five-tab shell.
      ShellRoute(
        navigatorKey: shellKey,
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          GoRoute(path: Routes.jobs, builder: (_, _) => const JobsScreen()),
          GoRoute(
            path: Routes.applications,
            builder: (_, _) => const ApplicationsScreen(),
          ),
          GoRoute(path: Routes.saved, builder: (_, _) => const SavedJobsScreen()),
          GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
        ],
      ),

      // Full-screen, outside the tab bar.
      GoRoute(
        path: '${Routes.jobs}/:id',
        parentNavigatorKey: rootKey,
        builder: (_, state) => JobDetailScreen(
          jobId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.alerts,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const AlertsScreen(),
      ),
      GoRoute(
        path: Routes.notificationPrefs,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const NotificationPrefsScreen(),
      ),
      GoRoute(
        path: Routes.skills,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const SkillsScreen(),
      ),
      GoRoute(
        path: Routes.links,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const LinksScreen(),
      ),
      GoRoute(
        path: Routes.importCv,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const ImportCvScreen(),
      ),
      GoRoute(
        path: '/profile/history/:kind',
        parentNavigatorKey: rootKey,
        builder: (_, state) {
          final name = state.pathParameters['kind'];
          final kind = HistoryKind.values.firstWhere(
            (k) => k.name == name,
            orElse: () => HistoryKind.employment,
          );
          return HistoryScreen(kind: kind);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(child: Text('No screen for ${state.uri}')),
    ),
  );
});

/// Turn a notification's `link` into an in-app route.
///
/// **Never opened as a URL.** The server sends things like `/seeker/applications`
/// or `/jobs/41`; those are *web* paths, so they are translated rather than
/// followed. Anything unrecognised goes to the notifications list — a known
/// screen beats a guess.
String routeForNotificationLink(String? link) {
  if (link == null || link.isEmpty) return Routes.notifications;

  // Refuse anything absolute outright: a link that names a host is not an
  // in-app destination, whatever host it names.
  if (link.contains('://')) return Routes.notifications;

  final path = link.startsWith('/') ? link : '/$link';

  final job = RegExp(r'^/jobs?/(\d+)').firstMatch(path);
  if (job != null) return Routes.job(int.parse(job.group(1)!));

  if (path.startsWith('/seeker/applications') || path.startsWith('/applications')) {
    return Routes.applications;
  }
  if (path.startsWith('/seeker/saved') || path.startsWith('/saved')) {
    return Routes.saved;
  }
  if (path.startsWith('/seeker/profile') || path.startsWith('/profile')) {
    return Routes.profile;
  }
  if (path.startsWith('/jobs')) return Routes.jobs;

  return Routes.notifications;
}

/// Rebuilds the router when the session changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
  final Ref _ref;
}
