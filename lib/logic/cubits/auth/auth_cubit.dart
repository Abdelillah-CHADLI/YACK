import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_state.dart';
import 'package:yack/logic/services/auth/auth_service.dart';
import 'package:yack/logic/services/contract/contract_sync_service.dart';
import 'package:yack/logic/services/auth/account_service.dart';
import 'package:hive/hive.dart';
import 'package:yack/logic/services/auth/decrypted_key_cache.dart';
import 'package:yack/logic/services/notification/notification_service.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  final ContractSyncService _syncService = ContractSyncService();
  final AccountService _accountService = AccountService();

  Future<void> checkAuth() async {
    emit(AuthChecking());

    // 1) Fast local read for quick app startup
    try {
      final localStatus = await AuthService.readLastAuthStatus();
      if (localStatus == true) {
        // User was locally authenticated -> decide which state to emit
        await _evaluateAccountStateAndEmit(fromOnlineCheck: false);
      } else if (localStatus == null) {
        emit(UnverifiedUser());
      } else {
        emit(Unauthenticated());
      }
    } catch (_) {
      // If local read fails for any reason, just continue to online check
    }

    // 2) Online check to refresh real status when internet is available
    try {
      final isLoggedIn = await AuthService.isAuthenticated();

      if (isLoggedIn == true) {
        await _evaluateAccountStateAndEmit(fromOnlineCheck: true);
        // Sync contracts in background when authenticated (only if fully ready)
        if (state is Authenticated) {
          _syncContractsInBackground();
        }
      } else if (isLoggedIn == null) {
        // logged in but email not verified
        emit(UnverifiedUser());
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      // If online check fails (e.g. no internet), emit error
      // emit(AuthError(e.toString()));

      // Schedule a retry after some delay (e.g. 5 seconds)
      Future.delayed(const Duration(seconds: 5), () {
        // Only retry if we are still in an error state to avoid
        // interfering with manual navigation changes
        if (state is AuthError) {
          checkOnlineAuth();
        }
      });
    }
  }

  /// Decide between:
  /// - AccountNotComplete
  /// - AccountCompleteButLocked
  /// - Authenticated
  Future<void> _evaluateAccountStateAndEmit({
    required bool fromOnlineCheck,
  }) async {
    // When coming from online, refresh profile cache to have latest isComplete, keys, etc.
    if (fromOnlineCheck) {
      await _accountService.fetchAndCacheProfile();
    }

    final box = await Hive.openBox('user');
    final isComplete = box.get('isComplete') ?? false;
    // Migrate away from older versions that persisted the unlocked key.
    if (box.containsKey('decryptedPrivateKey')) {
      await box.delete('decryptedPrivateKey');
    }

    if (!isComplete) {
      // Account not finished (no keypair initialized, etc.)
      emit(AccountNotComplete());
      return;
    }

    // Account is complete
    if (!DecryptedKeyCache.isUnlocked) {
      // Need to decrypt private key first
      emit(AccountCompleteButLocked());
      return;
    }

    // Account complete and the process-memory key exists -> fully authenticated
    emit(Authenticated());
  }

  /// Sync contracts in background (non-blocking)
  void _syncContractsInBackground() {
    unawaited(NotificationService().registerCurrentToken());
    // Run in background, don't await
    _syncService
        .syncContracts()
        .then((count) {
          print('[AuthCubit] Synced $count contracts in background');
        })
        .catchError((e) {
          print('[AuthCubit] Background contract sync failed: $e');
        });
  }

  Future<void> checkOnlineAuth() async {
    try {
      final isLoggedIn = await AuthService.isAuthenticated();

      if (isLoggedIn == true) {
        await _evaluateAccountStateAndEmit(fromOnlineCheck: true);
        if (state is Authenticated) {
          _syncContractsInBackground();
        }
      } else if (isLoggedIn == null) {
        // logged in but email not verified
        emit(UnverifiedUser());
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {}
  }

  /// Refresh the backend profile after a successful Firebase login and return
  /// the account state the UI should route to.
  Future<AuthState> resolveAccountAfterLogin() async {
    try {
      await _evaluateAccountStateAndEmit(fromOnlineCheck: true);
    } catch (_) {
      emit(AuthError('auth_unexpected_error'));
    }
    return state;
  }

  Future<bool> markAuthenticated() async {
    try {
      // Refreshing the backend profile also guarantees that the Mongo user ID
      // is cached before contract decryption decides which party key to use.
      await _evaluateAccountStateAndEmit(fromOnlineCheck: true);
      if (state is Authenticated) {
        _syncContractsInBackground();
        return true;
      }
      return false;
    } catch (error) {
      emit(AuthError(error.toString()));
      return false;
    }
  }

  void markUnauthenticated() {
    emit(Unauthenticated());
  }
}
