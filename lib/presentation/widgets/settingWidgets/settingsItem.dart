import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:flutter/material.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';

class SettingsItem extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    void futureFeature() {
      SnackBarHandler.showMessage(
        context,
        TranslationHandler.get('under_construction'),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? futureFeature,
        highlightColor: color.primary.withValues(alpha: 0.05),
        splashColor: color.primary.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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
              AnimatedRotation(
                duration: AppTheme.fast,
                turns: 0,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.chevron_right, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
