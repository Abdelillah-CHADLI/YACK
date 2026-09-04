import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// YACK's shared visual language.
///
/// The product is intentionally styled like a precise, trustworthy digital
/// docket: quiet surfaces, strong type, restrained colour, and clear states.
/// Screens should consume these tokens instead of inventing local styling.
class AppTheme {
  // Brand
  static const Color yackGreen = Color(0xFF0E6755);
  static const Color yackGreenLight = Color(0xFFE3F1EC);
  static const Color yackBrass = Color(0xFFB7791F);
  static const Color yackInk = Color(0xFF17231F);
  static const Color yackBackground = Color(0xFFF3F5F2);
  static const Color yackWhite = Color(0xFFFFFFFF);
  static const Color yackBlack = Color(0xFF0E1512);
  static const Color yackGray = Color(0xFF5C6963);
  static const Color yackGrayLight = Color(0xFFE7EBE8);
  static const Color yackDivider = Color(0xFFD9DFDB);

  // Dark surfaces
  static const Color darkBackground = Color(0xFF101613);
  static const Color darkSurface = Color(0xFF171F1B);
  static const Color darkSurfaceHigh = Color(0xFF202A25);
  static const Color darkText = Color(0xFFF0F4F1);

  // Semantic states
  static const Color statusGreen = Color(0xFF17815F);
  static const Color statusOrange = Color(0xFFB96B14);
  static const Color statusRed = Color(0xFFB83B3B);
  static const Color statusBlue = Color(0xFF356B8C);
  static const Color statusGray = Color(0xFF68736E);

  // Spacing and shape
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double space2Xl = 32;
  static const double pagePadding = 20;
  static const double maxContentWidth = 760;

  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 14;

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Curve ease = Curves.easeOutCubic;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A101713), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static bool disableAnimations(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static final ThemeData lightTheme = _buildTheme(Brightness.light);
  static final ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? darkBackground : yackBackground;
    final surface = isDark ? darkSurface : yackWhite;
    final surfaceLow = isDark
        ? const Color(0xFF141B17)
        : const Color(0xFFF8F9F7);
    final surfaceHigh = isDark ? darkSurfaceHigh : const Color(0xFFEBEFEC);
    final text = isDark ? darkText : yackInk;
    final textSecondary = isDark
        ? const Color(0xFFAFBBB4)
        : const Color(0xFF5C6963);
    final outline = isDark ? const Color(0xFF344039) : const Color(0xFFD6DDD8);
    final primary = isDark ? const Color(0xFF58C5A5) : yackGreen;
    final onPrimary = isDark ? const Color(0xFF082019) : yackWhite;
    final error = isDark ? const Color(0xFFFF8A86) : statusRed;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: isDark
          ? const Color(0xFF173D33)
          : const Color(0xFFDCEDE7),
      onPrimaryContainer: isDark
          ? const Color(0xFFC3F3E2)
          : const Color(0xFF0A473B),
      secondary: isDark ? const Color(0xFFE4B562) : yackBrass,
      onSecondary: isDark ? const Color(0xFF2B1B00) : yackWhite,
      secondaryContainer: isDark
          ? const Color(0xFF493615)
          : const Color(0xFFF6E9D4),
      onSecondaryContainer: isDark
          ? const Color(0xFFFFDFA4)
          : const Color(0xFF5F3B08),
      tertiary: isDark ? const Color(0xFF82B6D4) : statusBlue,
      onTertiary: isDark ? const Color(0xFF0A2636) : yackWhite,
      error: error,
      onError: isDark ? const Color(0xFF3C0507) : yackWhite,
      errorContainer: isDark
          ? const Color(0xFF541E20)
          : const Color(0xFFF8E3E2),
      onErrorContainer: isDark
          ? const Color(0xFFFFDAD8)
          : const Color(0xFF761E20),
      surface: surface,
      onSurface: text,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surfaceLow,
      surfaceContainer: isDark
          ? const Color(0xFF1C2520)
          : const Color(0xFFF0F3F0),
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: isDark
          ? const Color(0xFF2A352F)
          : const Color(0xFFE2E7E3),
      onSurfaceVariant: textSecondary,
      outline: outline,
      outlineVariant: outline,
      shadow: yackBlack,
      scrim: const Color(0xA6000000),
      inverseSurface: isDark
          ? const Color(0xFFE8EDE9)
          : const Color(0xFF26302B),
      onInverseSurface: isDark
          ? const Color(0xFF26302B)
          : const Color(0xFFF2F6F3),
      inversePrimary: isDark ? yackGreen : const Color(0xFF74D8B9),
      surfaceTint: Colors.transparent,
    );

    final base = isDark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final textTheme = base
        .copyWith(
          displaySmall: TextStyle(
            fontSize: 32,
            height: 1.12,
            letterSpacing: -0.8,
            fontWeight: FontWeight.w800,
            color: text,
          ),
          headlineMedium: TextStyle(
            fontSize: 27,
            height: 1.18,
            letterSpacing: -0.5,
            fontWeight: FontWeight.w800,
            color: text,
          ),
          headlineSmall: TextStyle(
            fontSize: 23,
            height: 1.22,
            letterSpacing: -0.3,
            fontWeight: FontWeight.w700,
            color: text,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: text,
          ),
          titleMedium: TextStyle(
            fontSize: 17,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: text,
          ),
          titleSmall: TextStyle(
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: text,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w400,
            color: text,
          ),
          bodyMedium: TextStyle(
            fontSize: 15,
            height: 1.48,
            fontWeight: FontWeight.w400,
            color: textSecondary,
          ),
          bodySmall: TextStyle(
            fontSize: 13,
            height: 1.42,
            fontWeight: FontWeight.w400,
            color: textSecondary,
          ),
          labelLarge: TextStyle(
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: onPrimary,
          ),
          labelMedium: TextStyle(
            fontSize: 14,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: text,
          ),
          labelSmall: TextStyle(
            fontSize: 12,
            height: 1.25,
            letterSpacing: 0.25,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        )
        .apply(bodyColor: text, displayColor: text);

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    );
    final controlPadding = const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 15,
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      dividerColor: outline,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleSpacing: pagePadding,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: text, size: 22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: textSecondary.withValues(alpha: 0.85),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(color: primary),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: error),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: error, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: surfaceHigh,
          disabledForegroundColor: textSecondary,
          elevation: 0,
          minimumSize: const Size(48, 52),
          padding: controlPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: surfaceHigh,
          disabledForegroundColor: textSecondary,
          minimumSize: const Size(48, 52),
          padding: controlPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: outline, width: 1.2),
          minimumSize: const Size(48, 52),
          padding: controlPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge?.copyWith(color: primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: buttonShape,
          textStyle: textTheme.labelMedium,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          foregroundColor: textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: outline),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        modalBarrierColor: Colors.black54,
        constraints: const BoxConstraints(maxWidth: 720),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
        showDragHandle: true,
        dragHandleColor: outline,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: scheme.inversePrimary,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLow,
        selectedColor: scheme.primaryContainer,
        disabledColor: surfaceHigh,
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineWidth: const WidgetStatePropertyAll(0),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.45)
              : surfaceHigh,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? primary : textSecondary,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: outline, width: 1.5),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: text, size: 22),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 1,
        focusElevation: 2,
        hoverElevation: 2,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? primary
                : textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        elevation: 0,
        useIndicator: true,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: textSecondary),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(color: primary),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: textSecondary,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceHigh,
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: 56,
        iconColor: textSecondary,
        textColor: text,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    );
  }
}
