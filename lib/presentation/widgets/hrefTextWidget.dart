import 'package:flutter/material.dart';
import 'package:yack/presentation/theme/theme.dart';

class HrefWidget extends StatelessWidget {
  final String text;
  final VoidCallback onClick;

  const HrefWidget({super.key, required this.text, required this.onClick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: text,
      button: true,
      link: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onClick,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.04),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
              child: Text(
                text,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.primary.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
