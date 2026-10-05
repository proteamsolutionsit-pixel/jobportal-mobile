/// Loading, empty and error states.
///
/// Centralised because every screen needs all three and the failure mode of
/// leaving them per-screen is that some screens quietly get only one — a spinner
/// that never resolves, with no way back.
///
/// The error view **uses the server's own sentence**. `app/main.py` translates
/// pydantic's text into product wording at the boundary and keeps `loc` intact
/// specifically so a client can present it; paraphrasing it here would undo
/// that work.
library;

import 'package:flutter/material.dart';

import '../../data/models/wire.dart';
import '../errors/api_exception.dart';
import '../theme/tokens.dart';

/// A skeleton block that shimmers. Used instead of a bare spinner on lists,
/// because a skeleton says how much is coming.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = R.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(C.surfaceSunk, C.line, _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// The job-card skeleton, shaped like the real card so the page does not jump.
class JobCardSkeleton extends StatelessWidget {
  const JobCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sp.x4),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: R.brLg,
        border: Border.all(color: C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Skeleton(width: 44, height: 44, radius: R.md),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Skeleton(height: 15),
                    SizedBox(height: Sp.x2),
                    Skeleton(width: 140, height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x4),
          const Skeleton(height: 12),
          const SizedBox(height: Sp.x2),
          const Skeleton(width: 200, height: 12),
        ],
      ),
    );
  }
}

/// Nothing here, and why — plus a way onward where one exists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [C.brand400, C.violet500],
                ),
                boxShadow: [
                  BoxShadow(
                    color: C.brand500.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: 38, color: Colors.white),
            ),
            const SizedBox(height: Sp.x4),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: Sp.x2),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Sp.x5),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A failure, with retry where retrying could plausibly help.
///
/// **Retry is hidden for a 409 or a 422** — those are a rule refusing, and
/// offering to try again invites the reader to hammer a door that is closed on
/// purpose.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final offline = api?.kind == ApiErrorKind.offline;
    // A reply in a shape this build does not know. Retrying will not help,
    // and "Something went wrong" said nothing anyone could act on -- which is
    // all the Saved and Applied tabs said on 5 Oct 2026 for exactly this.
    final outdated = error is WireFormatException;
    final canRetry =
        onRetry != null && !outdated && (api == null || api.isRetryable);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: C.amber50,
                shape: BoxShape.circle,
                border: Border.all(color: Tones.amber.border, width: 2),
              ),
              child: Icon(
                offline
                    ? Icons.wifi_off_rounded
                    : outdated
                        ? Icons.system_update_rounded
                        : Icons.cloud_off_rounded,
                size: 34,
                color: C.amber500,
              ),
            ),
            const SizedBox(height: Sp.x4),
            Text(
              offline
                  ? 'You appear to be offline'
                  : outdated
                      ? 'Please update the app'
                      : 'We could not load this',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Sp.x2),
            Text(
              // The server's own wording where there is one, not ours.
              outdated
                  ? 'This screen has new information your version of the app '
                      'cannot show yet. Updating will fix it.'
                  : api?.message ?? 'Please try again in a moment.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (canRetry) ...[
              const SizedBox(height: Sp.x5),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A short inline failure — for a form, where a full-page error would lose what
/// the reader had typed.
class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x3),
      decoration: BoxDecoration(
        color: C.bad50,
        borderRadius: R.brMd,
        border: Border.all(color: C.bad500.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: C.bad600),
          const SizedBox(width: Sp.x2),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                color: C.bad600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A short inline confirmation, same shape as [InlineError].
class InlineNotice extends StatelessWidget {
  const InlineNotice(this.message, {super.key, this.icon = Icons.check_circle_outline});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x3),
      decoration: BoxDecoration(
        color: C.ok50,
        borderRadius: R.brMd,
        border: Border.all(color: C.ok500.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: C.ok600),
          const SizedBox(width: Sp.x2),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13.5, color: C.ok600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
