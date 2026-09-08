import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yack/logic/cubits/auth/auth_cubit.dart';
import 'package:yack/logic/cubits/auth/auth_state.dart';
import 'package:yack/logic/cubits/auth/login_cubit.dart';
import 'package:yack/logic/cubits/auth/login_state.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/logic/utils/validator.dart';
import 'package:yack/presentation/widgets/hrefTextWidget.dart';
import 'package:yack/presentation/widgets/inputFormWidget.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<LoginCubit>().login(
      context,
      _formKey,
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return YackAuthScaffold(
      title: TranslationHandler.get('welcome_back'),
      subtitle: TranslationHandler.get('login_subtitle'),
      icon: Icons.lock_open_outlined,
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(TranslationHandler.get('dont_have_account')),
          const SizedBox(width: 4),
          HrefWidget(
            text: TranslationHandler.get('sign_up'),
            onClick: () => Navigator.pushReplacementNamed(context, '/signup'),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
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
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
              ),
              const SizedBox(height: 16),
              CustomTextFormField(
                labelText: TranslationHandler.get('password'),
                hintText: TranslationHandler.get('password'),
                isPassword: true,
                icon: Icons.key_outlined,
                controller: _passwordController,
                validator: (value) => Validator.length(value, min: 8),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: HrefWidget(
                  text: TranslationHandler.get('forget_password'),
                  onClick: () =>
                      Navigator.pushNamed(context, '/forgot-password'),
                ),
              ),
              const SizedBox(height: 12),
              YackNotice(
                message: TranslationHandler.get('login_unlock_note'),
                tone: YackNoticeTone.neutral,
                icon: Icons.shield_outlined,
              ),
              const SizedBox(height: 20),
              BlocConsumer<LoginCubit, LoginState>(
                listener: (blocContext, state) async {
                  if (state is LoginSuccess) {
                    final accountState = await blocContext
                        .read<AuthCubit>()
                        .resolveAccountAfterLogin();
                    if (!blocContext.mounted) return;

                    if (accountState is AccountNotComplete) {
                      Navigator.pushNamedAndRemoveUntil(
                        blocContext,
                        '/init-account',
                        (_) => false,
                      );
                    } else if (accountState is AccountCompleteButLocked) {
                      Navigator.pushNamedAndRemoveUntil(
                        blocContext,
                        '/decrypt-account',
                        (_) => false,
                      );
                    } else if (accountState is Authenticated) {
                      Navigator.pushNamedAndRemoveUntil(
                        blocContext,
                        '/home',
                        (_) => false,
                      );
                    } else {
                      SnackBarHandler.showError(
                        blocContext,
                        TranslationHandler.get('auth_unexpected_error'),
                      );
                    }
                  } else if (state is LoginUnverified) {
                    Navigator.pushNamedAndRemoveUntil(
                      blocContext,
                      '/confirm',
                      (_) => false,
                    );
                  } else if (state is LoginError) {
                    SnackBarHandler.showError(
                      blocContext,
                      TranslationHandler.get(
                        state.message ?? 'auth_unexpected_error',
                      ),
                    );
                  }
                },
                builder: (context, state) => PrimaryActionButton(
                  isLoading: state is LoginLoading,
                  onClick: state is LoginLoading ? null : _submit,
                  action: TranslationHandler.get('login'),
                  icon: Icons.arrow_forward,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
