import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:yack/data/db/models/notification.dart';
import 'package:yack/logic/services/notification/notification_router_service.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/main.dart';
import 'package:yack/presentation/theme/theme.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  void _startSelection([int? id]) {
    setState(() {
      _selectionMode = true;
      if (id != null) _selectedIds.add(id);
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _markAllAsRead() async {
    final unread = await isar.appNotifications
        .filter()
        .isReadEqualTo(false)
        .findAll();
    if (unread.isEmpty) return;
    await isar.writeTxn(() async {
      for (final notification in unread) {
        notification.isRead = true;
        await isar.appNotifications.put(notification);
      }
    });
  }

  Future<void> _markSelectedAsRead() async {
    if (_selectedIds.isEmpty) return;
    await isar.writeTxn(() async {
      for (final id in _selectedIds) {
        final notification = await isar.appNotifications.get(id);
        if (notification == null) continue;
        notification.isRead = true;
        await isar.appNotifications.put(notification);
      }
    });
    _clearSelection();
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(TranslationHandler.get('delete_activity_title')),
        content: Text(
          TranslationHandler.resolve(
            'delete_activity_message',
            params: {'count': '$count'},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(TranslationHandler.get('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(TranslationHandler.get('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await isar.writeTxn(() async {
      await isar.appNotifications.deleteAll(_selectedIds.toList());
    });
    if (!mounted) return;
    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          TranslationHandler.resolve(
            'activity_deleted',
            params: {'count': '$count'},
          ),
        ),
      ),
    );
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (!notification.isRead) {
      await isar.writeTxn(() async {
        notification.isRead = true;
        await isar.appNotifications.put(notification);
      });
    }
    if (!mounted) return;

    final contractId = notification.contractId;
    if (contractId != null && contractId.isNotEmpty) {
      final opened = notification.type == NotificationType.supportMessage
          ? await NotificationRouterService.navigateToSupport(contractId)
          : await NotificationRouterService.navigateToContract(contractId);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TranslationHandler.get('contract_unavailable')),
          ),
        );
      }
      return;
    }

    if (notification.tempId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TranslationHandler.get('invite_activity_hint'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<AppNotification>>(
      stream: isar.appNotifications.where().sortByCreatedAtDesc().watch(
        fireImmediately: true,
      ),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <AppNotification>[];
        final unreadCount = notifications
            .where((notification) => !notification.isRead)
            .length;

        return Scaffold(
          appBar: AppBar(
            leading: _selectionMode
                ? IconButton(
                    tooltip: TranslationHandler.get('cancel'),
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.close),
                  )
                : null,
            title: Text(
              _selectionMode
                  ? TranslationHandler.resolve(
                      'selected_count',
                      params: {'count': '${_selectedIds.length}'},
                    )
                  : TranslationHandler.get('activity_title'),
            ),
            actions: [
              if (_selectionMode)
                TextButton(
                  onPressed: () => setState(() {
                    _selectedIds
                      ..clear()
                      ..addAll(notifications.map((item) => item.id));
                  }),
                  child: Text(TranslationHandler.get('select_all')),
                )
              else ...[
                if (unreadCount > 0)
                  IconButton(
                    tooltip: TranslationHandler.get('mark_all_as_read'),
                    onPressed: _markAllAsRead,
                    icon: const Icon(Icons.done_all),
                  ),
                if (notifications.isNotEmpty)
                  IconButton(
                    tooltip: TranslationHandler.get('select'),
                    onPressed: _startSelection,
                    icon: const Icon(Icons.checklist_outlined),
                  ),
              ],
              const SizedBox(width: 4),
            ],
          ),
          body:
              snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : notifications.isEmpty
              ? YackEmptyState(
                  icon: Icons.notifications_none_outlined,
                  title: TranslationHandler.get('no_notifications'),
                  message: TranslationHandler.get('no_notifications_desc'),
                )
              : YackContent(
                  maxWidth: 820,
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    8,
                    AppTheme.pagePadding,
                    28,
                  ),
                  child: ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final previous = index == 0
                          ? null
                          : notifications[index - 1];
                      final group = _groupLabel(notification.createdAt);
                      final startsGroup =
                          previous == null ||
                          _groupLabel(previous.createdAt) != group;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (startsGroup)
                            Padding(
                              padding: EdgeInsets.only(
                                top: index == 0 ? 10 : 26,
                                bottom: 8,
                              ),
                              child: Text(
                                group,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          _ActivityRow(
                            notification: notification,
                            selected: _selectedIds.contains(notification.id),
                            selectionMode: _selectionMode,
                            onTap: () {
                              if (_selectionMode) {
                                _toggleSelection(notification.id);
                              } else {
                                _openNotification(notification);
                              }
                            },
                            onLongPress: () => _startSelection(notification.id),
                          ),
                        ],
                      );
                    },
                  ),
                ),
          bottomNavigationBar: !_selectionMode
              ? null
              : SafeArea(
                  top: false,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _selectedIds.isEmpty
                                  ? null
                                  : _markSelectedAsRead,
                              icon: const Icon(Icons.done_all),
                              label: Text(
                                TranslationHandler.get('mark_as_read'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                                foregroundColor: theme.colorScheme.onError,
                              ),
                              onPressed: _selectedIds.isEmpty
                                  ? null
                                  : _confirmDeleteSelected,
                              icon: const Icon(Icons.delete_outline),
                              label: Text(TranslationHandler.get('delete')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  String _groupLabel(DateTime value) {
    final date = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return TranslationHandler.get('today');
    if (difference == 1) return TranslationHandler.get('yesterday');
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _ActivityRow extends StatelessWidget {
  final AppNotification notification;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ActivityRow({
    required this.notification,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final localTime = notification.createdAt.toLocal();
    final time =
        '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}';
    final canOpen = notification.contractId?.isNotEmpty == true;

    return Semantics(
      button: true,
      selected: selected,
      readOnly: notification.isRead,
      child: Material(
        color: selected
            ? colors.primaryContainer
            : notification.isRead
            ? colors.surface
            : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectionMode)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: Checkbox(value: selected, onChanged: (_) => onTap()),
                  )
                else
                  Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsetsDirectional.only(end: 12),
                    decoration: BoxDecoration(
                      color: _toneColor(colors).withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(_icon, size: 20, color: _toneColor(colors)),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: notification.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(time, style: theme.textTheme.labelSmall),
                        ],
                      ),
                      if (notification.body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!selectionMode && !notification.isRead)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsetsDirectional.only(start: 10, top: 7),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else if (!selectionMode && canOpen)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8, top: 2),
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData get _icon => switch (notification.type) {
    NotificationType.contractJoin => Icons.person_add_alt_1_outlined,
    NotificationType.contractSign => Icons.draw_outlined,
    NotificationType.contractAccept => Icons.task_alt_outlined,
    NotificationType.contractDispute => Icons.report_problem_outlined,
    NotificationType.contractMessage => Icons.chat_bubble_outline,
    NotificationType.contractMedia => Icons.attach_file,
    NotificationType.supportMessage => Icons.support_agent_outlined,
    NotificationType.disputeResolved => Icons.gavel_outlined,
    NotificationType.unknown => Icons.notifications_none_outlined,
  };

  Color _toneColor(ColorScheme colors) => switch (notification.type) {
    NotificationType.contractDispute => colors.error,
    NotificationType.contractAccept => AppTheme.statusGreen,
    NotificationType.disputeResolved => AppTheme.statusGreen,
    NotificationType.contractJoin ||
    NotificationType.contractSign => colors.secondary,
    _ => colors.primary,
  };
}
