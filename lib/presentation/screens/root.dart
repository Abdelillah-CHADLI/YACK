import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:yack/presentation/screens/home.dart';
import 'package:yack/presentation/screens/notifications.dart';
import 'package:yack/presentation/screens/scan_contract.dart';
import 'package:yack/presentation/screens/settings.dart';
import 'package:yack/presentation/theme/theme.dart';



class BottomNavBar extends StatefulWidget {
  final int initialIndex;
  const BottomNavBar({super.key, this.initialIndex = 0});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  late PersistentTabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PersistentTabController(initialIndex: widget.initialIndex);
  }

  List<Widget> _buildScreens() {
    final screens = [
      const ContractsScreen(),
      const ScanContractScreen(),
      const NotificationsPage(), // removed hardcoded notifications: Chadli
      const SettingsScreen(),
    ];

    return screens;
  }

  List<PersistentBottomNavBarItem> _navBarsItems(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final items = [
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.home_outlined),
        activeColorPrimary: colorScheme.primary,
        inactiveColorPrimary: colorScheme.onSurfaceVariant,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.qr_code_scanner),
        activeColorPrimary: AppTheme.yackGreen,
        inactiveColorPrimary: colorScheme.onSurfaceVariant,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.notifications_outlined),
        activeColorPrimary: colorScheme.primary,
        inactiveColorPrimary: colorScheme.onSurfaceVariant,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.settings_outlined),
        activeColorPrimary: colorScheme.primary,
        inactiveColorPrimary: colorScheme.onSurfaceVariant,
      ),
    ];

    return items;
  }

  @override
  Widget build(BuildContext context) {
        return Scaffold(
          body: PersistentTabView(
            context,
            neumorphicProperties: NeumorphicProperties(showSubtitleText: false),
            controller: _controller,
            screens: _buildScreens(),
            items: _navBarsItems(context),
            navBarStyle: NavBarStyle.style3, // change style here
            backgroundColor: Theme.of(context).colorScheme.surface,
            decoration: NavBarDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(0),
              ),
              colorBehindNavBar: Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            resizeToAvoidBottomInset: true,
            hideNavigationBarWhenKeyboardAppears: true,
            popBehaviorOnSelectedNavBarItemPress: PopBehavior.once,
          ),
        );
  }
}
