import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:yack/logic/utils/profile_name_dialog.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';

class UserInfoHeader extends StatelessWidget {
  const UserInfoHeader({super.key});

  String _buildInitial(String? firstName) {
    if (firstName == null || firstName.trim().isEmpty) return '?';
    return firstName.trim().characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ValueListenableBuilder(
        valueListenable:
            Hive.box('user').listenable(keys: ['firstName', 'lastName']),
        builder: (context, box, _) {
          final firstName = box.get('firstName', defaultValue: '') as String?;
          final lastName = box.get('lastName', defaultValue: '') as String?;

          final name = [firstName, lastName]
              .where((value) => value != null && value.toString().isNotEmpty)
              .join(' ')
              .trim();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  _buildInitial(firstName),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty
                          ? name
                          : TranslationHandler.get('profile_name_placeholder'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user?.email ?? TranslationHandler.get('email'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 14,
                          color: colorScheme.primary.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          TranslationHandler.get('status_active'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        foregroundColor: colorScheme.primary,
                      ),
                      onPressed: () => showEditNameDialog(context),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(TranslationHandler.get('edit_name')),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
