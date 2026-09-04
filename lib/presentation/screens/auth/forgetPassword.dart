import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yack/logic/cubits/auth/password_reset_cubit.dart';
import 'package:yack/logic/cubits/auth/password_reset_state.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/logic/utils/validator.dart';
import 'package:yack/presentation/widgets/hrefTextWidget.dart';
import 'package:yack/presentation/widgets/inputFormWidget.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

class ForgetPassword extends StatefulWidget {
  const ForgetPassword({super.key});

  @override
  State<ForgetPassword> createState() => _ForgetPasswordState();
}

class _ForgetPasswordState extends State<ForgetPassword> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<PasswordResetCubit>().resetPassword(
      context,
      _formKey,
      _emailController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return YackAuthScaffold(
      showBack: true,
      title: TranslationHandler.get('forget_password'),
      subtitle: TranslationHandler.get('forget_password_message'),
      icon: Icons.password_outlined,
      footer: HrefWidget(
        text: TranslationHandler.get('back_to_login'),
        onClick: () => Navigator.pushReplacementNamed(context, '/login'),
      ),
      child: BlocConsumer<PasswordResetCubit, PasswordResetState>(
        listener: (context, state) {
          if (state is PasswordResetError) {
            SnackBarHandler.showError(
              context,
              TranslationHandler.get(state.messageKey),
            );
          }
        },
        builder: (context, state) {
          if (state is PasswordResetSuccess) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                YackNotice(
                  message: TranslationHandler.resolve(
                    'password_reset_sent_to',
                    params: {'email': _emailController.text.trim()},
                  ),
                  tone: YackNoticeTone.positive,
                  icon: Icons.mark_email_read_outlined,
                ),
                const SizedBox(height: 20),
                PrimaryActionButton(
                  action: TranslationHandler.get('back_to_login'),
                  icon: Icons.arrow_back,
                  onClick: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                ),
              ],
            );
          }

          return Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextFormField(
                  labelText: TranslationHandler.get('email'),
                  hintText: TranslationHandler.get('email'),
                  icon: Icons.mail_outline,
                  controller: _emailController,
                  validator: Validator.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                PrimaryActionButton(
                  isLoading: state is PasswordResetLoading,
                  action: TranslationHandler.get('send_reset_link'),
                  icon: Icons.send_outlined,
                  onClick: state is PasswordResetLoading ? null : _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
