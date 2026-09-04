import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yack/logic/cubits/auth/auth_cubit.dart';
import 'package:yack/logic/cubits/auth/confirm_cubit.dart';
import 'package:yack/logic/cubits/auth/confirm_state.dart';
import 'package:yack/logic/services/auth/account_service.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/widgets/hrefTextWidget.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

class ConfirmAccount extends StatefulWidget {
  const ConfirmAccount({super.key});

  @override
  State<ConfirmAccount> createState() => _ConfirmAccountState();
}

class _ConfirmAccountState extends State<ConfirmAccount> {
  bool _isResending = false;

  Future<void> _resend() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    final sent = await context.read<ConfirmCubit>().sendConfirmationEmail();
    if (!mounted) return;
    setState(() => _isResending = false);
    if (sent) {
      SnackBarHandler.showMessage(
        context,
        TranslationHandler.get('verification_email_sent'),
      );
    } else {
      SnackBarHandler.showError(
        context,
        TranslationHandler.get('resend_failed'),
      );
    }
  }

  Future<void> _switchAccount() async {
    await AccountService().clearCachedData();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.read<AuthCubit>().markUnauthenticated();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final email =
        FirebaseAuth.instance.currentUser?.email ??
        TranslationHandler.get('your_email');

    return YackAuthScaffold(
      title: TranslationHandler.get('confirm_account'),
      subtitle: TranslationHandler.get('confirm_account_message'),
      icon: Icons.mark_email_unread_outlined,
      footer: HrefWidget(
        text: TranslationHandler.get('use_another_account'),
        onClick: _switchAccount,
      ),
      child: BlocConsumer<ConfirmCubit, ConfirmState>(
        listener: (context, state) {
          if (state is ConfirmSuccess) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/init-account',
              (_) => false,
            );
          } else if (state is ConfirmUnverified) {
            SnackBarHandler.showWarning(
              context,
              TranslationHandler.get('auth_email_not_verified'),
            );
          } else if (state is ConfirmError) {
            SnackBarHandler.showError(
              context,
              TranslationHandler.get(state.message ?? 'auth_unexpected_error'),
            );
          }
        },
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              YackNotice(
                message: TranslationHandler.resolve(
                  'verification_sent_to',
                  params: {'email': email},
                ),
                icon: Icons.alternate_email,
              ),
              const SizedBox(height: 22),
              PrimaryActionButton(
                isLoading: state is ConfirmLoading,
                action: TranslationHandler.get('verified_email_action'),
                icon: Icons.verified_outlined,
                onClick: state is ConfirmLoading
                    ? null
                    : () => context.read<ConfirmCubit>().confirm(),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isResending ? null : _resend,
                icon: _isResending
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _isResending
                      ? TranslationHandler.get('sending')
                      : TranslationHandler.get('resend_email'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
