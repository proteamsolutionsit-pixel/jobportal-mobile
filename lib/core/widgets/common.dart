/// Shared building blocks: chips, logos, section cards, form scaffolding.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/environment.dart';
import '../theme/tokens.dart';

/// A small status or attribute chip.
///
/// Colour is decorative here and **must never be the only carrier of meaning** —
/// every chip carries its label, and the tone is a reinforcement.
class Tag extends StatelessWidget {
  const Tag(
    this.label, {
    super.key,
    this.icon,
    this.background = C.surfaceSunk,
    this.foreground = C.ink700,
    this.border,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? border;

  /// The tone map for an application stage. `withdrawn` and `rejected` are
  /// deliberately neutral rather than red — a job hunt is hard enough without
  /// the app shouting failure at somebody.
  factory Tag.stage(String stage, String label) {
    return switch (stage) {
      'hired' => Tag(label, background: C.ok50, foreground: C.ok600),
      'offered' => Tag(label, background: C.ok50, foreground: C.ok600),
      'interview' => Tag(label, background: C.violet50, foreground: C.violet600),
      'shortlisted' => Tag(label, background: C.brand50, foreground: C.brand700),
      'viewed' => Tag(label, background: C.sky50, foreground: C.sky600),
      'rejected' => Tag(label, background: C.surfaceSunk, foreground: C.ink600),
      'withdrawn' => Tag(label, background: C.surfaceSunk, foreground: C.ink500),
      _ => Tag(label, background: C.surfaceSunk, foreground: C.ink700),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: R.brPill,
        border: Border.all(color: border ?? Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 5),
          ],
          // Flexible, not bare: a Tag laid out as a direct child of a Column
          // gets the full width constraint, and a long label ("No longer
          // accepting applications") overflowed it by 128px at 390px wide.
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A company logo, or its initial on a tinted square.
///
/// **Logos are public and cache normally** — unlike resumes, which are never
/// written to disk.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({
    super.key,
    this.path,
    required this.name,
    this.size = 44,
  });

  final String? path;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: C.brand50,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: C.line),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: Fonts.display,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: C.brand600,
        ),
      ),
    );

    if (path == null || path!.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(R.md),
      child: CachedNetworkImage(
        imageUrl: absoluteMediaUrl(path!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

/// A candidate's own photograph.
class Avatar extends StatelessWidget {
  const Avatar({super.key, this.path, required this.name, this.size = 56});

  final String? path;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((s) => s[0].toUpperCase()).join();

    final fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: C.brand100, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: Fonts.display,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: C.brand700,
        ),
      ),
    );

    if (path == null || path!.isEmpty) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: absoluteMediaUrl(path!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

/// Resolve a stored media path against the API origin.
///
/// The server stores `uploads/photos/x.png` — relative, and relative to the API
/// host rather than to anything the app knows. Building it in one place stops
/// each screen guessing.
String absoluteMediaUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  final base = Env.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final rel = path.startsWith('/') ? path : '/$path';
  return '$base$rel';
}

/// A titled card. The mobile equivalent of the web's `.pcard`.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.padding = const EdgeInsets.all(Sp.x4),
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: R.brLg,
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x2, Sp.x3),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: C.ink600),
                  const SizedBox(width: Sp.x2),
                ],
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                ),
                if (actionLabel != null && onAction != null)
                  // 32px floor — this is the control that measured 29px on the
                  // web for the life of the project, because the audit's
                  // selector excluded a bare <a>.
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, Touch.min),
                      padding: const EdgeInsets.symmetric(horizontal: Sp.x3),
                    ),
                    child: Text(actionLabel!),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// A label/value row for read-only detail.
class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 16, color: C.ink400),
            ),
            const SizedBox(width: Sp.x2),
          ],
          SizedBox(
            width: 118,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: C.ink800,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-width primary action with a busy state.
///
/// The busy state is not cosmetic: it is **how a double submit is prevented**,
/// and applying twice is not something the candidate can undo.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.cta = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  /// The red-orange CTA. **Reserved for the single most important action on a
  /// screen — Apply, Register. Using it anywhere else destroys its meaning.**
  final bool cta;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: Touch.primary + 4,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: cta
            ? FilledButton.styleFrom(
                backgroundColor: C.cta500,
                foregroundColor: Colors.white,
                disabledBackgroundColor: C.cta500.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white70,
              )
            : null,
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: Sp.x2),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// Show a message without inventing wording for it.
void showSnack(BuildContext context, String message, {bool bad = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bad ? C.bad600 : C.ink800,
      ),
    );
}
