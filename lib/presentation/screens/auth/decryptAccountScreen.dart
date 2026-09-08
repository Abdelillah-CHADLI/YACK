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
import 'package:yack/presentation/widgets/hrefTextWidget.dart';
import 'package:yack/presentation/widgets/inputFormWidget.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

/// Unlocks the encrypted private key after a returning user signs in.
class DecryptAccountScreen extends StatefulWidget {
  const DecryptAccountScreen({super.key});

  @override
  State<DecryptAccountScreen> createState() => _DecryptAccountScreenState();
}

class _DecryptAccountScreenState extends State<DecryptAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _profileRequested = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileRequested) return;
    _profileRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UserCubit>().getProfile();
    });
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) {
      return TranslationHandler.get('decrypt_account_password_required');
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    context.read<UserCubit>().decryptAndLoad(
      password: _passwordController.text,
    );
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
        Hive.box('user').get('email')?.toString() ??
        '';

    return YackAuthScaffold(
      title: TranslationHandler.get('decrypt_account_title'),
      subtitle: TranslationHandler.get('decrypt_account_subtitle'),
      icon: Icons.key_outlined,
      footer: HrefWidget(
        text: TranslationHandler.get('use_another_account'),
        onClick: _switchAccount,
      ),
      child: BlocConsumer<UserCubit, UserState>(
        listener: (context, state) async {
          if (state is UserProfileMissingKeys) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/init-account',
              (_) => false,
            );
          } else if (state is UserDecryptSuccess) {
            final ready = await context.read<AuthCubit>().markAuthenticated();
            if (!context.mounted || !ready) return;
            Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
          } else if (state is UserDecryptError) {
            SnackBarHandler.showError(
              context,
              TranslationHandler.get('decrypt_account_error'),
            );
          } else if (state is UserError) {
            SnackBarHandler.showError(context, state.message);
          }
        },
        builder: (context, state) {
          return Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                YackNotice(
                  message: email.isEmpty
                      ? TranslationHandler.get('decrypt_account_info')
                      : TranslationHandler.resolve(
                          'unlocking_account',
                          params: {'email': email},
                        ),
                  icon: Icons.lock_outline,
                ),
                const SizedBox(height: 22),
                CustomTextFormField(
                  labelText: TranslationHandler.get(
                    'decrypt_account_password_label',
                  ),
                  hintText: TranslationHandler.get(
                    'decrypt_account_password_label',
                  ),
                  helperText: TranslationHandler.get(
                    'encryption_password_not_login',
                  ),
                  isPassword: true,
                  icon: Icons.key_outlined,
                  controller: _passwordController,
                  validator: _validatePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                PrimaryActionButton(
                  isLoading: state is UserLoading,
                  action: TranslationHandler.get('decrypt_account_submit'),
                  icon: Icons.lock_open_outlined,
                  onClick: state is UserLoading ? null : _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
