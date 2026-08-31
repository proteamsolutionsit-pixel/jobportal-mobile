/// The Material theme, built from the JobPortal tokens.
///
/// Light only, and deliberately: the web build has no dark mode, and shipping
/// one on mobile would mean this app inventing a palette the product does not
/// have. `docs/ui-branding.md` records it as a product decision rather than an
/// omission.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: C.brand500,
      brightness: Brightness.light,
    ).copyWith(
      primary: C.brand500,
      onPrimary: Colors.white,
      primaryContainer: C.brand50,
      onPrimaryContainer: C.brand800,
      // The CTA is NOT the secondary colour. It is reserved for the single most
      // important action on a screen, and wiring it into the scheme would let
      // any widget reach for it — which is exactly how its meaning is lost.
      secondary: C.brand600,
      surface: C.surface,
      onSurface: C.ink900,
      error: C.bad500,
      onError: Colors.white,
      outline: C.line,
      outlineVariant: C.lineStrong,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: C.surfaceSunk,
      fontFamily: Fonts.body,
      textTheme: _text,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: const AppBarTheme(
        backgroundColor: C.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: C.ink900,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: Fonts.display,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: C.ink900,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      cardTheme: CardThemeData(
        color: C.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: R.brLg,
          side: const BorderSide(color: C.line),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: C.line,
        thickness: 1,
        space: 1,
      ),

      // 44px: the primary-control floor. Material's default is 36.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, Touch.primary),
          padding: const EdgeInsets.symmetric(horizontal: Sp.x5),
          shape: const RoundedRectangleBorder(borderRadius: R.brMd),
          textStyle: const TextStyle(
            fontFamily: Fonts.body,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, Touch.primary),
          foregroundColor: C.brand600,
          side: const BorderSide(color: C.lineStrong),
          padding: const EdgeInsets.symmetric(horizontal: Sp.x5),
          shape: const RoundedRectangleBorder(borderRadius: R.brMd),
          textStyle: const TextStyle(
            fontFamily: Fonts.body,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // 32px: the secondary floor. This is the control that measured 29px
          // on the web for the life of the project.
          minimumSize: const Size(48, Touch.min),
          foregroundColor: C.brand600,
          textStyle: const TextStyle(
            fontFamily: Fonts.body,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: C.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Sp.x3,
          vertical: Sp.x3,
        ),
        border: const OutlineInputBorder(
          borderRadius: R.brMd,
          borderSide: BorderSide(color: C.lineStrong),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: R.brMd,
          borderSide: BorderSide(color: C.lineStrong),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: R.brMd,
          borderSide: BorderSide(color: C.brand500, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: R.brMd,
          borderSide: BorderSide(color: C.bad500),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: R.brMd,
          borderSide: BorderSide(color: C.bad500, width: 2),
        ),
        labelStyle: const TextStyle(color: C.ink600, fontSize: 14),
        hintStyle: const TextStyle(color: C.ink400, fontSize: 14),
        errorStyle: const TextStyle(color: C.bad600, fontSize: 12.5),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: C.surfaceSunk,
        selectedColor: C.brand50,
        side: const BorderSide(color: C.line),
        shape: const RoundedRectangleBorder(borderRadius: R.brPill),
        labelStyle: const TextStyle(
          fontFamily: Fonts.body,
          fontSize: 13,
          color: C.ink700,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x1),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: C.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: C.brand50,
        elevation: 3,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: Fonts.body,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? C.brand700 : C.ink500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? C.brand700 : C.ink500,
          );
        }),
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: C.ink800,
        contentTextStyle: TextStyle(fontFamily: Fonts.body, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: R.brMd),
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: C.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: R.brLg),
        titleTextStyle: TextStyle(
          fontFamily: Fonts.display,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: C.ink900,
        ),
        contentTextStyle: TextStyle(
          fontFamily: Fonts.body,
          fontSize: 14.5,
          height: 1.45,
          color: C.ink700,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: C.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
        ),
        showDragHandle: true,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: C.brand500,
        linearMinHeight: 3,
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: C.ink600,
        titleTextStyle: TextStyle(
          fontFamily: Fonts.body,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: C.ink900,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: Fonts.body,
          fontSize: 13,
          color: C.ink500,
        ),
      ),
    );
  }

  /// Headings on the display face, body on the UI face — the stylesheet's split.
  static const _text = TextTheme(
    displaySmall: TextStyle(
        fontFamily: Fonts.display,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: C.ink900,
        height: 1.2),
    headlineMedium: TextStyle(
        fontFamily: Fonts.display,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: C.ink900,
        height: 1.25),
    headlineSmall: TextStyle(
        fontFamily: Fonts.display,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: C.ink900,
        height: 1.3),
    titleLarge: TextStyle(
        fontFamily: Fonts.display,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: C.ink900,
        height: 1.35),
    titleMedium: TextStyle(
        fontFamily: Fonts.body,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: C.ink900,
        height: 1.4),
    titleSmall: TextStyle(
        fontFamily: Fonts.body,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: C.ink800,
        height: 1.4),
    bodyLarge: TextStyle(
        fontFamily: Fonts.body, fontSize: 15, color: C.ink700, height: 1.5),
    bodyMedium: TextStyle(
        fontFamily: Fonts.body, fontSize: 14, color: C.ink700, height: 1.5),
    bodySmall: TextStyle(
        fontFamily: Fonts.body, fontSize: 12.5, color: C.ink500, height: 1.45),
    labelLarge: TextStyle(
        fontFamily: Fonts.body,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: C.ink800),
    labelMedium: TextStyle(
        fontFamily: Fonts.body,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: C.ink600),
    labelSmall: TextStyle(
        fontFamily: Fonts.body,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: C.ink500),
  );
}
