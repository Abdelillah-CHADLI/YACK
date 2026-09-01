import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Central design system for YACK.
///
/// Preserves the existing brand identity (yackGreen primary) while evolving
/// the components, typography, spacing and micro-interactions into a
/// polished, professional SaaS-grade contract management product.
class AppTheme {
  // ---------------------------------------------------------------------------
  // Brand colors (kept identical to the original identity)
  // ---------------------------------------------------------------------------
  static const Color yackGreen = Color(0xFF00D563);
  static const Color yackGreenLight = Color(0xFFE8F5E9);
  static const Color yackBackground = Color(0xFFF5F5F5);
  static const Color yackWhite = Color(0xFFFFFFFF);
  static const Color yackBlack = Color(0xFF000000);
  static const Color yackGray = Color(0xFF757575);
  static const Color yackGrayLight = Color(0xFFEEEEEE);
  static const Color yackDivider = Color(0xFFE0E0E0);

  // Dark mode colors
  static const Color darkBackground = Color(0xFF111318);
  static const Color darkSurface = Color(0xFF1A1D23);
  static const Color darkSurfaceHigh = Color(0xFF242832);
  static const Color darkText = Color(0xFFE4E6EB);

  // Semantic status colors (used consistently across statuses/badges)
  static const Color statusGreen = Color(0xFF16A34A);
  static const Color statusOrange = Color(0xFFF59E0B);
  static const Color statusRed = Color(0xFFDC2626);
  static const Color statusBlue = Color(0xFF2563EB);
  static const Color statusGray = Color(0xFF6B7280);

  // ---------------------------------------------------------------------------
  // Motion + spacing tokens
  // ---------------------------------------------------------------------------
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 350);
  static const Curve ease = Curves.easeOutCubic;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// Whether the user prefers reduced motion.
  static bool disableAnimations(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  // ---------------------------------------------------------------------------
  // Light Theme
  // ---------------------------------------------------------------------------
  static final ThemeData lightTheme = _buildTheme(
    brightness: Brightness.light,
  );

  // ---------------------------------------------------------------------------
  // Dark Theme
  // ---------------------------------------------------------------------------
  static final ThemeData darkTheme = _buildTheme(
    brightness: Brightness.dark,
  );

  static ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final Color background = isDark ? darkBackground : yackBackground;
    final Color surface = isDark ? darkSurface : yackWhite;
    final Color surfaceHigh =
        isDark ? darkSurfaceHigh : const Color(0xFFF7F9F8);
    final Color text = isDark ? darkText : const Color(0xFF17211B);
    final Color textSecondary = isDark ? const Color(0xFF9CA3AF) : yackGray;
    final Color divider = isDark ? const Color(0xFF2C2F36) : const Color(0xFFE3E7E4);

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: yackGreen,
      onPrimary: isDark ? yackBlack : yackWhite,
      primaryContainer: isDark
          ? const Color(0xFF0E3D27)
          : const Color(0xFFDCFCE5),
      onPrimaryContainer: isDark
          ? const Color(0xFFB8F5CC)
          : const Color(0xFF0B3D24),
      secondary: yackGreen,
      onSecondary: isDark ? yackBlack : yackWhite,
      secondaryContainer: isDark
          ? const Color(0xFF16351F)
          : const Color(0xFFE8F5E9),
      onSecondaryContainer: isDark
          ? const Color(0xFFB8D8C0)
          : const Color(0xFF14401D),
      tertiary: isDark ? const Color(0xFF8AB4F8) : const Color(0xFF2E6BD6),
      onTertiary: isDark ? yackBlack : yackWhite,
      error: isDark ? const Color(0xFFEF5350) : const Color(0xFFD32F2F),
      onError: yackWhite,
      errorContainer: isDark
          ? const Color(0xFF4C1D1D)
          : const Color(0xFFFDECEC),
      onErrorContainer: isDark
          ? const Color(0xFFF3B3B3)
          : const Color(0xFF7A1F1F),
      surface: surface,
      onSurface: text,
      surfaceContainerLowest: surface,
      surfaceContainerLow: isDark ? const Color(0xFF171A1F) : const Color(0xFFFAFBFA),
      surfaceContainer: isDark ? darkSurfaceHigh : const Color(0xFFF3F5F3),
      surfaceContainerHigh: isDark ? const Color(0xFF2C3038) : const Color(0xFFEDF1EE),
      surfaceContainerHighest: isDark ? const Color(0xFF333840) : yackGrayLight,
      onSurfaceVariant: textSecondary,
      outline: divider,
      outlineVariant: divider,
      shadow: const Color(0xFF000000),
      scrim: const Color(0x99000000),
      inverseSurface: isDark ? const Color(0xFFEDEDED) : const Color(0xFF23282A),
      onInverseSurface: isDark ? const Color(0xFF23282A) : const Color(0xFFEDEDED),
      inversePrimary: isDark ? const Color(0xFF0B3D24) : const Color(0xFF5BE398),
      surfaceTint: Colors.transparent,
    );

    // Typography hierarchy: Primary → Secondary → Supporting → Metadata
    final TextTheme baseText = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final TextTheme textTheme = baseText
        .copyWith(
          displaySmall: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: text,
            letterSpacing: -0.5,
            height: 1.15,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: text,
            letterSpacing: -0.3,
            height: 1.2,
          ),
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: text,
            height: 1.25,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: text,
            height: 1.3,
          ),
          titleMedium: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: text,
            height: 1.3,
          ),
          titleSmall: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: text,
            height: 1.35,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: text,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textSecondary,
            height: 1.5,
          ),
          bodySmall: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: textSecondary,
            height: 1.45,
          ),
          labelLarge: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.onPrimary,
          ),
          labelMedium: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: text,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textSecondary,
            letterSpacing: 0.3,
          ),
        )
        .apply(
          bodyColor: text,
          displayColor: text,
        );

    final RoundedRectangleBorder buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd));

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,

      // Micro-interactions (default page transitions kept for performance)
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: text, size: 24),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.85), fontSize: 14),
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
        errorStyle: const TextStyle(fontSize: 12.5),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: yackGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: yackGreen,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          animationDuration: AppTheme.normal,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: yackGreen,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? const Color(0xFF5BE398) : yackGreen,
          side: BorderSide(color: yackGreen, width: 1.5),
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          animationDuration: AppTheme.normal,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? const Color(0xFF5BE398) : yackGreen,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: divider),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        modalBarrierColor: Colors.black45,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: textSecondary.withValues(alpha: 0.4),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2A2E36) : const Color(0xFF23282A),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        elevation: 6,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: isDark ? const Color(0xFF0E3D27) : const Color(0xFFDCFCE5),
        side: BorderSide(color: divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        labelStyle: textTheme.labelMedium,
      ),

      switchTheme: SwitchThemeData(
        trackOutlineWidth: WidgetStateProperty.all(0),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? yackGreen.withValues(alpha: 0.4)
              : divider,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? yackGreen
              : textSecondary,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      iconTheme: IconThemeData(color: text, size: 24),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: yackGreen,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: yackGreen,
        unselectedItemColor: textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: yackGreen,
        linearTrackColor: yackGreen.withValues(alpha: 0.2),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
    );
  }
}
