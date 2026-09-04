import 'package:flutter/material.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

class PrivacySettingsSheet extends StatelessWidget {
  const PrivacySettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              TranslationHandler.get('privacy_settings'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            YackNotice(
              message: TranslationHandler.get('privacy_controls_detail'),
              icon: Icons.shield_outlined,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              TranslationHandler.get('privacy_controls_explanation'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spaceXl),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(TranslationHandler.get('done')),
            ),
          ],
        ),
      ),
    );
  }
}
