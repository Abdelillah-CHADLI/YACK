import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:yack/data/db/models/notification.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/screens/home.dart';
import 'package:yack/presentation/screens/notifications.dart';
import 'package:yack/presentation/screens/scan_contract.dart';
import 'package:yack/presentation/screens/settings.dart';

/// Adaptive top-level application shell.
///
/// Phones use a labeled navigation bar; wider layouts use a navigation rail.
/// IndexedStack intentionally preserves each destination's scroll and form state.
class BottomNavBar extends StatefulWidget {
  final int initialIndex;

  const BottomNavBar({super.key, this.initialIndex = 0});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  late int _selectedIndex;

  static const _screens = <Widget>[
    ContractsScreen(),
    ScanContractScreen(),
    NotificationsPage(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _screens.length - 1);
  }

  void _select(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  List<_DestinationData> _destinations() => [
    _DestinationData(
      label: TranslationHandler.get('contracts'),
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
    ),
    _DestinationData(
      label: TranslationHandler.get('scan'),
      icon: Icons.qr_code_scanner_outlined,
      selectedIcon: Icons.qr_code_scanner,
    ),
    _DestinationData(
      label: TranslationHandler.get('activity_title'),
      icon: Icons.notifications_none_outlined,
      selectedIcon: Icons.notifications,
      badge: true,
    ),
    _DestinationData(
      label: TranslationHandler.get('settings'),
      icon: Icons.manage_accounts_outlined,
      selectedIcon: Icons.manage_accounts,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations();
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final content = IndexedStack(index: _selectedIndex, children: _screens);

    if (isWide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: BorderDirectional(
                    end: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.75,
                  destinations: destinations
                      .map(
                        (item) => NavigationRailDestination(
                          icon: _DestinationIcon(data: item, selected: false),
                          selectedIcon: _DestinationIcon(
                            data: item,
                            selected: true,
                          ),
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _select,
          destinations: destinations
              .map(
                (item) => NavigationDestination(
                  icon: _DestinationIcon(data: item, selected: false),
                  selectedIcon: _DestinationIcon(data: item, selected: true),
                  label: item.label,
                  tooltip: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _DestinationData {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool badge;

  const _DestinationData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badge = false,
  });
}

class _DestinationIcon extends StatelessWidget {
  final _DestinationData data;
  final bool selected;

  const _DestinationIcon({required this.data, required this.selected});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(selected ? data.selectedIcon : data.icon);
    if (!data.badge) return icon;

    final isar = Isar.getInstance();
    if (isar == null) return icon;

    return StreamBuilder<List<AppNotification>>(
      stream: isar.appNotifications.where().watch(fireImmediately: true),
      builder: (context, snapshot) {
        final unread = (snapshot.data ?? const <AppNotification>[])
            .where((notification) => !notification.isRead)
            .length;
        return Badge.count(
          count: unread,
          isLabelVisible: unread > 0,
          child: icon,
        );
      },
    );
  }
}
