/// The assistant — the same one as the web's floating widget, as a full
/// screen.
///
/// **The conversation's memory is the `context` round trip.** Each answer's
/// context goes back with the next question, which is what lets "what about
/// Pune?" amend the last search instead of starting a new one. Nothing else is
/// remembered, here or on the server, so leaving the screen ends the thread.
///
/// Links inside answers are web paths. They go through
/// [routeForAssistantLink] and become known routes, or nothing — never a URL.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/assistant.dart';
import '../../../routing/router.dart';
import '../jobs/jobs_controller.dart';

/// `Assistant::MAX_INPUT` — past this is a paste, not a question. The server
/// truncates rather than refusing; capping the field here says so up front.
const assistantMaxInput = 400;

sealed class Turn {
  const Turn();
}

class YouTurn extends Turn {
  const YouTurn(this.text);
  final String text;
}

class BotTurn extends Turn {
  const BotTurn(this.answer);
  final AssistantAnswer answer;
}

class ErrorTurn extends Turn {
  const ErrorTurn(this.text);
  final String text;
}

class AssistantState {
  const AssistantState({
    this.turns = const [],
    this.chips = const [],
    this.busy = false,
    this.context,
  });

  final List<Turn> turns;
  final List<String> chips;
  final bool busy;
  final AssistantContext? context;

  AssistantState copyWith({
    List<Turn>? turns,
    List<String>? chips,
    bool? busy,
    AssistantContext? context,
    bool clearContext = false,
  }) => AssistantState(
    turns: turns ?? this.turns,
    chips: chips ?? this.chips,
    busy: busy ?? this.busy,
    context: clearContext ? null : (context ?? this.context),
  );
}

class AssistantController extends AutoDisposeNotifier<AssistantState> {
  @override
  AssistantState build() {
    _loadStarters();
    return const AssistantState();
  }

  Future<void> _loadStarters() async {
    try {
      final intents = await ref.read(assistantRepositoryProvider).intents();
      if (state.turns.isEmpty) state = state.copyWith(chips: intents.chips);
    } catch (_) {
      // Starters are a convenience; the box still works without them.
    }
  }

  Future<void> ask(String raw) async {
    final q = raw.trim();
    if (q.isEmpty || state.busy) return;

    state = state.copyWith(
      turns: [...state.turns, YouTurn(q)],
      chips: const [],
      busy: true,
    );
    try {
      final out = await ref
          .read(assistantRepositoryProvider)
          .ask(q, context: state.context);
      final a = out.answer;
      final options = a.question?.options ?? const <String>[];
      state = state.copyWith(
        turns: [...state.turns, BotTurn(a)],
        chips: {...options, ...a.chips}.toList(),
        busy: false,
        context: a.context,
        clearContext: a.context == null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        turns: [...state.turns, ErrorTurn(e.message)],
        busy: false,
      );
    } catch (_) {
      state = state.copyWith(
        turns: [
          ...state.turns,
          const ErrorTurn(
            'I could not reach the server. Check your connection and ask again.',
          ),
        ],
        busy: false,
      );
    }
  }
}

final assistantProvider =
    AutoDisposeNotifierProvider<AssistantController, AssistantState>(
      AssistantController.new,
    );

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    _input.clear();
    ref.read(assistantProvider.notifier).ask(text);
  }

  /// Follow a link from an answer. A jobs search carries its filters into the
  /// Jobs tab first, so the list there is the one the answer counted.
  void _open(String? url) {
    final query = jobQueryForAssistantLink(url);
    if (query != null) ref.read(jobQueryProvider.notifier).state = query;
    final route = routeForAssistantLink(url);
    if (route == null) return;
    // Tabs are switched with go(); the rest stack on top of the assistant so
    // Back returns to the conversation.
    const tabs = {
      Routes.home,
      Routes.jobs,
      Routes.applications,
      Routes.saved,
      Routes.profile,
    };
    tabs.contains(route) ? context.go(route) : context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(assistantProvider);

    // Keep the newest turn in view.
    ref.listen(assistantProvider.select((s) => s.turns.length), (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x3),
              children: [
                const _Intro(),
                const SizedBox(height: Sp.x4),
                for (final t in s.turns) ...[
                  switch (t) {
                    YouTurn(:final text) => _YouBubble(text),
                    BotTurn(:final answer) => _BotBubble(
                      answer: answer,
                      onOpen: _open,
                    ),
                    ErrorTurn(:final text) => _ErrorBubble(text),
                  },
                  const SizedBox(height: Sp.x3),
                ],
                if (s.busy) const _Typing(),
              ],
            ),
          ),
          // Wrapped, not a sideways-scrolling row: a suggestion past the
          // right edge is one nobody sees. Measured — the second of two
          // starter chips sat at x=431 on a 390px phone.
          if (s.chips.isNotEmpty && !s.busy)
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x1, Sp.x4, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: Sp.x2,
                  runSpacing: Sp.x1,
                  children: [
                    for (final chip in s.chips.take(6))
                      Builder(
                        builder: (_) {
                          final t = Tones.of(toneOf(chip));
                          return ActionChip(
                            label: Text(chip),
                            labelStyle: TextStyle(
                              color: t.ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            backgroundColor: t.wash,
                            side: BorderSide(color: t.border),
                            onPressed: () => _send(chip),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x2, Sp.x3),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: assistantMaxInput,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: const InputDecoration(
                        hintText:
                            'Ask about jobs, your profile or applications',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: Sp.x1),
                  IconButton.filled(
                    tooltip: 'Send',
                    constraints: const BoxConstraints(
                      minWidth: Touch.primary,
                      minHeight: Touch.primary,
                    ),
                    onPressed: s.busy ? null : () => _send(_input.text),
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return GradientBanner(
      layers: Gradients.hero,
      padding: const EdgeInsets.all(Sp.x4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: R.brMd,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          const SizedBox(width: Sp.x3),
          const Expanded(
            child: Text(
              'Ask me to find jobs, check how complete your profile is, or see '
              'where your applications stand.',
              style: TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _YouBubble extends StatelessWidget {
  const _YouBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.x4,
            vertical: Sp.x3,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [C.brand600, C.brand500]),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(R.lg),
              topRight: Radius.circular(R.lg),
              bottomLeft: Radius.circular(R.lg),
              bottomRight: Radius.circular(R.sm),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14.5),
          ),
        ),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Tag(
      text,
      icon: Icons.error_outline_rounded,
      background: C.bad50,
      foreground: C.bad600,
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Tag(
        'Thinking…',
        icon: Icons.more_horiz_rounded,
        background: C.surface,
      ),
    );
  }
}

class _BotBubble extends StatelessWidget {
  const _BotBubble({required this.answer, required this.onOpen});

  final AssistantAnswer answer;
  final void Function(String? url) onOpen;

  @override
  Widget build(BuildContext context) {
    final a = answer;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(Sp.x4),
        decoration: BoxDecoration(
          color: C.surface,
          border: Border.all(color: C.line),
          boxShadow: Shadows.sm,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(R.lg),
            topRight: Radius.circular(R.lg),
            bottomRight: Radius.circular(R.lg),
            bottomLeft: Radius.circular(R.sm),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rendered as text, never markup: an answer is assembled from job
            // titles and company names other people typed.
            Text(
              a.text,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: C.ink800,
              ),
            ),
            if (a.facts.isNotEmpty) ...[
              const SizedBox(height: Sp.x3),
              Wrap(
                spacing: Sp.x2,
                runSpacing: Sp.x2,
                children: [
                  for (final (i, f) in a.facts.indexed)
                    _Fact(fact: f, tone: Tones.of(i + 1)),
                ],
              ),
            ],
            if (a.items.isNotEmpty) ...[
              const SizedBox(height: Sp.x3),
              for (final item in a.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.x2),
                  child: _Item(item: item, onOpen: onOpen),
                ),
            ],
            if (a.question != null && a.question!.prompt != a.text) ...[
              const SizedBox(height: Sp.x2),
              Text(
                a.question!.prompt,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: C.ink900,
                ),
              ),
            ],
            if (a.actions.any((x) => routeForAssistantLink(x.url) != null)) ...[
              const SizedBox(height: Sp.x2),
              Wrap(
                spacing: Sp.x2,
                runSpacing: Sp.x2,
                children: [
                  for (final act in a.actions)
                    if (routeForAssistantLink(act.url) != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, Touch.min + 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: Sp.x3,
                          ),
                        ),
                        onPressed: () => onOpen(act.url),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: Text(act.label),
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.fact, required this.tone});
  final AnswerFact fact;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x2),
      decoration: BoxDecoration(
        color: tone.wash,
        border: Border.all(color: tone.border),
        borderRadius: R.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fact.value,
            style: TextStyle(
              fontFamily: Fonts.display,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: tone.ink,
            ),
          ),
          Text(
            fact.label,
            style: const TextStyle(fontSize: 12, color: C.ink600),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item, required this.onOpen});
  final AnswerItem item;
  final void Function(String? url) onOpen;

  @override
  Widget build(BuildContext context) {
    final tappable = routeForAssistantLink(item.url) != null;
    final tone = Tones.of(toneOf(item.title));
    return Material(
      color: C.surfaceAlt,
      borderRadius: R.brMd,
      child: InkWell(
        borderRadius: R.brMd,
        onTap: tappable ? () => onOpen(item.url) : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            Sp.x3,
            Sp.x2 + 2,
            Sp.x2,
            Sp.x2 + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: R.brMd,
            border: Border.all(color: C.line),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: tone.solid,
                  borderRadius: R.brPill,
                ),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: C.ink900,
                      ),
                    ),
                    if (item.meta != null)
                      Text(
                        item.meta!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (item.note != null)
                      Text(
                        item.note!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (item.tag != null) ...[
                const SizedBox(width: Sp.x2),
                Tag.tone(item.tag!),
              ],
              if (tappable)
                const Icon(Icons.chevron_right_rounded, color: C.ink400),
            ],
          ),
        ),
      ),
    );
  }
}
