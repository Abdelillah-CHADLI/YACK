import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:yack/data/db/models/contract.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';

class ContractStatusSummary extends StatelessWidget {
  const ContractStatusSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final database = Isar.getInstance();
    if (database == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<Contract>>(
      stream: database.contracts.where().watch(fireImmediately: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final contracts = snapshot.data ?? const <Contract>[];
        final inProgress = contracts.where((contract) {
          return contract.status == ContractStatus.pending ||
              contract.status == ContractStatus.active ||
              contract.status == ContractStatus.accepted;
        }).length;
        final closed = contracts.where((contract) {
          return contract.status == ContractStatus.completed ||
              contract.status == ContractStatus.rejected;
        }).length;
        final disputed = contracts
            .where((contract) => contract.status == ContractStatus.disputed)
            .length;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              _SummaryRow(
                icon: Icons.pending_actions_outlined,
                label: TranslationHandler.get('in_progress'),
                count: inProgress,
                color: AppTheme.statusOrange,
              ),
              const Divider(),
              _SummaryRow(
                icon: Icons.task_alt_outlined,
                label: TranslationHandler.get('closed'),
                count: closed,
                color: AppTheme.statusGreen,
              ),
              const Divider(),
              _SummaryRow(
                icon: Icons.report_problem_outlined,
                label: TranslationHandler.get('status_disputed'),
                count: disputed,
                color: AppTheme.statusRed,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
          Text(
            '$count',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
