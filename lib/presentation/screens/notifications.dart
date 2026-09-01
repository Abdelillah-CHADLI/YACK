import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:yack/main.dart';
import 'package:yack/data/db/models/notification.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // Selection state
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<AppNotification> notifications) {
    setState(() {
      _selectedIds.clear();
      _selectedIds.addAll(notifications.map((n) => n.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    await isar.writeTxn(() async {
      await isar.appNotifications.deleteAll(_selectedIds.toList());
    });
    _clearSelection();
  }

  Future<void> _markSelectedAsRead() async {
    await isar.writeTxn(() async {
      for (final id in _selectedIds) {
        final notification = await isar.appNotifications.get(id);
        if (notification != null) {
          notification.isRead = true;
          await isar.appNotifications.put(notification);
        }
      }
    });
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '${_selectedIds.length} ${TranslationHandler.get('selected')}'
              : TranslationHandler.get('notifications_title'),
          style: theme.textTheme.titleMedium,
        ),
        backgroundColor: Colors.transparent,
        actions: _selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: _markSelectedAsRead,
                  tooltip: TranslationHandler.get('mark_as_read'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deleteSelected,
                  tooltip: TranslationHandler.get('delete'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                  tooltip: TranslationHandler.get('cancel'),
                ),
              ]
            : null,
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: isar.appNotifications.where().sortByCreatedAtDesc().watch(
          fireImmediately: true,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!;

          if (notifications.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              // Select All button when in selection mode
              if (_selectionMode)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _selectAll(notifications),
                        icon: const Icon(Icons.select_all, size: 18),
                        label: Text(TranslationHandler.get('select_all')),
                      ),
                    ],
                  ),
                ),
              // Notifications list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final isSelected = _selectedIds.contains(n.id);

                    return GestureDetector(
                      onLongPress: () {
                        setState(() {
                          _selectionMode = true;
                          _selectedIds.add(n.id);
                        });
                      },
                      onTap: () {
                        if (_selectionMode) {
                          _toggleSelection(n.id);
                        } else {
                          // navigate to contract or mark as read
                          _markAsRead(n);
                        }
                      },
                      child: AnimatedContainer(
                        duration: AppTheme.normal,
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.primaryContainer
                              : color.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          border: Border.all(
                            color: isSelected
                                ? color.primary
                                : color.outlineVariant.withValues(alpha: 0.6),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected ? null : AppTheme.cardShadow,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: n.isRead
                                    ? color.surfaceContainerHighest
                                    : color.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : n.isRead
                                        ? Icons.notifications_none
                                        : Icons.notifications_active,
                                size: 20,
                                color: isSelected
                                    ? color.primary
                                    : n.isRead
                                        ? color.onSurfaceVariant
                                        : color.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: n.isRead
                                                ? FontWeight.w600
                                                : FontWeight.w700,
                                            color: color.onSurface,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(n.createdAt),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: color.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.body,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: color.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (!notification.isRead) {
      await isar.writeTxn(() async {
        notification.isRead = true;
        await isar.appNotifications.put(notification);
      });
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: color.primary.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: color.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            TranslationHandler.get('no_notifications'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              TranslationHandler.get('no_notifications_desc'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
