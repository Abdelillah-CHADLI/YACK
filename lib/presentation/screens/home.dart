import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:isar/isar.dart';
import 'package:yack/presentation/screens/create_contract.dart';
import 'package:yack/presentation/theme/theme.dart';
import 'package:yack/data/db/models/contract.dart';
import 'package:yack/logic/services/contract/contract_sync_service.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/widgets/status_badge.dart';
import 'package:yack/presentation/widgets/metric_card.dart';
import 'package:yack/presentation/widgets/shimmer.dart';
import 'package:yack/presentation/widgets/settingWidgets/sectionHeader.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  bool _isRefreshing = false;

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final syncService = ContractSyncService();
      await syncService.syncContracts();
    } catch (e) {
      print('[ContractsScreen] Error syncing contracts: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _buildGreeting() {
    final now = DateTime.now().hour;
    if (now < 12) return TranslationHandler.get('good_morning');
    if (now < 18) return TranslationHandler.get('good_afternoon');
    return TranslationHandler.get('good_evening');
  }

  String _userFirstName() {
    try {
      final box = Hive.box('user');
      final first = box.get('firstName')?.toString() ?? '';
      if (first.trim().isNotEmpty) return first.trim().split(' ').first;
    } catch (_) {}
    return '';
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final translate = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: color.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      size: 56,
                      color: color.primary.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    TranslationHandler.get('no_contracts'),
                    style: translate.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      TranslationHandler.get('no_contracts_desc'),
                      textAlign: TextAlign.center,
                      style: translate.bodyMedium?.copyWith(
                        color: color.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateContractScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: Text(TranslationHandler.get('add_contract')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isar = Isar.getInstance();

    if (isar == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppTheme.yackGreen,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              TranslationHandler.get('app_name'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: StreamBuilder<List<Contract>>(
                  stream: isar.contracts.where().watch(fireImmediately: true),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildSkeletonList();
                    }

                    final data = snapshot.data;

                    if (data == null || data.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: _buildEmptyState(context),
                      );
                    }

                    final activeContracts = data
                        .where(
                          (c) =>
                              c.status == ContractStatus.active ||
                              c.status == ContractStatus.accepted ||
                              c.status == ContractStatus.pending ||
                              c.status == ContractStatus.disputed,
                        )
                        .toList();
                    final pastContracts = data
                        .where(
                          (c) =>
                              c.status == ContractStatus.completed ||
                              c.status == ContractStatus.rejected,
                        )
                        .toList();

                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        children: [
                          _buildDashboardHeader(context, data),
                          const SizedBox(height: 20),
                          _buildMetrics(context, data),
                          const SizedBox(height: 28),
                          if (activeContracts.isNotEmpty) ...[
                            SectionHeader(
                              title: TranslationHandler.get('active_section'),
                              color: Theme.of(context).colorScheme.primary,
                              icon: Icons.bolt_outlined,
                            ),
                            const SizedBox(height: 8),
                          ],
                          ...activeContracts.map(
                            (c) => ContractCard(contract: c, isar: isar),
                          ),
                          if (activeContracts.isNotEmpty &&
                              pastContracts.isNotEmpty)
                            const SizedBox(height: 24),
                          if (pastContracts.isNotEmpty) ...[
                            SectionHeader(
                              title: TranslationHandler.get('past_section'),
                              color: Theme.of(context).colorScheme.primary,
                              icon: Icons.history,
                            ),
                            const SizedBox(height: 8),
                          ],
                          ...pastContracts.map(
                            (c) => ContractCard(contract: c, isar: isar),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(18),
            alignment: TranslationHandler.isRTL
                ? Alignment.bottomLeft
                : Alignment.bottomRight,
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateContractScreen(),
                  ),
                );
              },
              backgroundColor: AppTheme.yackGreen,
              foregroundColor: AppTheme.yackWhite,
              icon: const Icon(Icons.add),
              label: Text(TranslationHandler.get('add_contract_short')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader(BuildContext context, List<Contract> data) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final firstName = _userFirstName();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _buildGreeting(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    firstName.isNotEmpty
                        ? firstName
                        : TranslationHandler.get('contracts'),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            // Secure badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: color.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: color.primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    TranslationHandler.get('encrypted_label'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${TranslationHandler.get('total_contracts_label')}: ${data.length}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMetrics(BuildContext context, List<Contract> data) {
    final active = data
        .where(
          (c) =>
              c.status == ContractStatus.active ||
              c.status == ContractStatus.accepted ||
              c.status == ContractStatus.pending ||
              c.status == ContractStatus.disputed,
        )
        .length;
    final pending = data
        .where((c) => c.status == ContractStatus.pending)
        .length;
    final completed = data
        .where((c) => c.status == ContractStatus.completed)
        .length;

    final metrics = [
      MetricCard(
        icon: Icons.description_outlined,
        color: AppTheme.yackGreen,
        label: TranslationHandler.get('total_contracts_label'),
        value: '${data.length}',
      ),
      MetricCard(
        icon: Icons.bolt_outlined,
        color: AppTheme.statusBlue,
        label: TranslationHandler.get('active_contracts_label'),
        value: '$active',
      ),
      MetricCard(
        icon: Icons.schedule_outlined,
        color: AppTheme.statusOrange,
        label: TranslationHandler.get('pending_signatures_label'),
        value: '$pending',
      ),
      MetricCard(
        icon: Icons.task_alt_outlined,
        color: AppTheme.statusGreen,
        label: TranslationHandler.get('completed_label'),
        value: '$completed',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive: 2x2 grid on phones, 4-in-a-row on wide screens
        final columns = constraints.maxWidth >= 560 ? 4 : 2;

        if (columns == 4) {
          return Row(
            children: metrics
                .map(
                  (m) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: m,
                    ),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  metrics[0],
                  const SizedBox(height: 12),
                  metrics[2],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  metrics[1],
                  const SizedBox(height: 12),
                  metrics[3],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeletonList() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: const [
          ContractCardSkeleton(),
          ContractCardSkeleton(),
          ContractCardSkeleton(),
          ContractCardSkeleton(),
        ],
      ),
    );
  }
}

class ContractCard extends StatelessWidget {
  final Contract contract;
  final Isar isar;

  const ContractCard({super.key, required this.contract, required this.isar});

  Future<void> _deleteContract(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(TranslationHandler.get('dialog_delete_contract_title')),
        content:
            Text(TranslationHandler.get('dialog_delete_contract_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(TranslationHandler.get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child:
                Text(TranslationHandler.get('dialog_delete_contract_confirm')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await isar.writeTxn(() async {
        await isar.contracts.delete(contract.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    if ((contract.userAAccepted || contract.userBAccepted) &&
        contract.status == ContractStatus.active) {
      contract.status = ContractStatus.pending;
    }

    final isPast =
        contract.status == ContractStatus.completed ||
        contract.status == ContractStatus.rejected;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppTheme.normal,
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        );
      },
      child: Semantics(
        button: true,
        label: contract.title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/contract/view', arguments: contract.id);
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            splashColor: color.primary.withValues(alpha: 0.05),
            highlightColor: color.primary.withValues(alpha: 0.03),
            child: AnimatedContainer(
              duration: AppTheme.fast,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: color.outlineVariant.withValues(alpha: 0.6),
                ),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: icon, title, status badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isPast
                              ? Icons.folder_open_outlined
                              : Icons.description_outlined,
                          color: color.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contract.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.currency_exchange,
                                  size: 13,
                                  color: color.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${contract.price} ${TranslationHandler.get('currency')}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: color.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(status: contract.status),
                    ],
                  ),
                  if (contract.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      contract.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Metadata row
                  Row(
                    children: [
                      if (contract.userAName != null ||
                          contract.userBName != null) ...[
                        Expanded(
                          child: _MetaItem(
                            icon: Icons.person_outline,
                            text:
                                contract.userAName ?? contract.userBName ?? '',
                            color: color.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: _MetaItem(
                          icon: Icons.calendar_today_outlined,
                          text: _formatDate(contract.createdAt),
                          color: color.onSurfaceVariant,
                        ),
                      ),
                      if (isPast)
                        TextButton.icon(
                          onPressed: () => _deleteContract(context),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: AppTheme.statusRed,
                          ),
                          label: Text(
                            TranslationHandler.get('delete'),
                            style: const TextStyle(
                              color: AppTheme.statusRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MetaItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color.withValues(alpha: 0.85),
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
