import 'package:hive/hive.dart';
import 'package:yack/logic/services/auth/cryptoService.dart';
import 'package:yack/logic/services/auth/decrypted_key_cache.dart';
import 'package:yack/logic/services/user/user_service.dart';

class InitAccountService {
  InitAccountService({UserService? userService})
    : _userService = userService ?? UserService();

  final UserService _userService;

  Future<void> initializeAccount(String password) async {
    final keyBundle = await CryptoService.generateAndEncryptKeysAsync(password);
    await _userService.finalize(
      publicKey: keyBundle['publicKey']!,
      encryptedPrivateKey: keyBundle['encryptedPrivateKey']!,
      salt: keyBundle['salt']!,
      iv: keyBundle['iv']!,
    );

    // Keep the unlocked private key in process memory for immediate use.
    // Runs on a background isolate so the first unlock stays responsive (F-19).
    final decryptedPrivateKey = await CryptoService.decryptPrivateKeyAsync(
      ciphertextBase64: keyBundle['encryptedPrivateKey']!,
      password: password,
      saltBase64: keyBundle['salt']!,
      ivBase64: keyBundle['iv']!,
    );

    final box = await Hive.openBox('user');
    await box.put('publicKey', keyBundle['publicKey']);
    await box.put('encryptedPrivateKey', keyBundle['encryptedPrivateKey']);
    await box.put('privateKeySalt', keyBundle['salt']);
    await box.put('privateKeyIV', keyBundle['iv']);
    DecryptedKeyCache.store(decryptedPrivateKey);
    await box.delete('decryptedPrivateKey');
    await box.put('isComplete', true);
  }
}
