/// Online links — LinkedIn, GitHub, a portfolio.
///
/// **The scheme is re-checked here even though the server checks it.** The
/// server's `_http_url()` refuses anything that is not http/https because a
/// `javascript:` href would be stored XSS on the **admin's** page. This client
/// checks again before making a stored link tappable, on the principle that the
/// client is the second line and not the first — a row written before the
/// server check existed would otherwise still be live here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/models.dart';
import 'profile_controller.dart';

class LinksScreen extends ConsumerWidget {
  const LinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(linksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Online presence')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLinkSheet(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add link'),
      ),
      body: links.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(linksProvider)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.link_rounded,
              title: 'No links yet',
              message: 'Add your LinkedIn, GitHub or portfolio so recruiters can '
                  'see more of your work.',
              actionLabel: 'Add a link',
              onAction: () => _showLinkSheet(context, ref, null),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: Sp.x3),
            itemBuilder: (context, i) {
              final link = list[i];
              return Container(
                padding: const EdgeInsets.all(Sp.x3),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: R.brLg,
                  border: Border.all(color: C.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: link.isSafe ? C.brand50 : C.bad50,
                        borderRadius: BorderRadius.circular(R.md),
                      ),
                      child: Icon(
                        link.isSafe ? Icons.link_rounded : Icons.warning_amber_rounded,
                        size: 18,
                        color: link.isSafe ? C.brand600 : C.bad500,
                      ),
                    ),
                    const SizedBox(width: Sp.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            link.label ?? link.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            link.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (!link.isSafe)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                'This link is not a web address and will not open.',
                                style: TextStyle(fontSize: 12, color: C.bad600),
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          _showLinkSheet(context, ref, link);
                        } else {
                          await _delete(context, ref, link);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> _delete(BuildContext context, WidgetRef ref, LinkEntry link) async {
  try {
    await ref.read(seekerRepositoryProvider).deleteLink(link.id);
    ref.invalidate(linksProvider);
    if (context.mounted) showSnack(context, 'Link removed.');
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.message, bad: true);
  }
}

Future<void> _showLinkSheet(
  BuildContext context,
  WidgetRef ref,
  LinkEntry? existing,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LinkSheet(existing: existing),
  );
}

class _LinkSheet extends ConsumerStatefulWidget {
  const _LinkSheet({this.existing});
  final LinkEntry? existing;

  @override
  ConsumerState<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends ConsumerState<_LinkSheet> {
  late final _url = TextEditingController(text: widget.existing?.url ?? '');
  late final _label = TextEditingController(text: widget.existing?.label ?? '');

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    var url = _url.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Enter a web address.');
      return;
    }
    // A convenience, not a security control: somebody typing "linkedin.com/in/x"
    // means https. The scheme check below is what actually refuses.
    if (!url.contains('://')) url = 'https://$url';

    final parsed = Uri.tryParse(url);
    if (parsed == null || (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      setState(() => _error = 'Enter a web address starting with http:// or https://');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = ref.read(seekerRepositoryProvider);
      if (widget.existing == null) {
        await repo.addLink(url: url, label: _label.text.trim());
      } else {
        await repo.editLink(
          widget.existing!.id,
          url: url,
          label: _label.text.trim(),
          // sort_order is a SORT KEY, not an insert-before index — carried
          // through unchanged rather than recomputed from the list position.
          sortOrder: widget.existing!.sortOrder,
        );
      }
      ref.invalidate(linksProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, 'Saved.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Sp.x4,
        right: Sp.x4,
        top: Sp.x2,
        bottom: MediaQuery.of(context).viewInsets.bottom + Sp.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? 'Add a link' : 'Edit link',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: Sp.x4),
          if (_error != null) ...[
            InlineError(_error!),
            const SizedBox(height: Sp.x4),
          ],
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'LinkedIn',
            ),
          ),
          const SizedBox(height: Sp.x4),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Web address',
              hintText: 'https://linkedin.com/in/…',
            ),
          ),
          const SizedBox(height: Sp.x5),
          PrimaryButton(label: 'Save', busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}
