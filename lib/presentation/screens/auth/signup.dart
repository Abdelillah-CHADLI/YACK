import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yack/logic/cubits/auth/signup_cubit.dart';
import 'package:yack/logic/cubits/auth/signup_state.dart';
import 'package:yack/logic/utils/platform.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/utils/validator.dart';
import 'package:yack/presentation/widgets/inputFormWidget.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/titleWidget.dart';
import 'package:yack/presentation/widgets/hrefTextWidget.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});


  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
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
                const SizedBox(height: 20),
                SizedBox(
                  width: PlatformInfo.isDesktop
                      ? min(400, screenWidth * 0.9)
                      : screenWidth,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      spacing: 10,
                      children: [
                        TitleWidget(text: TranslationHandler.get('welcome')),
                        const SizedBox(height: 8),
                        Text(
                          TranslationHandler.get('signup_subtitle'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),

                        // Email
                        CustomTextFormField(
                          hintText: TranslationHandler.get('email'),
                          icon: Icons.mail_outline,
                          controller: emailController,
                          validator: Validator.email,
                        ),

                        // First & Last Name
                        Row(
                          spacing: 10,
                          children: [
                            Expanded(
                              child: CustomTextFormField(
                                hintText: TranslationHandler.get('first_name'),
                                icon: Icons.person_outline,
                                controller: firstNameController,
                                validator: (v) =>
                                    Validator.name(v, fieldName: 'first_name'),
                              ),
                            ),
                            Expanded(
                              child: CustomTextFormField(
                                hintText: TranslationHandler.get('last_name'),
                                controller: lastNameController,
                                validator: (v) =>
                                    Validator.name(v, fieldName: 'last_name'),
                              ),
                            ),
                          ],
                        ),

                        // Password
                        CustomTextFormField(
                          hintText: TranslationHandler.get('password'),
                          isPassword: true,
                          icon: Icons.lock_outline,
                          controller: passwordController,
                          validator: (v) =>
                              Validator.password(v, minLength: 8),
                        ),

                        // Password Confirm
                        CustomTextFormField(
                          hintText: TranslationHandler.get('confirm_password'),
                          isPassword: true,
                          icon: Icons.lock_outline,
                          controller: confirmPasswordController,
                          validator: (v) => Validator.confirmPassword(
                              v, passwordController.value.text),
                        ),
                        BlocConsumer<SignupCubit, SignupState>(
                          builder: (context, state) {
                            return PrimaryActionButton(
                              isLoading: state is SignupLoading,
                              action: TranslationHandler.get('sign_up'),
                              onClick: () {
                                context.read<SignupCubit>().signup(
                                    context,
                                    _formKey,
                                    emailController.value.text.trim(),
                                    passwordController.value.text.trim(),
                                    firstNameController.value.text.trim(),
                                    lastNameController.value.text.trim());
                              },
                            );
                          },
                          listener: (context, state) {
                            if (state is SignupSuccess) {
                              Navigator.pushReplacementNamed(
                                  context, "/confirm");
                            } else if (state is SignupError) {
                              SnackBarHandler.showError(
                                  context,
                                  TranslationHandler.get('signup_failed'));
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(TranslationHandler.get('already_have_account')),
                            const SizedBox(width: 5),
                            HrefWidget(
                              text: TranslationHandler.get('login'),
                              onClick: () =>
                                  Navigator.pushNamed(context, '/login'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
