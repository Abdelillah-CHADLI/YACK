import 'dart:async';
import 'package:flutter/material.dart';

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.action,
    this.onClick,
    this.isLoading = false,
    this.icon,
  });

  final String action;
  final bool isLoading;
  final FutureOr<void> Function()? onClick;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = Text(action, textAlign: TextAlign.center);

    return Semantics(
      button: true,
      enabled: !isLoading && onClick != null,
      liveRegion: isLoading,
      value: isLoading ? action : null,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isLoading || onClick == null ? null : () => onClick!(),
          icon: isLoading
              ? SizedBox.square(
                  dimension: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: colors.onPrimary,
                  ),
                )
              : icon == null
              ? const SizedBox.shrink()
              : Icon(icon, size: 20),
          label: label,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        ),
      ),
    );
  }
}
