import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:yack/presentation/theme/theme.dart';

class SecondaryActionButton extends StatelessWidget {
  const SecondaryActionButton({
    super.key,
    required this.action,
    this.onClick,
    this.isLoading = false,
  });

  final String action;
  final bool isLoading;
  final FutureOr<void> Function()? onClick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;

    return AnimatedOpacity(
      duration: AppTheme.fast,
      opacity: isLoading ? 0.85 : 1,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: BorderSide(color: error, width: 1.4),
        ),
        child: InkWell(
          onTap: isLoading ? null : onClick,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          highlightColor: error.withValues(alpha: 0.06),
          splashColor: error.withValues(alpha: 0.08),
          child: Container(
            constraints: BoxConstraints(minHeight: min(58, 60)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            alignment: Alignment.center,
            width: double.infinity,
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: error,
                    ),
                  )
                : Text(
                    action,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ).copyWith(color: error),
                  ),
          ),
        ),
      ),
    );
  }
}
