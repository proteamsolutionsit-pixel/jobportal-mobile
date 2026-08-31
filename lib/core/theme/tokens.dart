/// The JobPortal palette, type scale and spacing, transcribed from the
/// `:root` block of `jobportal-python/frontend/public/assets/css/app.css`.
///
/// **That stylesheet is the identity** — 3,967 lines, ported from the
/// CodeIgniter build, and the web app's whole fidelity strategy is "match the
/// original DOM and the pixels follow". These are the same values, so the app
/// reads as the same product.
///
/// What is deliberately **not** carried across is the desktop layout. The web
/// CSS has one appended block for small screens because the original had none —
/// at 375px the PHP top bar is 275px wide starting 150px in, so every page
/// scrolls sideways. That block is a patch on a desktop design; this app is laid
/// out for a phone from the start.
library;

import 'package:flutter/material.dart';

/// Colours. Names match the CSS custom properties one-for-one so a change on
/// either side is greppable from the other.
abstract final class C {
  // --- brand: "naukri blue" -------------------------------------------------
  static const brand50 = Color(0xFFEDF4FF); // tinted surfaces, chips
  static const brand100 = Color(0xFFDBE7FF);
  static const brand200 = Color(0xFFB8CEFF);
  static const brand300 = Color(0xFF7CA3FA);
  static const brand400 = Color(0xFF4A7CF7);
  static const brand500 = Color(0xFF275DF5); // primary
  static const brand600 = Color(0xFF1E4BD8);
  static const brand700 = Color(0xFF1739A8);
  static const brand800 = Color(0xFF122B7D);

  /// CTA red-orange. **Reserved for the single most important action on a
  /// screen — Register, Apply. Using it anywhere else destroys its meaning.**
  static const cta500 = Color(0xFFDE370D);
  static const cta600 = Color(0xFFC22F0A);
  static const cta50 = Color(0xFFFFF1ED);

  // --- status ---------------------------------------------------------------
  static const ok50 = Color(0xFFE9F7EA);
  static const ok500 = Color(0xFF2E9B31);
  static const ok600 = Color(0xFF218024);
  static const warn50 = Color(0xFFFFF6E0);
  static const warn500 = Color(0xFFB57B00);
  static const warn600 = Color(0xFF946400);
  static const bad50 = Color(0xFFFDECEA);
  static const bad500 = Color(0xFFD93A22);
  static const bad600 = Color(0xFFB52F1B);
  static const info50 = Color(0xFFEDF4FF);
  static const info500 = Color(0xFF275DF5);

  // --- decorative accents ---------------------------------------------------
  // "Colour here is decorative and must never be the only carrier of meaning."
  static const violet50 = Color(0xFFF3ECFF);
  static const violet500 = Color(0xFF8951FF);
  static const teal50 = Color(0xFFE3F7F6);
  static const teal500 = Color(0xFF0E9B93);
  static const amber50 = Color(0xFFFFF5DB);
  static const amber500 = Color(0xFFD99400);
  static const pink50 = Color(0xFFFFECF3);
  static const pink500 = Color(0xFFE0417A);
  static const lime50 = Color(0xFFEEFAE0);
  static const lime500 = Color(0xFF5C9A12);
  static const sky50 = Color(0xFFE6F5FF);
  static const sky500 = Color(0xFF0B83D9);

  /// The darker pair exists because violet-500 and sky-500 land near 4:1 on
  /// their own -50 wash, **short of AA at chip sizes**. Use these for small text
  /// on a tint, not the -500s.
  static const violet600 = Color(0xFF6B2FD6);
  static const sky600 = Color(0xFF0A5F9E);

  // --- ink ------------------------------------------------------------------
  static const ink900 = Color(0xFF121224); // headings
  static const ink800 = Color(0xFF1B2437);
  static const ink700 = Color(0xFF474D6A); // body
  static const ink600 = Color(0xFF5B6285);
  static const ink500 = Color(0xFF717B9E); // muted
  static const ink400 = Color(0xFF979EC2);

  // --- surfaces -------------------------------------------------------------
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunk = Color(0xFFF7F7F9);
  static const surfaceAlt = Color(0xFFFBFBFD);
  static const line = Color(0xFFE7E7F1);
  static const lineStrong = Color(0xFFD3D4E3);
}

/// Spacing scale — `--sp-1` … `--sp-8`.
abstract final class Sp {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 24.0;
  static const x6 = 32.0;
  static const x7 = 48.0;
  static const x8 = 64.0;
}

/// Corner radii — `--r-sm` … `--r-pill`.
abstract final class R {
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const pill = 999.0;

  static const brSm = BorderRadius.all(Radius.circular(sm));
  static const brMd = BorderRadius.all(Radius.circular(md));
  static const brLg = BorderRadius.all(Radius.circular(lg));
  static const brPill = BorderRadius.all(Radius.circular(pill));
}

/// Elevation, as the CSS shadows rather than Material's.
abstract final class Shadows {
  static const sm = [
    BoxShadow(color: Color(0x0F10151F), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const md = [
    BoxShadow(color: Color(0x1410151F), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const lg = [
    BoxShadow(color: Color(0x1F10151F), blurRadius: 28, offset: Offset(0, 8)),
  ];
}

/// Typography families. `Jakarta` is the display face for headings, `InterVar`
/// the body and UI face — the same split the stylesheet makes.
abstract final class Fonts {
  static const body = 'InterVar';
  static const display = 'Jakarta';
}

/// Touch-target floors.
///
/// **32px minimum, 44px for a primary control.** Not arbitrary: `.pcard__edit`
/// — the Edit/Add pill on every profile card — is an `<a>` and measured **29px**
/// for the whole web project, unmeasured, because the mobile audit's `CONTROLS`
/// selector deliberately excludes a bare `<a>`. It surfaced only when a new
/// section rendered the same control as a `<button>`, the honest element for
/// something that opens a form.
///
/// *An audit reporting zero is only as wide as its selector.*
abstract final class Touch {
  static const min = 32.0;
  static const primary = 44.0;
}
