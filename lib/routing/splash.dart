/// Held while the cold-start session restore runs.
///
/// It exists so the app does not flash a login screen at somebody who is
/// already signed in — `/api/auth/me` takes a round trip, and redirecting
/// before it answers would make every launch look like a sign-out.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme/tokens.dart';
import '../features/jobseeker/authentication/auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    // The site name is a server setting, so it is read rather than hardcoded.
    final name = ref.watch(brandingProvider).valueOrNull?.name ?? 'JobPortal';

    return Scaffold(
      backgroundColor: C.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: C.brand500,
                borderRadius: BorderRadius.circular(R.lg + 4),
              ),
              child: const Icon(Icons.work_rounded, color: Colors.white, size: 38),
            ),
            const SizedBox(height: Sp.x4),
            Text(
              name,
              style: const TextStyle(
                fontFamily: Fonts.display,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: C.ink900,
              ),
            ),
            const SizedBox(height: Sp.x6),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
