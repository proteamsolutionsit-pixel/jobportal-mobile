/// The five-tab shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../core/theme/tokens.dart';
import 'router.dart';

/// Unread count for the bell. Refreshed on demand rather than polled — **there
/// is no push transport** (task MOB-B-004), and polling for notifications would
/// multiply server load by the installed base for a badge.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final list = await ref.watch(seekerRepositoryProvider).notifications(limit: 1);
    // The payload's own count, not items.length — the list is capped by `limit`
    // and here that limit is 1.
    return list.unread;
  } catch (_) {
    return 0;
  }
});

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabs = <({String path, IconData icon, IconData active, String label})>[
    (path: Routes.home, icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
    (path: Routes.jobs, icon: Icons.search_outlined, active: Icons.search_rounded, label: 'Jobs'),
    (
      path: Routes.applications,
      icon: Icons.description_outlined,
      active: Icons.description_rounded,
      label: 'Applied'
    ),
    (
      path: Routes.saved,
      icon: Icons.bookmark_outline_rounded,
      active: Icons.bookmark_rounded,
      label: 'Saved'
    ),
    (
      path: Routes.profile,
      icon: Icons.person_outline_rounded,
      active: Icons.person_rounded,
      label: 'Profile'
    ),
  ];

  int get _index {
    final i = _tabs.indexWhere((t) => location.startsWith(t.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      // Android hardware back: from any tab other than Home, go Home rather
      // than leaving the app. Leaving from the middle of a task is the most
      // common accidental exit on Android.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.home);
      },
      child: Scaffold(
        body: SafeArea(top: false, child: child),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            if (i == _index) return;
            context.go(_tabs[i].path);
          },
          destinations: [
            for (var i = 0; i < _tabs.length; i++)
              NavigationDestination(
                icon: Icon(_tabs[i].icon),
                selectedIcon: Icon(_tabs[i].active),
                label: _tabs[i].label,
              ),
          ],
        ),
      ),
    );
  }
}

/// The bell, with its unread badge. Shown in each tab's app bar.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Semantics(
      label: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      button: true,
      child: IconButton(
        onPressed: () => context.push(Routes.notifications),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none_rounded),
            if (unread > 0)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: C.cta500,
                    borderRadius: BorderRadius.circular(R.pill),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
