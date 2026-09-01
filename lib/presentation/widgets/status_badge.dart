import 'package:flutter/material.dart';
import 'package:yack/data/db/models/contract.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';

/// Consistent status badge with icon, color and label used across the app.
class StatusBadge extends StatelessWidget {
  final ContractStatus status;
  final bool compact;

  const StatusBadge({super.key, required this.status, this.compact = false});

  Color get _color {
    switch (status) {
      case ContractStatus.active:
      case ContractStatus.accepted:
        return AppTheme.statusGreen;
      case ContractStatus.pending:
        return AppTheme.statusOrange;
      case ContractStatus.disputed:
        return AppTheme.statusRed;
      case ContractStatus.completed:
        return AppTheme.statusBlue;
      case ContractStatus.rejected:
        return AppTheme.statusGray;
    }
  }

  IconData get _icon {
    switch (status) {
      case ContractStatus.active:
      case ContractStatus.accepted:
        return Icons.check_circle_outline;
      case ContractStatus.pending:
        return Icons.schedule_outlined;
      case ContractStatus.disputed:
        return Icons.gavel_outlined;
      case ContractStatus.completed:
        return Icons.task_alt_outlined;
      case ContractStatus.rejected:
        return Icons.cancel_outlined;
    }
  }

  String get _label {
    switch (status) {
      case ContractStatus.active:
      case ContractStatus.accepted:
        return TranslationHandler.get('status_active');
      case ContractStatus.pending:
        return TranslationHandler.get('status_pending');
      case ContractStatus.disputed:
        return TranslationHandler.get('status_disputed');
      case ContractStatus.completed:
        return TranslationHandler.get('status_completed');
      case ContractStatus.rejected:
        return TranslationHandler.get('status_rejected');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: compact ? 12 : 14, color: color),
          if (!compact) ...[
            const SizedBox(width: 5),
            Text(
              _label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
