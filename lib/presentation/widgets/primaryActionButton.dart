import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:yack/presentation/theme/theme.dart';

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({super.key, required this.action, this.onClick,  this.isLoading = false});

  final String action;
  final bool isLoading;
  final FutureOr<void> Function()? onClick;



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedOpacity(
      duration: AppTheme.fast,
      opacity: isLoading ? 0.85 : 1,
      child: Material(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        elevation: 0,
        child: InkWell(
          onTap: isLoading ? null : onClick,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          splashColor: Colors.white24,
          highlightColor: Colors.white12,
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
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          action,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimary,
                          ),
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