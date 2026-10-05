/// Notification preferences — one card per event, a delivery channel each.
///
/// The server's `PrefsOut` is a list of events, each naming the channels it
/// allows (`both`, `email`, `in_app`, and `none` only where silencing is
/// permitted). Labels and help text come from the server, so this screen
/// carries no copy of its own about which events exist; a new event appears
/// here without an app release.
///
/// Until 5 Oct 2026 this screen decoded the old three-boolean shape, which
/// the server no longer sends, and failed on every account.
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

/// How each channel reads, and the tone it wears.
const _channelLabel = {
  'both': 'Email + app',
  'email': 'Email',
  'in_app': 'In app',
  'none': 'Off',
};

IconData _channelIcon(String c) => switch (c) {
      'both' => Icons.all_inbox_rounded,
      'email' => Icons.mail_outline_rounded,
      'in_app' => Icons.notifications_none_rounded,
      _ => Icons.notifications_off_outlined,
    };

/// One tone per event, in the order the server lists them.
final _eventTones = <Tone>[Tones.ok, Tones.violet, Tones.amber, Tones.sky, Tones.pink];

class NotificationPrefsScreen extends ConsumerStatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  ConsumerState<NotificationPrefsScreen> createState() => _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends ConsumerState<NotificationPrefsScreen> {
  bool _saving = false;

  Future<void> _set(NotificationPrefs next) async {
    setState(() => _saving = true);
    try {
      await ref.read(seekerRepositoryProvider).setNotificationPrefs(next);
      ref.invalidate(notificationPrefsProvider);
      if (mounted) showSnack(context, 'Saved.');
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
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x6),
          children: [
            GradientBanner(
              layers: Gradients.hero,
              padding: const EdgeInsets.all(Sp.x4),
              child: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Colors.white),
                  SizedBox(width: Sp.x3),
                  Expanded(
                    child: Text(
                      'Choose how we tell you about each update. You stay in '
                      'control — change it any time.',
                      style: TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.x4),
            for (final (i, e) in p.events.indexed) ...[
              _EventCard(
                event: e,
                tone: _eventTones[i % _eventTones.length],
                busy: _saving,
                onChanged: (c) => _set(p.withChannel(e.column, c)),
              ),
              const SizedBox(height: Sp.x3),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.tone,
    required this.busy,
    required this.onChanged,
  });

  final NotificationEvent event;
  final Tone tone;
  final bool busy;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.x4),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: R.brLg,
        border: Border.all(color: C.line),
        boxShadow: Shadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ToneBadge(icon: _channelIcon(event.channel), tone: tone),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.label, style: Theme.of(context).textTheme.titleMedium),
                    if (event.help != null) ...[
                      const SizedBox(height: 2),
                      Text(event.help!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x3),
          Wrap(
            spacing: Sp.x2,
            runSpacing: Sp.x2,
            children: [
              for (final c in event.channels)
                ChoiceChip(
                  label: Text(_channelLabel[c] ?? c),
                  avatar: Icon(
                    _channelIcon(c),
                    size: 16,
                    color: c == event.channel ? Colors.white : tone.ink,
                  ),
                  showCheckmark: false,
                  selected: c == event.channel,
                  selectedColor: tone.solid,
                  backgroundColor: tone.wash,
                  side: BorderSide(color: c == event.channel ? tone.solid : tone.border),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: c == event.channel ? Colors.white : tone.ink,
                  ),
                  // Never null: a chip with no handler draws as disabled, which
                  // made the CURRENT choice look greyed out. Choosing it again
                  // simply does nothing.
                  onSelected: (_) {
                    if (!busy && c != event.channel) onChanged(c);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
