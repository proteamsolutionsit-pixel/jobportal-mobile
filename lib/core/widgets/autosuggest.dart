/// A typeahead over the public suggestion endpoints.
///
/// ## Two rules, both load-bearing
///
/// **A suggestion list is not a whitelist.** Nothing in the posting path
/// compares a submitted title or location against `locations` or `job_titles` —
/// there is a server test guarding the *absence* of that check, because a
/// controlled vocabulary here would refuse every employer's invented job title.
/// So **submitting with nothing highlighted must not be swallowed**: the typed
/// text goes through as-is. The web component has the identical rule.
///
/// **Debounce.** The suggest endpoints run at 2 SQL statements and 5.6–6.7 ms
/// per keystroke against a `perf_probe.py` budget of 3 — the tightest in that
/// file, because everything else there is hit once per page. A typeahead that
/// fires per keystroke is the one client that can breach it.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../theme/tokens.dart';

class Autosuggest extends StatefulWidget {
  const Autosuggest({
    super.key,
    required this.controller,
    required this.fetch,
    this.label,
    this.hint,
    this.prefixIcon,
    this.onSubmitted,
    this.onSelected,
    this.textInputAction = TextInputAction.search,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final Future<List<Suggestion>> Function(String term) fetch;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;

  /// Called with whatever is in the field — **typed or chosen.**
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<Suggestion>? onSelected;
  final TextInputAction textInputAction;
  final bool autofocus;

  @override
  State<Autosuggest> createState() => _AutosuggestState();
}

class _AutosuggestState extends State<Autosuggest> {
  final _focus = FocusNode();
  final _link = LayerLink();

  Timer? _debounce;
  OverlayEntry? _overlay;
  List<Suggestion> _items = const [];
  int _highlighted = -1;

  /// Guards against an older request landing after a newer one and overwriting
  /// it — the classic typeahead race, which shows the reader results for a word
  /// they have already finished typing.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(() {
      if (!_focus.hasFocus) _close();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    _close();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final term = widget.controller.text.trim();

    if (term.length < 2) {
      _close();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () => _fetch(term));
  }

  Future<void> _fetch(String term) async {
    final id = ++_requestId;
    try {
      final results = await widget.fetch(term);
      if (!mounted || id != _requestId) return;
      setState(() {
        _items = results;
        _highlighted = -1;
      });
      if (results.isEmpty) {
        _close();
      } else if (_focus.hasFocus) {
        _open();
      }
    } catch (_) {
      // A failed suggestion lookup is not an error worth showing. The field
      // still works; that is the whole point of it not being a whitelist.
      if (id == _requestId) _close();
    }
  }

  void _open() {
    _overlay?.remove();
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 0;

    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: width,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 4,
            borderRadius: R.brMd,
            color: C.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final item = _items[i];
                  return InkWell(
                    onTap: () => _choose(item),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: Touch.primary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Sp.x3,
                        vertical: Sp.x3,
                      ),
                      color: i == _highlighted ? C.brand50 : null,
                      child: Row(
                        children: [
                          const Icon(Icons.north_west_rounded,
                              size: 15, color: C.ink400),
                          const SizedBox(width: Sp.x3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    color: C.ink800,
                                  ),
                                ),
                                if (item.parent != null)
                                  Text(
                                    item.parent!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: C.ink500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
  }

  void _choose(Suggestion item) {
    widget.controller.text = item.label;
    widget.controller.selection =
        TextSelection.collapsed(offset: item.label.length);
    _close();
    _focus.unfocus();
    widget.onSelected?.call(item);
    widget.onSubmitted?.call(item.label);
  }

  /// **Submit is never swallowed.** With something highlighted, the highlighted
  /// item wins; with nothing highlighted — which is the normal case, since a
  /// touch keyboard has no arrow keys — the typed text submits as-is.
  void _submit(String value) {
    if (_highlighted >= 0 && _highlighted < _items.length) {
      _choose(_items[_highlighted]);
      return;
    }
    _close();
    widget.onSubmitted?.call(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.autofocus,
        textInputAction: widget.textInputAction,
        onSubmitted: _submit,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: widget.prefixIcon == null
              ? null
              : Icon(widget.prefixIcon, size: 19, color: C.ink500),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    widget.controller.clear();
                    _close();
                  },
                ),
        ),
      ),
    );
  }
}
