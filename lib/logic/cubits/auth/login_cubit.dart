import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yack/logic/services/auth/auth_service.dart';

import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(LoginInitial());

  Future<void> login(
    BuildContext context,
    GlobalKey<FormState> formKey,
    String email,
    String password,
  ) async {
    emit(LoginLoading());

    try {
      final isVerified = await AuthService.login(
        context,
        formKey,
        email,
        password,
      );
      emit(isVerified ? LoginSuccess() : LoginUnverified());
    } catch (e) {
      emit(LoginError(e.toString()));
    }
  }
}
