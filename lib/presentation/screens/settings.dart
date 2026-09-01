import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yack/logic/utils/passwordPopUp.dart';
import 'package:yack/logic/utils/encryptionPasswordPopUp.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/logic/services/auth/account_service.dart';
import 'package:yack/presentation/widgets/secondaryActionButtonAutoLoading.dart';
import 'package:yack/logic/cubits/auth/auth_cubit.dart';
import 'package:yack/presentation/widgets/settingWidgets/appearanceSheet.dart';
import 'package:yack/presentation/widgets/settingWidgets/languageSheet.dart';
import 'package:yack/presentation/widgets/settingWidgets/notificationSheet.dart';
import 'package:yack/presentation/widgets/settingWidgets/privacySheet.dart';
import 'package:yack/presentation/widgets/settingWidgets/sectionHeader.dart';
import 'package:yack/presentation/widgets/settingWidgets/settingsCard.dart';
import 'package:yack/presentation/widgets/settingWidgets/settingsItem.dart';
import 'package:yack/presentation/widgets/settingWidgets/settingsIcon.dart';
import 'package:yack/presentation/theme/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const NotificationSettingsSheet(),
    );
  }

  void _showPrivacySettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const PrivacySettingsSheet(),
    );
  }

  void _showAppearanceSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AppearanceSettingsSheet(),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(TranslationHandler.get('about_yack')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(TranslationHandler.get('about_title')),
            SizedBox(height: 16),
            Text(TranslationHandler.get('app_version')),
            SizedBox(height: 8),
            Text(TranslationHandler.get('app_copyright')),
            SizedBox(height: 16),
            Text(
              TranslationHandler.get('about_description'),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(TranslationHandler.get('close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(TranslationHandler.get('settings'),
            style: theme.textTheme.titleMedium),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: TranslationHandler.get('account_section'),
                    color: color.primary,
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 8),
                  SettingsCard(
                    children: [
                      SettingsItem(
                        icon: const SettingsIcon(
                          icon: Icons.person_outline,
                        ),
                        title: TranslationHandler.get('profile'),
                        subtitle: TranslationHandler.get('profile_subtitle'),
                        onTap: () {
                          Navigator.of(context, rootNavigator: true)
                              .pushNamed('/profile');
                        },
                      ),
                      Divider(height: 1, color: theme.dividerTheme.color),
                      SettingsItem(
                        icon: const SettingsIcon(
                          icon: Icons.key_outlined,
                          color: AppTheme.statusBlue,
                        ),
                        title: TranslationHandler.get('password'),
                        subtitle: TranslationHandler.get('password_subtitle'),
                        onTap: () {
                          showChangePasswordDialog(context);
                        },
                      ),
                      Divider(height: 1, color: theme.dividerTheme.color),
                      SettingsItem(
                        icon: const SettingsIcon(
                          icon: Icons.shield_outlined,
                          color: AppTheme.statusGreen,
                        ),
                        title: TranslationHandler.get('encryption_password'),
                        subtitle: TranslationHandler.get('encryption_password_subtitle'),
                        onTap: () {
                          showChangeEncryptionPasswordDialog(context);
                        },
                      ),
                      Divider(height: 1, color: theme.dividerTheme.color),
                      SettingsItem(
                        icon: const SettingsIcon(
                          icon: Icons.rocket_launch_outlined,
                          color: AppTheme.statusOrange,
                        ),
                        title: TranslationHandler.get('upgrade'),
                        subtitle: TranslationHandler.get('upgrade_subtitle'),
                        onTap: () {
                          Navigator.of(context, rootNavigator: true)
                              .pushNamed('/upgrade');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: TranslationHandler.get('preferences_section'),
                    color: color.primary,
                    icon: Icons.tune,
                  ),
                  const SizedBox(height: 8),
                  SettingsCard(
                    children: [
                      SettingsItem(
                        icon: const SettingsIcon(
                          icon: Icons.notifications_outlined,
                        ),
                        title: TranslationHandler.get('notifications'),
                        subtitle: TranslationHandler.get('notifications_subtitle'),
                        onTap: () => _showNotificationSettings(context),
                      ),
                      Divider(height: 1, color: theme.dividerTheme.color),
                      SettingsItem(
                        icon: const SettingsIcon(
                          icon: Icons.shield_outlined,
                          color: AppTheme.statusGreen,
                        ),
                        title: TranslationHandler.get('privacy'),
                        subtitle: TranslationHandler.get('privacy_subtitle'),
                        onTap: () => _showPrivacySettings(context),
                      ),
                      Divider(height: 1, color: theme.dividerTheme.color),
                      SettingsItem(
                        icon: const SettingsIcon(
                          icon: Icons.brightness_6_outlined,
                          color: AppTheme.statusBlue,
                        ),
                        title: TranslationHandler.get('appearance'),
                        subtitle: TranslationHandler.get('appearance_subtitle'),
                        onTap: () => _showAppearanceSettings(context),
                      ),
                      Divider(height: 1, color: theme.dividerTheme.color),
                      SettingsItem(
                        icon: const SettingsIcon(
                          icon: Icons.language_outlined,
                          color: AppTheme.statusOrange,
                        ),
                        title: TranslationHandler.get('language'),
                        subtitle: TranslationHandler.get('language_subtitle'),
                        onTap: () => _showLanguageSettings(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: TranslationHandler.get('support_section'),
                    color: color.primary,
                    icon: Icons.support_agent,
                  ),
                  const SizedBox(height: 8),
                  SettingsCard(
                    children: [
                      SettingsItem(
                        icon: const SettingsIcon(
                          icon: Icons.help_outline,
                          color: AppTheme.statusBlue,
                        ),
                        title: TranslationHandler.get('help_support'),
                        subtitle: TranslationHandler.get('help_support_subtitle'),
                        onTap: null,
                      ),
                      Divider(height: 1, color: theme.dividerTheme.color),
                      SettingsItem(
                        icon: const SettingsIcon(
                          icon: Icons.info_outline,
                          color: AppTheme.statusGray,
                        ),
                        title: TranslationHandler.get('about_yack'),
                        subtitle: TranslationHandler.get('about_subtitle'),
                        onTap: () => _showAboutDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SecondaryActionButtonAutoReload(
                    action: TranslationHandler.get('logout'),
                    onClick: () async {
                      // Clear all cached data including Isar
                      await AccountService().clearCachedData();

                      await FirebaseAuth.instance.signOut();
                      context.read<AuthCubit>().markUnauthenticated();

                      Navigator.of(context, rootNavigator: true)
                          .pushNamedAndRemoveUntil('/login', (route) => false);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const LanguageSettingsSheet(),
    );
  }
}
