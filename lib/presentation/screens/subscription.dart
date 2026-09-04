import 'package:flutter/material.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

/// Product-plan information only. Billing is intentionally not simulated:
/// there is no purchase backend in the current application.
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.close),
        ),
        title: Text(TranslationHandler.get('plans_preview')),
      ),
      body: SingleChildScrollView(
        child: YackContent(
          maxWidth: 720,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            12,
            AppTheme.pagePadding,
            36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YackPageHeading(
                eyebrow: TranslationHandler.get('subscription'),
                title: TranslationHandler.get('plans_title'),
                subtitle: TranslationHandler.get('plans_title_desc'),
              ),
              const SizedBox(height: 24),
              YackNotice(
                message: TranslationHandler.get('billing_unavailable_note'),
                tone: YackNoticeTone.warning,
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 28),
              YackSectionHeading(
                title: TranslationHandler.get('available_now'),
                caption: TranslationHandler.get('available_now_desc'),
              ),
              _PlanRow(
                icon: Icons.description_outlined,
                title: TranslationHandler.get('current_access'),
                description: TranslationHandler.get('current_access_desc'),
                status: TranslationHandler.get('included'),
                statusColor: AppTheme.statusGreen,
              ),
              const SizedBox(height: 10),
              _PlanRow(
                icon: Icons.lock_outline,
                title: TranslationHandler.get('device_encryption'),
                description: TranslationHandler.get('device_encryption_desc'),
                status: TranslationHandler.get('included'),
                statusColor: AppTheme.statusGreen,
              ),
              const SizedBox(height: 28),
              YackSectionHeading(
                title: TranslationHandler.get('planned_options'),
                caption: TranslationHandler.get('planned_options_desc'),
              ),
              _PlanRow(
                icon: Icons.workspace_premium_outlined,
                title: TranslationHandler.get('paid_plans'),
                description: TranslationHandler.get('paid_plans_desc'),
                status: TranslationHandler.get('not_available_yet'),
                statusColor: colors.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              _PlanRow(
                icon: Icons.payments_outlined,
                title: TranslationHandler.get('in_app_billing'),
                description: TranslationHandler.get('in_app_billing_desc'),
                status: TranslationHandler.get('not_available_yet'),
                statusColor: colors.onSurfaceVariant,
              ),
              const SizedBox(height: 28),
              Text(
                TranslationHandler.get('plans_no_purchase_disclaimer'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: Text(TranslationHandler.get('done')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String status;
  final Color statusColor;

  const _PlanRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, size: 21, color: colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleSmall),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
