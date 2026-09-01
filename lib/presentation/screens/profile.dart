import 'package:flutter/material.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/widgets/profile/contract_status_summary.dart';
import 'package:yack/presentation/widgets/profile/user_info_header.dart';
import 'package:yack/presentation/widgets/settingWidgets/sectionHeader.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          TranslationHandler.get('profile'),
          style: theme.textTheme.titleMedium,
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: TranslationHandler.get('profile_information'),
                    color: theme.colorScheme.primary,
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 8),
                  const UserInfoHeader(),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: TranslationHandler.get('contracts_summary'),
                    color: theme.colorScheme.primary,
                    icon: Icons.assessment_outlined,
                  ),
                  const SizedBox(height: 8),
                  const ContractStatusSummary(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
