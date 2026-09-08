import 'package:flutter/material.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';

enum YackNoticeTone { neutral, positive, warning, critical }

/// Compact product signature used in app and authentication chrome.
class YackBrand extends StatelessWidget {
  final bool showName;
  final double size;

  const YackBrand({super.key, this.showName = true, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      label: TranslationHandler.get('app_name'),
      image: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: size * .56,
                  color: colors.onPrimary,
                ),
                PositionedDirectional(
                  end: size * .12,
                  bottom: size * .12,
                  child: Container(
                    width: size * .22,
                    height: size * .22,
                    decoration: BoxDecoration(
                      color: colors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.primary, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showName) ...[
            const SizedBox(width: 10),
            Text(
              TranslationHandler.get('app_name'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Centers wide layouts while keeping touch-friendly phone gutters.
class YackContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  const YackContent({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = AppTheme.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
          child: child,
        ),
      ),
    );
  }
}

class YackPageHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? trailing;

  const YackPageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    letterSpacing: 0.35,
                  ),
                ),
                const SizedBox(height: 5),
              ],
              Text(title, style: theme.textTheme.headlineMedium),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(subtitle!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppTheme.spaceLg),
          trailing!,
        ],
      ],
    );
  }
}

class YackSectionHeading extends StatelessWidget {
  final String title;
  final String? caption;
  final Widget? action;

  const YackSectionHeading({
    super.key,
    required this.title,
    this.caption,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(caption!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class YackNotice extends StatelessWidget {
  final String message;
  final YackNoticeTone tone;
  final IconData? icon;
  final Widget? action;

  const YackNotice({
    super.key,
    required this.message,
    this.tone = YackNoticeTone.neutral,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (foreground, background, defaultIcon) = switch (tone) {
      YackNoticeTone.positive => (
        AppTheme.statusGreen,
        AppTheme.statusGreen.withValues(alpha: .09),
        Icons.check_circle_outline,
      ),
      YackNoticeTone.warning => (
        AppTheme.statusOrange,
        AppTheme.statusOrange.withValues(alpha: .10),
        Icons.info_outline,
      ),
      YackNoticeTone.critical => (
        colors.error,
        colors.errorContainer.withValues(alpha: .55),
        Icons.warning_amber_rounded,
      ),
      YackNoticeTone.neutral => (
        colors.primary,
        colors.primaryContainer.withValues(alpha: .65),
        Icons.shield_outlined,
      ),
    };

    return Semantics(
      liveRegion: tone == YackNoticeTone.critical,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          border: BorderDirectional(
            start: BorderSide(color: foreground, width: 3),
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? defaultIcon, color: foreground, size: 21),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (action != null) ...[const SizedBox(width: 8), action!],
          ],
        ),
      ),
    );
  }
}

class YackEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const YackEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      label: '$title. $message',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceXl,
              vertical: AppTheme.space2Xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Icon(icon, size: 32, color: colors.primary),
                ),
                const SizedBox(height: AppTheme.spaceXl),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                if (action != null) ...[
                  const SizedBox(height: AppTheme.spaceXl),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared authentication shell. It keeps the brand visible without turning
/// sign-in into a marketing page and constrains forms on desktop/web.
class YackAuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? footer;
  final bool showBack;

  const YackAuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.footer,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (showBack) ...[
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 4),
                      ],
                      const YackBrand(),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(icon, color: colors.primary, size: 26),
                  ),
                  const SizedBox(height: 20),
                  Text(title, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  child,
                  if (footer != null) ...[
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 16),
                    Center(child: footer!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
