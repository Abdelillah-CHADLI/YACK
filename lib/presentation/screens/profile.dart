import 'package:flutter/material.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/widgets/profile/contract_status_summary.dart';
import 'package:yack/presentation/widgets/profile/user_info_header.dart';
import 'package:yack/presentation/widgets/settingWidgets/sectionHeader.dart';
import 'package:yack/presentation/theme/theme.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(TranslationHandler.get('profile'))),
      body: SingleChildScrollView(
        child: YackContent(
          maxWidth: 680,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            12,
            AppTheme.pagePadding,
            36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YackPageHeading(
                title: TranslationHandler.get('identity_security'),
                subtitle: TranslationHandler.get('identity_security_desc'),
              ),
              const SizedBox(height: 26),
              SectionHeader(
                title: TranslationHandler.get('profile_information'),
                color: theme.colorScheme.primary,
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 8),
              const UserInfoHeader(),
              const SizedBox(height: 26),
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
    );
  }
}
