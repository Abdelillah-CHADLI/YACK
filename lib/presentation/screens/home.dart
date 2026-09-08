import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:isar/isar.dart';
import 'package:yack/data/db/models/contract.dart';
import 'package:yack/logic/services/contract/contract_sync_service.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';
import 'package:yack/presentation/widgets/shimmer.dart';
import 'package:yack/presentation/widgets/status_badge.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

enum _AgreementFilter { all, open, completed, disputed }

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final _searchController = TextEditingController();
  Stream<List<Contract>>? _contractsStream;
  Timer? _filterDebounce;
  bool _isRefreshing = false;
  bool _filtering = false;
  String _query = '';
  _AgreementFilter _filter = _AgreementFilter.all;

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await ContractSyncService().syncContracts();
    } catch (error) {
      debugPrint('[ContractsScreen] Error syncing contracts: $error');
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('sync_failed'),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return TranslationHandler.get('good_morning');
    if (hour < 18) return TranslationHandler.get('good_afternoon');
    return TranslationHandler.get('good_evening');
  }

  String _firstName() {
    try {
      final value = Hive.box('user').get('firstName')?.toString().trim() ?? '';
      return value.isEmpty ? '' : value.split(' ').first;
    } catch (_) {
      return '';
    }
  }

  void _createContract() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamed('/contract/create_contract');
  }

  bool _matches(Contract contract) {
    final query = _query.trim().toLowerCase();
    final matchesQuery =
        query.isEmpty ||
        contract.title.toLowerCase().contains(query) ||
        contract.description.toLowerCase().contains(query) ||
        (contract.userAName ?? '').toLowerCase().contains(query) ||
        (contract.userBName ?? '').toLowerCase().contains(query);

    final matchesFilter = switch (_filter) {
      _AgreementFilter.all => true,
      _AgreementFilter.open =>
        contract.status == ContractStatus.active ||
            contract.status == ContractStatus.accepted ||
            contract.status == ContractStatus.pending,
      _AgreementFilter.completed =>
        contract.status == ContractStatus.completed ||
            contract.status == ContractStatus.rejected,
      _AgreementFilter.disputed => contract.status == ContractStatus.disputed,
    };
    return matchesQuery && matchesFilter;
  }

  @override
  Widget build(BuildContext context) {
    final isar = Isar.getInstance();
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const YackBrand(),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(15),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: TranslationHandler.get('refresh'),
              onPressed: _onRefresh,
              icon: const Icon(Icons.sync),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: isWide
          ? null
          : FloatingActionButton.extended(
              onPressed: _createContract,
              icon: const Icon(Icons.add),
              label: Text(TranslationHandler.get('add_contract_short')),
            ),
      body: isar == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Contract>>(
              stream: _contractsStream ??= isar.contracts
                  .where()
                  .watch(fireImmediately: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _ContractsLoadingView();
                }

                final contracts = [...?snapshot.data]
                  ..sort(
                    (a, b) => (b.updatedAt ?? b.createdAt).compareTo(
                      a.updatedAt ?? a.createdAt,
                    ),
                  );
                return _buildContent(context, isar, contracts, isWide);
              },
            ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Isar isar,
    List<Contract> contracts,
    bool isWide,
  ) {
    final hiddenIds =
        (Hive.box('user').get('hiddenContractIds') as List?)
            ?.map((value) => value.toString())
            .toSet() ??
        <String>{};
    final availableContracts = contracts.where((contract) {
      final storageKey = contract.externalId ?? 'local:${contract.id}';
      return !hiddenIds.contains(storageKey);
    }).toList();
    final visible = availableContracts.where(_matches).toList();
    final open = availableContracts.where((contract) {
      return contract.status == ContractStatus.active ||
          contract.status == ContractStatus.accepted ||
          contract.status == ContractStatus.pending;
    }).length;
    final completed = availableContracts.where((contract) {
      return contract.status == ContractStatus.completed ||
          contract.status == ContractStatus.rejected;
    }).length;
    final disputed = availableContracts
        .where((contract) => contract.status == ContractStatus.disputed)
        .length;
    final firstName = _firstName();

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: YackContent(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                8,
                AppTheme.pagePadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  YackPageHeading(
                    eyebrow: firstName.isEmpty
                        ? _greeting()
                        : '${_greeting()}, $firstName',
                    title: TranslationHandler.get('contracts'),
                    subtitle:
                        '${TranslationHandler.get('total_contracts_label')}: ${availableContracts.length}',
                    trailing: isWide
                        ? FilledButton.icon(
                            onPressed: _createContract,
                            icon: const Icon(Icons.add),
                            label: Text(
                              TranslationHandler.get('add_contract_short'),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: TranslationHandler.get('search_contracts'),
                      hintText: TranslationHandler.get('search_contracts'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: TranslationHandler.get('clear'),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(
                          _AgreementFilter.all,
                          TranslationHandler.get('all'),
                          availableContracts.length,
                        ),
                        _filterChip(
                          _AgreementFilter.open,
                          TranslationHandler.get('in_progress'),
                          open,
                        ),
                        _filterChip(
                          _AgreementFilter.completed,
                          TranslationHandler.get('closed'),
                          completed,
                        ),
                        _filterChip(
                          _AgreementFilter.disputed,
                          TranslationHandler.get('status_disputed'),
                          disputed,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (visible.isNotEmpty)
                    YackSectionHeading(
                      title: _sectionTitle(),
                      caption: '${visible.length}',
                    ),
                ],
              ),
            ),
          ),
          if (availableContracts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: YackEmptyState(
                icon: Icons.description_outlined,
                title: TranslationHandler.get('no_contracts'),
                message: TranslationHandler.get('no_contracts_desc'),
              ),
            )
          else
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(_filter),
                  child: _filtering
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 56),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : visible.isEmpty
                          ? YackEmptyState(
                              icon: Icons.search_off_outlined,
                              title: TranslationHandler.get(
                                'no_matching_contracts',
                              ),
                              message: TranslationHandler.get(
                                'no_matching_contracts_desc',
                              ),
                              action: OutlinedButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _query = '';
                                    _filter = _AgreementFilter.all;
                                  });
                                },
                                child: Text(
                                  TranslationHandler.get('clear_filters'),
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppTheme.pagePadding,
                                0,
                                AppTheme.pagePadding,
                                104,
                              ),
                              child: Column(
                                children: [
                                  for (final contract in visible)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: ContractCard(
                                        contract: contract,
                                        isar: isar,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(_AgreementFilter value, String label, int count) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilterChip(
        selected: _filter == value,
        onSelected: (_) {
          if (_filter == value) return;
          setState(() {
            _filter = value;
            _filtering = true;
          });
          _filterDebounce?.cancel();
          _filterDebounce = Timer(const Duration(milliseconds: 220), () {
            if (mounted) setState(() => _filtering = false);
          });
        },
        label: Text('$label  $count'),
        showCheckmark: false,
      ),
    );
  }

  String _sectionTitle() => switch (_filter) {
    _AgreementFilter.all => TranslationHandler.get('all_contracts'),
    _AgreementFilter.open => TranslationHandler.get('in_progress'),
    _AgreementFilter.completed => TranslationHandler.get('closed'),
    _AgreementFilter.disputed => TranslationHandler.get('status_disputed'),
  };
}

class ContractCard extends StatelessWidget {
  final Contract contract;
  final Isar isar;

  const ContractCard({super.key, required this.contract, required this.isar});

  bool get _isClosed =>
      contract.status == ContractStatus.completed ||
      contract.status == ContractStatus.rejected;

  ContractStatus get _displayStatus {
    if ((contract.userAAccepted || contract.userBAccepted) &&
        contract.status == ContractStatus.active) {
      return ContractStatus.pending;
    }
    return contract.status;
  }

  Color _statusColor() => switch (_displayStatus) {
    ContractStatus.active => AppTheme.statusGreen,
    ContractStatus.accepted => AppTheme.statusBlue,
    ContractStatus.pending => AppTheme.statusOrange,
    ContractStatus.disputed => AppTheme.statusRed,
    ContractStatus.completed => AppTheme.statusGreen,
    ContractStatus.rejected => AppTheme.statusGray,
  };

  Future<void> _hideContract(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.visibility_off_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(TranslationHandler.get('hide_agreement_title')),
        content: Text(TranslationHandler.get('hide_agreement_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(TranslationHandler.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(TranslationHandler.get('hide_from_device')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final userBox = Hive.box('user');
      final storageKey = contract.externalId ?? 'local:${contract.id}';
      final hiddenIds =
          (userBox.get('hiddenContractIds') as List?)
              ?.map((value) => value.toString())
              .toSet() ??
          <String>{};
      hiddenIds.add(storageKey);
      await userBox.put('hiddenContractIds', hiddenIds.toList());
      await isar.writeTxn(() => isar.contracts.delete(contract.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TranslationHandler.get('agreement_hidden')),
          action: SnackBarAction(
            label: TranslationHandler.get('undo'),
            onPressed: () async {
              final latest =
                  (userBox.get('hiddenContractIds') as List?)
                      ?.map((value) => value.toString())
                      .toSet() ??
                  <String>{};
              latest.remove(storageKey);
              await userBox.put('hiddenContractIds', latest.toList());
              await isar.writeTxn(() => isar.contracts.put(contract));
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final party = (contract.userBName?.trim().isNotEmpty ?? false)
        ? contract.userBName!
        : (contract.userAName?.trim().isNotEmpty ?? false)
        ? contract.userAName!
        : TranslationHandler.get('unknown');

    return Semantics(
      button: true,
      label:
          '${contract.title}, ${contract.price} '
          '${TranslationHandler.get('currency')}',
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(
            context,
            rootNavigator: true,
          ).pushNamed('/contract/view', arguments: contract.id),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: _statusColor()),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 14, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                contract.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 12),
                            StatusBadge(status: _displayStatus),
                          ],
                        ),
                        if (contract.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            contract.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 7,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _MetaItem(
                              icon: Icons.payments_outlined,
                              text:
                                  '${contract.price} '
                                  '${TranslationHandler.get('currency')}',
                              emphasized: true,
                            ),
                            _MetaItem(icon: Icons.person_outline, text: party),
                            _MetaItem(
                              icon: Icons.calendar_today_outlined,
                              text: _formatDate(contract.createdAt),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isClosed)
                  PopupMenuButton<String>(
                    tooltip: TranslationHandler.get('more_options'),
                    onSelected: (value) {
                      if (value == 'hide') _hideContract(context);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'hide',
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility_off_outlined,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Text(TranslationHandler.get('hide_from_device')),
                          ],
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert),
                  )
                else
                  const Padding(
                    padding: EdgeInsetsDirectional.only(end: 10),
                    child: Icon(Icons.chevron_right),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/${localDate.year}';
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool emphasized;

  const _MetaItem({
    required this.icon,
    required this.text,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasized
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ContractsLoadingView extends StatelessWidget {
  const _ContractsLoadingView();

  @override
  Widget build(BuildContext context) {
    return YackContent(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 80),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(width: 110, height: 14),
            SizedBox(height: 10),
            SkeletonBox(width: 220, height: 30),
            SizedBox(height: 24),
            SkeletonBox(height: 56, radius: AppTheme.radiusMd),
            SizedBox(height: 28),
            ContractCardSkeleton(),
            ContractCardSkeleton(),
            ContractCardSkeleton(),
          ],
        ),
      ),
    );
  }
}
