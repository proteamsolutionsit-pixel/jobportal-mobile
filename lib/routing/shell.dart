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

  /// Each tab wears its own colour, like the web's coloured menu icons —
  /// Home brand blue, Jobs violet, Applied green, Saved pink, Profile teal.
  static const _tabs = <({String path, IconData icon, IconData active, String label, int tone})>[
    (path: Routes.home, icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home', tone: 1),
    (path: Routes.jobs, icon: Icons.travel_explore_rounded, active: Icons.travel_explore_rounded, label: 'Jobs', tone: 2),
    (
      path: Routes.applications,
      icon: Icons.task_outlined,
      active: Icons.task_rounded,
      label: 'Applied',
      tone: 6,
    ),
    (
      path: Routes.saved,
      icon: Icons.bookmark_outline_rounded,
      active: Icons.bookmark_rounded,
      label: 'Saved',
      tone: 5,
    ),
    (
      path: Routes.profile,
      icon: Icons.person_outline_rounded,
      active: Icons.person_rounded,
      label: 'Profile',
      tone: 3,
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
        bottomNavigationBar: NavigationBarTheme(
          // copyWith, not a fresh theme: a bare NavigationBarThemeData
          // replaces the app's, and the bar lost its white ground and height.
          data: Theme.of(context).navigationBarTheme.copyWith(
            indicatorColor: Tones.of(_tabs[_index].tone).wash,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontFamily: Fonts.body,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Tones.of(_tabs[_index].tone).ink : C.ink500,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              if (i == _index) return;
              context.go(_tabs[i].path);
            },
            destinations: [
              for (var i = 0; i < _tabs.length; i++)
                NavigationDestination(
                  // Coloured even when not selected, a little softer.
                  icon: Icon(
                    _tabs[i].icon,
                    color: Tones.of(_tabs[i].tone).solid.withValues(alpha: 0.7),
                  ),
                  selectedIcon: Icon(_tabs[i].active, color: Tones.of(_tabs[i].tone).solid),
                  label: _tabs[i].label,
                ),
            ],
          ),
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
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Tones.amber.wash,
                borderRadius: R.brMd,
                border: Border.all(color: Tones.amber.border),
              ),
              child: Icon(Icons.notifications_rounded, size: 20, color: Tones.amber.solid),
            ),
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
