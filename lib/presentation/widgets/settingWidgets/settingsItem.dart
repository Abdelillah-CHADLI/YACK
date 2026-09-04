import 'package:flutter/material.dart';

class SettingsItem extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final String? value;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final interactive = enabled && onTap != null;

    return Semantics(
      button: interactive,
      enabled: interactive,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: interactive ? onTap : null,
          highlightColor: color.primary.withValues(alpha: 0.05),
          splashColor: color.primary.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: interactive
                              ? color.onSurface
                              : color.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (value != null && value!.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text(
                    value!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color.onSurfaceVariant,
                    ),
                  ),
                ],
                if (interactive)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      textDirection: Directionality.of(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
