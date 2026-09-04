import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/logic/services/auth/decrypted_key_cache.dart';
import 'package:yack/logic/utils/profile_name_dialog.dart';
import 'package:yack/presentation/theme/theme.dart';

class UserInfoHeader extends StatelessWidget {
  const UserInfoHeader({super.key});

  String _initial(String? firstName) {
    if (firstName == null || firstName.trim().isEmpty) return '?';
    return firstName.trim().characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return ValueListenableBuilder(
      valueListenable: Hive.box(
        'user',
      ).listenable(keys: ['firstName', 'lastName', 'isComplete']),
      builder: (context, box, _) {
        final firstName = box.get('firstName', defaultValue: '')?.toString();
        final lastName = box.get('lastName', defaultValue: '')?.toString();
        final name = [firstName, lastName]
            .where((value) => value != null && value.trim().isNotEmpty)
            .join(' ')
            .trim();
        final setupComplete = box.get('isComplete') == true;
        final keyUnlocked = DecryptedKeyCache.isUnlocked;
        final emailVerified = firebaseUser?.emailVerified == true;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      _initial(firstName),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty
                              ? name
                              : TranslationHandler.get(
                                  'profile_name_placeholder',
                                ),
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          firebaseUser?.email ??
                              TranslationHandler.get('email_unavailable'),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: TranslationHandler.get('edit_name'),
                    onPressed: () => showEditNameDialog(context),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 12),
              _AccountStateRow(
                icon: emailVerified
                    ? Icons.verified_user_outlined
                    : Icons.mark_email_unread_outlined,
                label: emailVerified
                    ? TranslationHandler.get('email_verified')
                    : TranslationHandler.get('email_verification_required'),
                positive: emailVerified,
              ),
              const SizedBox(height: 10),
              _AccountStateRow(
                icon: keyUnlocked
                    ? Icons.lock_open_outlined
                    : Icons.lock_outline,
                label: keyUnlocked
                    ? TranslationHandler.get('agreements_unlocked_device')
                    : setupComplete
                    ? TranslationHandler.get('agreements_locked_device')
                    : TranslationHandler.get('encryption_setup_incomplete'),
                positive: keyUnlocked,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountStateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool positive;

  const _AccountStateRow({
    required this.icon,
    required this.label,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = positive
        ? AppTheme.statusGreen
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
