import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:yack/logic/cubits/auth/auth_cubit.dart';
import 'package:yack/logic/services/auth/account_service.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/logic/utils/encryptionPasswordPopUp.dart';
import 'package:yack/logic/utils/passwordPopUp.dart';
import 'package:yack/presentation/theme/theme.dart';
import 'package:yack/presentation/widgets/secondaryActionButton.dart';
import 'package:yack/presentation/widgets/settingWidgets/appearanceSheet.dart';
import 'package:yack/presentation/widgets/settingWidgets/languageSheet.dart';
import 'package:yack/presentation/widgets/settingWidgets/notificationSheet.dart';
import 'package:yack/presentation/widgets/settingWidgets/privacySheet.dart';
import 'package:yack/presentation/widgets/settingWidgets/sectionHeader.dart';
import 'package:yack/presentation/widgets/settingWidgets/settingsCard.dart';
import 'package:yack/presentation/widgets/settingWidgets/settingsIcon.dart';
import 'package:yack/presentation/widgets/settingWidgets/settingsItem.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loggingOut = false;

  Future<void> _showSheet(Widget sheet) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => sheet,
    );
  }

  String get _themeLabel {
    final stored = Hive.box('user').get('theme');
    return switch (stored) {
      1 => TranslationHandler.get('light'),
      2 => TranslationHandler.get('dark'),
      _ => TranslationHandler.get('system_default'),
    };
  }

  String get _languageLabel => switch (TranslationHandler.currentLanguage) {
    'ar' => TranslationHandler.get('arabic'),
    'fr' => TranslationHandler.get('french'),
    _ => TranslationHandler.get('english'),
  };

  Future<void> _showAboutDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(TranslationHandler.get('about_yack')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const YackBrand(),
              const SizedBox(height: 20),
              Text(
                TranslationHandler.get('about_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(TranslationHandler.get('app_version')),
              const SizedBox(height: 16),
              Text(TranslationHandler.get('about_description')),
              const SizedBox(height: 16),
              Text(
                TranslationHandler.get('app_copyright'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(TranslationHandler.get('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(TranslationHandler.get('logout_confirm_title')),
        content: Text(TranslationHandler.get('logout_confirm_message')),
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
            child: Text(TranslationHandler.get('logout')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {
        // Token cleanup is best effort; it must not trap the user in session.
      }
      await FirebaseAuth.instance.signOut();
      await AccountService().clearCachedData();
      if (!mounted) return;
      context.read<AuthCubit>().markUnauthenticated();
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TranslationHandler.get('logout_failed'))),
      );
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(TranslationHandler.get('settings'))),
      body: SingleChildScrollView(
        child: YackContent(
          maxWidth: 760,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            10,
            AppTheme.pagePadding,
            36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YackPageHeading(
                title: TranslationHandler.get('settings_heading'),
                subtitle: TranslationHandler.get('settings_heading_desc'),
              ),
              const SizedBox(height: 28),
              SectionHeader(
                title: TranslationHandler.get('account_section'),
                color: colors.primary,
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 8),
              SettingsCard(
                children: [
                  SettingsItem(
                    icon: const SettingsIcon(icon: Icons.badge_outlined),
                    title: TranslationHandler.get('profile'),
                    subtitle: TranslationHandler.get('profile_subtitle'),
                    onTap: () => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/profile'),
                  ),
                  Divider(height: 1, color: theme.dividerTheme.color),
                  SettingsItem(
                    icon: const SettingsIcon(
                      icon: Icons.password_outlined,
                      color: AppTheme.statusBlue,
                    ),
                    title: TranslationHandler.get('password'),
                    subtitle: TranslationHandler.get('password_subtitle'),
                    onTap: () => showChangePasswordDialog(context),
                  ),
                  Divider(height: 1, color: theme.dividerTheme.color),
                  SettingsItem(
                    icon: const SettingsIcon(
                      icon: Icons.key_outlined,
                      color: AppTheme.statusGreen,
                    ),
                    title: TranslationHandler.get('encryption_password'),
                    subtitle: TranslationHandler.get(
                      'encryption_password_subtitle',
                    ),
                    onTap: () => showChangeEncryptionPasswordDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              SectionHeader(
                title: TranslationHandler.get('preferences_section'),
                color: colors.primary,
                icon: Icons.tune,
              ),
              const SizedBox(height: 8),
              SettingsCard(
                children: [
                  SettingsItem(
                    icon: const SettingsIcon(
                      icon: Icons.brightness_6_outlined,
                      color: AppTheme.statusBlue,
                    ),
                    title: TranslationHandler.get('appearance'),
                    subtitle: TranslationHandler.get('appearance_subtitle'),
                    value: _themeLabel,
                    onTap: () => _showSheet(const AppearanceSettingsSheet()),
                  ),
                  Divider(height: 1, color: theme.dividerTheme.color),
                  SettingsItem(
                    icon: const SettingsIcon(
                      icon: Icons.language_outlined,
                      color: AppTheme.statusOrange,
                    ),
                    title: TranslationHandler.get('language'),
                    subtitle: TranslationHandler.get('language_subtitle'),
                    value: _languageLabel,
                    onTap: () => _showSheet(const LanguageSettingsSheet()),
                  ),
                  Divider(height: 1, color: theme.dividerTheme.color),
                  SettingsItem(
                    icon: const SettingsIcon(
                      icon: Icons.notifications_outlined,
                    ),
                    title: TranslationHandler.get('notifications'),
                    subtitle: TranslationHandler.get(
                      'notifications_info_subtitle',
                    ),
                    value: TranslationHandler.get('info'),
                    onTap: () => _showSheet(const NotificationSettingsSheet()),
                  ),
                  Divider(height: 1, color: theme.dividerTheme.color),
                  SettingsItem(
                    icon: const SettingsIcon(
                      icon: Icons.shield_outlined,
                      color: AppTheme.statusGreen,
                    ),
                    title: TranslationHandler.get('privacy'),
                    subtitle: TranslationHandler.get('privacy_info_subtitle'),
                    value: TranslationHandler.get('info'),
                    onTap: () => _showSheet(const PrivacySettingsSheet()),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              SectionHeader(
                title: TranslationHandler.get('plans_support_section'),
                color: colors.primary,
                icon: Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 8),
              SettingsCard(
                children: [
                  SettingsItem(
                    icon: const SettingsIcon(
                      icon: Icons.workspace_premium_outlined,
                      color: AppTheme.statusOrange,
                    ),
                    title: TranslationHandler.get('plans_preview'),
                    subtitle: TranslationHandler.get('plans_preview_subtitle'),
                    onTap: () => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamed('/subscription'),
                  ),
                  Divider(height: 1, color: theme.dividerTheme.color),
                  SettingsItem(
                    icon: const SettingsIcon(
                      icon: Icons.help_outline,
                      color: AppTheme.statusBlue,
                    ),
                    title: TranslationHandler.get('help_support'),
                    subtitle: TranslationHandler.get(
                      'help_unavailable_subtitle',
                    ),
                    value: TranslationHandler.get('unavailable'),
                    enabled: false,
                  ),
                  Divider(height: 1, color: theme.dividerTheme.color),
                  SettingsItem(
                    icon: const SettingsIcon(
                      icon: Icons.info_outline,
                      color: AppTheme.statusGray,
                    ),
                    title: TranslationHandler.get('about_yack'),
                    subtitle: TranslationHandler.get('about_subtitle'),
                    onTap: _showAboutDialog,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              YackNotice(
                message: TranslationHandler.get('logout_device_note'),
                tone: YackNoticeTone.neutral,
                icon: Icons.phonelink_erase_outlined,
              ),
              const SizedBox(height: 16),
              SecondaryActionButton(
                action: TranslationHandler.get('logout'),
                isLoading: _loggingOut,
                destructive: true,
                icon: Icons.logout,
                onClick: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
