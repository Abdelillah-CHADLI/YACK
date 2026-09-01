import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yack/logic/cubits/auth/login_cubit.dart';
import 'package:yack/logic/cubits/auth/login_state.dart';
import 'package:yack/logic/utils/platform.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/titleWidget.dart';
import 'package:yack/presentation/widgets/hrefTextWidget.dart';
import 'package:yack/logic/utils/validator.dart';
import 'package:yack/presentation/widgets/inputFormWidget.dart';
import 'package:yack/presentation/theme/theme.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppTheme.yackGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    TranslationHandler.get('app_name'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: PlatformInfo.isDesktop
                    ? min(400, screenWidth * 0.9)
                    : screenWidth,
                child: Form(
                  key: _formKey,
                  child: Column(
                    spacing: 10,
                    children: [
                      TitleWidget(
                          text: TranslationHandler.get('welcome_back')),
                      const SizedBox(height: 8),
                      Text(
                        TranslationHandler.get('login_subtitle'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      CustomTextFormField(
                        hintText: TranslationHandler.get('email'),
                        icon: Icons.mail_outline,
                        controller: emailController,
                        validator: Validator.email,
                      ),
                      CustomTextFormField(
                        hintText: TranslationHandler.get('password'),
                        isPassword: true,
                        icon: Icons.lock_outline,
                        controller: passwordController,
                        validator: (v) => Validator.length(v, min: 8),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          HrefWidget(
                            text: TranslationHandler.get('forget_password'),
                            onClick: () {
                              Navigator.pushNamed(context, '/forgot-password');
                            },
                          ),
                        ],
                      ),
                      BlocConsumer<LoginCubit, LoginState>(
                        listener: (context, state) {
                          if (state is LoginSuccess) {
                            // Navigate to decrypt account to unlock with encryption password
                            Navigator.pushReplacementNamed(
                                context, "/decrypt-account");
                          } else if (state is LoginError) {
                            SnackBarHandler.showError(
                                context,
                                TranslationHandler.get(state.message!));
                          }
                        },
                        builder: (context, state) {
                          return PrimaryActionButton(
                            isLoading: state is LoginLoading,
                            onClick: () {
                              context.read<LoginCubit>().login(
                                  context,
                                  _formKey,
                                  emailController.value.text.trim(),
                                  passwordController.value.text.trim());
                            },
                            action: TranslationHandler.get('login'),
                          );
                        },
                      )
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 5,
                children: [
                  Text(TranslationHandler.get('dont_have_account')),
                  HrefWidget(
                    text: TranslationHandler.get('sign_up'),
                    onClick: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
