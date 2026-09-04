import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:yack/logic/cubits/auth/auth_cubit.dart';
import 'package:yack/logic/cubits/user/user_cubit.dart';
import 'package:yack/logic/cubits/user/user_state.dart';
import 'package:yack/logic/services/auth/account_service.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/logic/utils/validator.dart';
import 'package:yack/presentation/widgets/hrefTextWidget.dart';
import 'package:yack/presentation/widgets/inputFormWidget.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

/// Creates the local encryption key after email verification.
class InitAccountScreen extends StatefulWidget {
  const InitAccountScreen({super.key});

  @override
  State<InitAccountScreen> createState() => _InitAccountScreenState();
}

class _InitAccountScreenState extends State<InitAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _needsNames = false;
  bool _understandsRecovery = false;

  @override
  void initState() {
    super.initState();
    final box = Hive.box('user');
    _firstNameController.text = box.get('firstName')?.toString() ?? '';
    _lastNameController.text = box.get('lastName')?.toString() ?? '';
    _needsNames =
        _firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return TranslationHandler.get('init_account_password_required');
    }
    if (text.length < 12) {
      return TranslationHandler.get('init_account_password_min_length');
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value != _passwordController.text) {
      return TranslationHandler.get('passwords_do_not_match');
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_understandsRecovery) {
      SnackBarHandler.showWarning(
        context,
        TranslationHandler.get('acknowledge_encryption_warning'),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    if (_needsNames) {
      await Hive.box('user').putAll({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
      });
    }
    if (!mounted) return;
    context.read<UserCubit>().finalize(password: _passwordController.text);
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
    return YackAuthScaffold(
      title: TranslationHandler.get('init_account_title'),
      subtitle: TranslationHandler.get('init_account_subtitle'),
      icon: Icons.enhanced_encryption_outlined,
      footer: HrefWidget(
        text: TranslationHandler.get('use_another_account'),
        onClick: _switchAccount,
      ),
      child: BlocConsumer<UserCubit, UserState>(
        listener: (context, state) {
          if (state is UserFinalizeSuccess) {
            context.read<AuthCubit>().markAuthenticated();
            Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
          } else if (state is UserError) {
            SnackBarHandler.showError(context, state.message);
          }
        },
        builder: (context, state) {
          return AutofillGroup(
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  YackNotice(
                    message: TranslationHandler.get('init_account_warning'),
                    tone: YackNoticeTone.warning,
                    icon: Icons.key_outlined,
                  ),
                  if (_needsNames) ...[
                    const SizedBox(height: 22),
                    Text(
                      TranslationHandler.get('complete_profile'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    CustomTextFormField(
                      labelText: TranslationHandler.get('first_name'),
                      hintText: TranslationHandler.get('first_name'),
                      controller: _firstNameController,
                      icon: Icons.person_outline,
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
                      controller: _lastNameController,
                      icon: Icons.badge_outlined,
                      validator: (value) =>
                          Validator.name(value, fieldName: 'last_name'),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.familyName],
                    ),
                  ],
                  const SizedBox(height: 22),
                  CustomTextFormField(
                    labelText: TranslationHandler.get(
                      'init_account_password_label',
                    ),
                    hintText: TranslationHandler.get(
                      'init_account_password_label',
                    ),
                    helperText: TranslationHandler.get(
                      'init_account_password_helper',
                    ),
                    isPassword: true,
                    icon: Icons.key_outlined,
                    controller: _passwordController,
                    validator: _validatePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                  const SizedBox(height: 16),
                  CustomTextFormField(
                    labelText: TranslationHandler.get(
                      'init_account_confirm_password_label',
                    ),
                    hintText: TranslationHandler.get(
                      'init_account_confirm_password_label',
                    ),
                    isPassword: true,
                    icon: Icons.key_outlined,
                    controller: _confirmPasswordController,
                    validator: _validateConfirmation,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _understandsRecovery,
                    onChanged: state is UserLoading
                        ? null
                        : (value) => setState(
                            () => _understandsRecovery = value ?? false,
                          ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      TranslationHandler.get('encryption_acknowledgement'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 18),
                  PrimaryActionButton(
                    isLoading: state is UserLoading,
                    action: TranslationHandler.get('init_account_submit'),
                    icon: Icons.shield_outlined,
                    onClick: state is UserLoading ? null : _submit,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
