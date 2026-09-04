import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/adapters.dart';
import 'logic/cubits/auth/auth_cubit.dart';
import 'logic/cubits/auth/auth_state.dart';
import 'logic/services/snackBarHandler.dart';
import 'logic/services/translation_handler.dart';
import 'presentation/widgets/yack_ui.dart';

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        final userBox = Hive.box('user');

        // ERROR → Show Snack bar only
        if (state is AuthError) {
          SnackBarHandler.showError(
            context,
            TranslationHandler.get(state.messageKey),
          );
        }

        // ==========================
        //     UNVERIFIED USER
        // ==========================
        if (state is UnverifiedUser) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/confirm',
              (_) => false,
            );
          });
          return; // IMPORTANT
        }

        // ==========================
        //    ACCOUNT NOT COMPLETE
        // ==========================
        if (state is AccountNotComplete) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/init-account',
              (_) => false,
            );
          });
          return; // IMPORTANT
        }

        // ==========================
        //   ACCOUNT COMPLETE BUT
        //   NO DECRYPTED PRIVATE KEY
        // ==========================
        if (state is AccountCompleteButLocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/decrypt-account',
              (_) => false,
            );
          });
          return; // IMPORTANT
        }

        // ==========================
        //        UNAUTHENTICATED
        // ==========================
        if (state is Unauthenticated || state is AuthError) {
          // FIRST TIME → WELCOME
          if (userBox.get('didFirstTime') != true) {
            userBox.put('didFirstTime', true);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/welcome',
                (_) => false,
              );
            });

            return; // IMPORTANT
          }

          // Seen login screen before
          if (userBox.get('didFirstLogin') == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (_) => false,
              );
            });

            return; // IMPORTANT
          }

          // DEFAULT → signup
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(context, '/signup', (_) => false);
          });

          return; // IMPORTANT
        }

        // ==========================
        //         AUTHENTICATED
        // ==========================
        if (state is Authenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
          });

          return;
        }
      },

      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const YackBrand(),
                  const SizedBox(height: 24),
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    TranslationHandler.get('checking_account'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
