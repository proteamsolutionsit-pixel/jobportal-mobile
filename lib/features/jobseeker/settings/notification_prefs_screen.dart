/// Notification preferences.
///
/// **Three booleans, because that is what the running server serves.**
///
/// The richer per-event model — Email / In-app / Both / None chosen per event,
/// with `application.rejected` the only one that may be silenced completely —
/// exists in the web working tree and is **not on production**. It was also
/// produced by an agent run that has not been verified. Building this screen
/// against it would be building against code that has not landed.
///
/// When it does land, this screen grows and `docs/feature-parity.md` moves the
/// row from WEB AHEAD to SYNCED. Until then, what is here matches what the API
/// actually answers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/models.dart';
import '../profile/profile_controller.dart';

class NotificationPrefsScreen extends ConsumerStatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  ConsumerState<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState
    extends ConsumerState<NotificationPrefsScreen> {
  bool _saving = false;

  Future<void> _set(NotificationPrefs next) async {
    setState(() => _saving = true);
    try {
      await ref.read(seekerRepositoryProvider).setNotificationPrefs(next);
      ref.invalidate(notificationPrefsProvider);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, bad: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPrefsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        bottom: _saving
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: prefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(notificationPrefsProvider),
        ),
        data: (p) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: Text(
                'You will always see updates in the app. These control what we '
                'also send to your inbox.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Divider(height: 1),

            SwitchListTile(
              value: p.emailStatus,
              onChanged: _saving
                  ? null
                  : (v) => _set(p.copyWith(emailStatus: v)),
              title: const Text('When my application moves'),
              subtitle: const Text(
                'Shortlisted, invited to interview, offered or hired.',
              ),
            ),
            const Divider(height: 1),

            SwitchListTile(
              value: p.emailApplication,
              onChanged: _saving
                  ? null
                  : (v) => _set(p.copyWith(emailApplication: v)),
              title: const Text('Confirmations when I apply'),
              subtitle: const Text('A receipt for each application you send.'),
            ),
            const Divider(height: 1),

            SwitchListTile(
              value: p.emailDigest,
              onChanged: _saving
                  ? null
                  : (v) => _set(p.copyWith(emailDigest: v)),
              title: const Text('The regular summary'),
              subtitle: const Text(
                'One message covering the period rather than one per event.',
              ),
            ),
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: Container(
                padding: const EdgeInsets.all(Sp.x3),
                decoration: BoxDecoration(
                  color: C.surfaceSunk,
                  borderRadius: R.brMd,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 17, color: C.ink500),
                    const SizedBox(width: Sp.x2),
                    Expanded(
                      child: Text(
                        'Interview invitations and shortlisting always reach you '
                        'in the app, even with email turned off — they usually '
                        'need an answer.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
