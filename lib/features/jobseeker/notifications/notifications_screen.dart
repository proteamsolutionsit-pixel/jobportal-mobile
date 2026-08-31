/// In-app notifications.
///
/// **There is no push transport.** `/api/notifications` is in-app and email
/// only; FCM/APNs would be genuinely new backend work (task MOB-B-004). So this
/// list refreshes when opened and on pull — **it does not poll**, which would
/// multiply server load by the installed base for a badge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/models.dart';
import '../../../routing/router.dart';
import '../../../routing/shell.dart';
import '../profile/profile_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          notifications.maybeWhen(
            data: (list) => list.unread == 0
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () async {
                      try {
                        await ref.read(seekerRepositoryProvider).markAllRead();
                        ref.invalidate(notificationsProvider);
                        ref.invalidate(unreadCountProvider);
                      } on ApiException catch (e) {
                        if (context.mounted) {
                          showSnack(context, e.message, bad: true);
                        }
                      }
                    },
                    child: const Text('Mark all read'),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: 'Notification settings',
            onPressed: () => context.push(Routes.notificationPrefs),
            icon: const Icon(Icons.tune_rounded, size: 20),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (list) {
          if (list.items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Nothing yet',
              message: 'We will tell you when a recruiter moves your application '
                  'forward.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: ListView.separated(
              itemCount: list.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) =>
                  _NotificationTile(notification: list.items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});
  final NotificationOut notification;

  IconData get _icon => switch (notification.kind) {
        'application.shortlisted' => Icons.star_outline_rounded,
        'application.stage' => Icons.trending_up_rounded,
        'application.rejected' => Icons.info_outline_rounded,
        'application.received' => Icons.person_add_alt_outlined,
        _ => Icons.notifications_none_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: notification.read ? C.surface : C.brand50,
      child: InkWell(
        onTap: () async {
          if (!notification.read) {
            try {
              await ref.read(seekerRepositoryProvider).markRead(notification.id);
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            } on ApiException {
              // Failing to mark it read must not block navigation.
            }
          }
          if (!context.mounted) return;
          // The link becomes a ROUTE. It is never opened as a URL — that would
          // make navigation a server-controlled primitive.
          context.push(routeForNotificationLink(notification.link));
        },
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: notification.read ? C.surfaceSunk : C.brand100,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 18, color: C.brand700),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: notification.read
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: C.ink900,
                        height: 1.35,
                      ),
                    ),
                    if (notification.body != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        notification.body!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: Sp.x2),
                    Text(
                      timeAgo(notification.createdAt),
                      style: const TextStyle(fontSize: 12, color: C.ink400),
                    ),
                  ],
                ),
              ),
              if (!notification.read)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, left: Sp.x2),
                  decoration: const BoxDecoration(
                    color: C.brand500,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
