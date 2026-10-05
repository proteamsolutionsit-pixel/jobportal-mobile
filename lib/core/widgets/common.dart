/// Shared building blocks: chips, logos, section cards, form scaffolding.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/environment.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';

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

  /// A chip coloured by its own text — the web's `.chip--tN`, via [toneOf], so a
  /// skill is the same colour in the app and on the site.
  factory Tag.tone(String label, {IconData? icon}) {
    final t = Tones.of(toneOf(label));
    return Tag(label, icon: icon, background: t.wash, foreground: t.ink, border: t.border);
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
    // Each employer wears its own tone, as its card does on the web, so a
    // list of logo-less companies is not a column of identical blue squares.
    final tone = Tones.of(toneOf(name));

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.wash,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: tone.border),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: Fonts.display,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: tone.ink,
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

    // The web's initials avatar: a violet-to-brand disc with white letters.
    final fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.violet500, C.brand500],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: Fonts.display,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: Colors.white,
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
    this.tone,
    this.padding = const EdgeInsets.all(Sp.x4),
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  /// When set, the icon sits on a solid badge of this tone and the header takes
  /// a wash of it, as each section of the web profile does.
  final Tone? tone;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = tone;
    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: R.brLg,
        border: Border.all(color: C.line),
        boxShadow: t == null ? null : Shadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: t == null
                ? null
                : BoxDecoration(
                    gradient: LinearGradient(
                      colors: [t.wash, C.surface],
                      stops: const [0, 0.85],
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(R.lg)),
                  ),
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x2, Sp.x3),
            child: Row(
              children: [
                if (icon != null && t != null) ...[
                  ToneBadge(icon: icon!, tone: t),
                  const SizedBox(width: Sp.x3),
                ] else if (icon != null) ...[
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

/// A white icon on a solid tone — the web's `.tile__icon` and the profile
/// section icons.
class ToneBadge extends StatelessWidget {
  const ToneBadge({super.key, required this.icon, required this.tone, this.size = 34});

  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.solid,
        borderRadius: R.brMd,
        boxShadow: const [
          BoxShadow(color: Color(0x2E10151F), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.53, color: Colors.white),
    );
  }
}

/// A gradient panel — the web's `.page-hero` ([Gradients.hero]) and
/// `.profhead__band` ([Gradients.band]). Layers paint bottom to top, the way a
/// CSS `background:` list stacks (where the base gradient is written last).
class GradientBanner extends StatelessWidget {
  const GradientBanner({
    super.key,
    required this.layers,
    required this.child,
    this.padding = const EdgeInsets.all(Sp.x5),
    this.radius = R.brLg,
  });

  final List<Gradient> layers;
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          for (final g in layers)
            Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: g)),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// A coloured statistic tile — the web dashboard's `.tile.tile--{tone}`: a
/// tinted wash, a solid icon badge, the label, then the figure in the tone's
/// ink.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.note,
    this.onTap,
  });

  final String label;

  /// Null while loading, which draws a placeholder rather than a 0 that reads
  /// like an answer.
  final String? value;
  final IconData icon;
  final Tone tone;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: value == null ? label : '$label: $value',
      excludeSemantics: true,
      child: Material(
        color: tone.wash,
        borderRadius: R.brLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: R.brLg,
          child: Container(
            padding: const EdgeInsets.all(Sp.x3 + 2),
            decoration: BoxDecoration(
              borderRadius: R.brLg,
              border: Border.all(color: tone.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ToneBadge(icon: icon, tone: tone, size: 32),
                const SizedBox(height: Sp.x3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: C.ink600),
                ),
                const SizedBox(height: 4),
                if (value == null)
                  Container(
                    width: 36,
                    height: 22,
                    decoration: BoxDecoration(color: tone.border, borderRadius: R.brSm),
                  )
                else
                  Text(
                    value!,
                    style: TextStyle(
                      fontFamily: Fonts.display,
                      fontSize: 24,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: tone.ink,
                    ),
                  ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: C.ink500),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One figure in a [PageHero]: the value bold, its label beside it.
typedef HeroPill = ({IconData icon, String text});

/// The gradient header at the top of a main tab — the web's `.page-hero`,
/// with the page's own figures as pills. Every figure handed to it must come
/// from the server (a `total`, never a list length).
class PageHero extends StatelessWidget {
  const PageHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.pills = const [],
    this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<HeroPill> pills;

  /// Anything else that belongs inside the banner — a search field.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return GradientBanner(
      layers: Gradients.hero,
      padding: const EdgeInsets.all(Sp.x4 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: R.brMd,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: Fonts.display,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pills.isNotEmpty) ...[
            const SizedBox(height: Sp.x3),
            Wrap(
              spacing: Sp.x2,
              runSpacing: Sp.x2,
              children: [for (final p in pills) _HeroPillChip(p)],
            ),
          ],
          if (child != null) ...[const SizedBox(height: Sp.x3), child!],
        ],
      ),
    );
  }
}

class _HeroPillChip extends StatelessWidget {
  const _HeroPillChip(this.pill);
  final HeroPill pill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: R.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pill.icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            pill.text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled fact on a tinted tile — salary, experience, location.
class FactTile extends StatelessWidget {
  const FactTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.x3),
      decoration: BoxDecoration(
        color: tone.wash,
        borderRadius: R.brLg,
        border: Border.all(color: tone.border),
      ),
      child: Row(
        children: [
          ToneBadge(icon: icon, tone: tone, size: 34),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11.5, color: C.ink600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: tone.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
