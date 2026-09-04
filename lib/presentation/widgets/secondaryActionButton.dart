import 'dart:async';
import 'package:flutter/material.dart';

class SecondaryActionButton extends StatelessWidget {
  const SecondaryActionButton({
    super.key,
    required this.action,
    this.onClick,
    this.isLoading = false,
    this.destructive = false,
    this.icon,
  });

  final String action;
  final bool isLoading;
  final FutureOr<void> Function()? onClick;
  final bool destructive;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      enabled: !isLoading && onClick != null,
      liveRegion: isLoading,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: isLoading || onClick == null ? null : () => onClick!(),
          icon: isLoading
              ? SizedBox.square(
                  dimension: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: foreground,
                  ),
                )
              : icon == null
              ? const SizedBox.shrink()
              : Icon(icon, size: 20),
          label: Text(action, textAlign: TextAlign.center),
          style: OutlinedButton.styleFrom(
            foregroundColor: foreground,
            side: BorderSide(
              color: destructive
                  ? theme.colorScheme.error.withValues(alpha: .65)
                  : theme.colorScheme.outline,
            ),
            minimumSize: const Size.fromHeight(54),
          ),
        ),
      ),
    );
  }
}
