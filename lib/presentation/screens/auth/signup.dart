import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yack/logic/cubits/auth/signup_cubit.dart';
import 'package:yack/logic/cubits/auth/signup_state.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/logic/utils/validator.dart';
import 'package:yack/presentation/widgets/hrefTextWidget.dart';
import 'package:yack/presentation/widgets/inputFormWidget.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<SignupCubit>().signup(
      context,
      _formKey,
      _emailController.text.trim(),
      _passwordController.text,
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return YackAuthScaffold(
      title: TranslationHandler.get('create_account'),
      subtitle: TranslationHandler.get('signup_subtitle'),
      icon: Icons.person_add_alt_1_outlined,
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(TranslationHandler.get('already_have_account')),
          const SizedBox(width: 4),
          HrefWidget(
            text: TranslationHandler.get('login'),
            onClick: () => Navigator.pushReplacementNamed(context, '/login'),
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
                  AutofillHints.newUsername,
                  AutofillHints.email,
                ],
              ),
              const SizedBox(height: 16),
              CustomTextFormField(
                labelText: TranslationHandler.get('first_name'),
                hintText: TranslationHandler.get('first_name'),
                icon: Icons.person_outline,
                controller: _firstNameController,
                validator: (value) =>
                    Validator.name(value, fieldName: 'first_name'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
              ),
              const SizedBox(height: 16),
              CustomTextFormField(
                labelText: TranslationHandler.get('last_name'),
                hintText: TranslationHandler.get('last_name'),
                icon: Icons.badge_outlined,
                controller: _lastNameController,
                validator: (value) =>
                    Validator.name(value, fieldName: 'last_name'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
              ),
              const SizedBox(height: 16),
              CustomTextFormField(
                labelText: TranslationHandler.get('password'),
                hintText: TranslationHandler.get('password'),
                helperText: TranslationHandler.get('account_password_helper'),
                isPassword: true,
                icon: Icons.key_outlined,
                controller: _passwordController,
                validator: (value) => Validator.password(value, minLength: 8),
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 16),
              CustomTextFormField(
                labelText: TranslationHandler.get('confirm_password'),
                hintText: TranslationHandler.get('confirm_password'),
                isPassword: true,
                icon: Icons.key_outlined,
                controller: _confirmPasswordController,
                validator: (value) =>
                    Validator.confirmPassword(value, _passwordController.text),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              BlocConsumer<SignupCubit, SignupState>(
                listener: (context, state) {
                  if (state is SignupSuccess) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/confirm',
                      (_) => false,
                    );
                  } else if (state is SignupError) {
                    SnackBarHandler.showError(
                      context,
                      TranslationHandler.get(state.message ?? 'signup_failed'),
                    );
                  }
                },
                builder: (context, state) => PrimaryActionButton(
                  isLoading: state is SignupLoading,
                  onClick: state is SignupLoading ? null : _submit,
                  action: TranslationHandler.get('sign_up'),
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
