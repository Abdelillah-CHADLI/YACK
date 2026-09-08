import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yack/logic/services/auth/cryptoService.dart';
import 'package:yack/logic/services/media/media_crypto.dart';

class _Identity {
  _Identity(this.publicKey, this.privateKey);

  final String publicKey;
  final Uint8List privateKey;
}
void main() {
  group('CryptoService', () {
    group('generateAndEncryptKeys', () {
      test('generates all required key components', () async {
        const password = 'TestPassword123!';

        final result = await CryptoService.generateAndEncryptKeys(password);

        expect(result.containsKey('publicKey'), true);
        expect(result.containsKey('encryptedPrivateKey'), true);
        expect(result.containsKey('salt'), true);
        expect(result.containsKey('iv'), true);
      });

      test('generates non-empty values for all components', () async {
        const password = 'TestPassword123!';

        final result = await CryptoService.generateAndEncryptKeys(password);

        expect(result['publicKey']!.isNotEmpty, true);
        expect(result['encryptedPrivateKey']!.isNotEmpty, true);
        expect(result['salt']!.isNotEmpty, true);
        expect(result['iv']!.isNotEmpty, true);
      });

      test('generates valid base64 encoded values', () async {
        const password = 'TestPassword123!';

        final result = await CryptoService.generateAndEncryptKeys(password);

        // These should not throw if valid base64
        expect(() => base64Decode(result['publicKey']!), returnsNormally);
        expect(() => base64Decode(result['encryptedPrivateKey']!), returnsNormally);
        expect(() => base64Decode(result['salt']!), returnsNormally);
        expect(() => base64Decode(result['iv']!), returnsNormally);
      });

      test('generates unique keys for each call', () async {
        const password = 'TestPassword123!';

        final result1 = await CryptoService.generateAndEncryptKeys(password);
        final result2 = await CryptoService.generateAndEncryptKeys(password);

        expect(result1['publicKey'], isNot(equals(result2['publicKey'])));
        expect(result1['encryptedPrivateKey'], isNot(equals(result2['encryptedPrivateKey'])));
        expect(result1['salt'], isNot(equals(result2['salt'])));
        expect(result1['iv'], isNot(equals(result2['iv'])));
      });
    });

    group('encryptPrivateKey and decryptPrivateKey', () {
      test('decrypts encrypted private key correctly', () async {
        const password = 'TestPassword123!';

        final generated = await CryptoService.generateAndEncryptKeys(password);

        final decrypted = CryptoService.decryptPrivateKey(
          ciphertextBase64: generated['encryptedPrivateKey']!,
          password: password,
          saltBase64: generated['salt']!,
          ivBase64: generated['iv']!,
        );

        // Decrypted bytes should be valid JSON containing RSA key components
        final jsonStr = utf8.decode(decrypted);
        final keyData = json.decode(jsonStr) as Map<String, dynamic>;

        expect(keyData.containsKey('n'), true);
        expect(keyData.containsKey('d'), true);
        expect(keyData.containsKey('p'), true);
        expect(keyData.containsKey('q'), true);
      });

      test('fails to decrypt with wrong password', () async {
        const password = 'CorrectPassword123!';
        const wrongPassword = 'WrongPassword456!';

        final generated = await CryptoService.generateAndEncryptKeys(password);

        expect(
          () => CryptoService.decryptPrivateKey(
            ciphertextBase64: generated['encryptedPrivateKey']!,
            password: wrongPassword,
            saltBase64: generated['salt']!,
            ivBase64: generated['iv']!,
          ),
          throwsA(anything),
        );
      });
    });

    group('encryptWithPublicKey and decryptWithPrivateKey', () {
      test('encrypts and decrypts message correctly', () async {
        const password = 'TestPassword123!';
        const testMessage = 'Hello, this is a secret message!';

        final generated = await CryptoService.generateAndEncryptKeys(password);
        final privateKeyBytes = CryptoService.decryptPrivateKey(
          ciphertextBase64: generated['encryptedPrivateKey']!,
          password: password,
          saltBase64: generated['salt']!,
          ivBase64: generated['iv']!,
        );

        final encrypted = CryptoService.encryptWithPublicKey(
          plaintext: testMessage,
          publicKeyBase64: generated['publicKey']!,
        );

        final decrypted = CryptoService.decryptWithPrivateKey(
          ciphertextBase64: encrypted,
          privateKeyBytes: privateKeyBytes,
        );

        expect(decrypted, equals(testMessage));
      });

      test('encrypts short message correctly', () async {
        const password = 'TestPassword123!';
        const testMessage = 'Hi';

        final generated = await CryptoService.generateAndEncryptKeys(password);
        final privateKeyBytes = CryptoService.decryptPrivateKey(
          ciphertextBase64: generated['encryptedPrivateKey']!,
          password: password,
          saltBase64: generated['salt']!,
          ivBase64: generated['iv']!,
        );

        final encrypted = CryptoService.encryptWithPublicKey(
          plaintext: testMessage,
          publicKeyBase64: generated['publicKey']!,
        );

        final decrypted = CryptoService.decryptWithPrivateKey(
          ciphertextBase64: encrypted,
          privateKeyBytes: privateKeyBytes,
        );

        expect(decrypted, equals(testMessage));
      });

      test('encrypts numeric message correctly', () async {
        const password = 'TestPassword123!';
        const testMessage = '2500 DZD';

        final generated = await CryptoService.generateAndEncryptKeys(password);
        final privateKeyBytes = CryptoService.decryptPrivateKey(
          ciphertextBase64: generated['encryptedPrivateKey']!,
          password: password,
          saltBase64: generated['salt']!,
          ivBase64: generated['iv']!,
        );

        final encrypted = CryptoService.encryptWithPublicKey(
          plaintext: testMessage,
          publicKeyBase64: generated['publicKey']!,
        );

        final decrypted = CryptoService.decryptWithPrivateKey(
          ciphertextBase64: encrypted,
          privateKeyBytes: privateKeyBytes,
        );

        expect(decrypted, equals(testMessage));
      });

      test('encrypts unicode message correctly', () async {
        const password = 'TestPassword123!';
        const testMessage = 'مرحبا بالعالم 👋';

        final generated = await CryptoService.generateAndEncryptKeys(password);
        final privateKeyBytes = CryptoService.decryptPrivateKey(
          ciphertextBase64: generated['encryptedPrivateKey']!,
          password: password,
          saltBase64: generated['salt']!,
          ivBase64: generated['iv']!,
        );

        final encrypted = CryptoService.encryptWithPublicKey(
          plaintext: testMessage,
          publicKeyBase64: generated['publicKey']!,
        );

        final decrypted = CryptoService.decryptWithPrivateKey(
          ciphertextBase64: encrypted,
          privateKeyBytes: privateKeyBytes,
        );

        expect(decrypted, equals(testMessage));
      });

      test('encrypted output is base64 encoded', () async {
        const password = 'TestPassword123!';
        const testMessage = 'Test message';

        final generated = await CryptoService.generateAndEncryptKeys(password);

        final encrypted = CryptoService.encryptWithPublicKey(
          plaintext: testMessage,
          publicKeyBase64: generated['publicKey']!,
        );

        // Should not throw if valid base64
        expect(() => base64Decode(encrypted), returnsNormally);
      });

      test('same message encrypted twice produces different ciphertext', () async {
        const password = 'TestPassword123!';
        const testMessage = 'Test message';

        final generated = await CryptoService.generateAndEncryptKeys(password);

        final encrypted1 = CryptoService.encryptWithPublicKey(
          plaintext: testMessage,
          publicKeyBase64: generated['publicKey']!,
        );

        final encrypted2 = CryptoService.encryptWithPublicKey(
          plaintext: testMessage,
          publicKeyBase64: generated['publicKey']!,
        );

        // OAEP padding should produce different ciphertext each time
        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('cannot decrypt with wrong private key', () async {
        const password = 'TestPassword123!';
        const testMessage = 'Test message';

        final generated1 = await CryptoService.generateAndEncryptKeys(password);
        final generated2 = await CryptoService.generateAndEncryptKeys(password);

        final privateKeyBytes2 = CryptoService.decryptPrivateKey(
          ciphertextBase64: generated2['encryptedPrivateKey']!,
          password: password,
          saltBase64: generated2['salt']!,
          ivBase64: generated2['iv']!,
        );

        final encrypted = CryptoService.encryptWithPublicKey(
          plaintext: testMessage,
          publicKeyBase64: generated1['publicKey']!, // Encrypt with key1
        );

        // Try to decrypt with key2's private key
        expect(
          () => CryptoService.decryptWithPrivateKey(
            ciphertextBase64: encrypted,
            privateKeyBytes: privateKeyBytes2,
          ),
          throwsA(anything),
        );
      });
    });

    group('generateRSAKeyPair', () {
      test('generates valid RSA key pair', () {
        final keyPair = CryptoService.generateRSAKeyPair();

        expect(keyPair.publicKey, isNotNull);
        expect(keyPair.privateKey, isNotNull);
      });
    });

    group('edge cases', () {
      test('handles empty password', () async {
        const password = '';

        final generated = await CryptoService.generateAndEncryptKeys(password);

        expect(generated['publicKey']!.isNotEmpty, true);
        expect(generated['encryptedPrivateKey']!.isNotEmpty, true);
      });

      test('handles very long password', () async {
        final password = 'A' * 1000;

        final generated = await CryptoService.generateAndEncryptKeys(password);

        expect(generated['publicKey']!.isNotEmpty, true);
        expect(generated['encryptedPrivateKey']!.isNotEmpty, true);
      });

      test('handles special characters in password', () async {
        const password = '!@#\$%^&*()_+-=[]{}|;:,.<>?/~`éèà';

        final generated = await CryptoService.generateAndEncryptKeys(password);
        final privateKeyBytes = CryptoService.decryptPrivateKey(
          ciphertextBase64: generated['encryptedPrivateKey']!,
          password: password,
          saltBase64: generated['salt']!,
          ivBase64: generated['iv']!,
        );

        expect(privateKeyBytes.isNotEmpty, true);
      });
    });

    group('background isolate variants (F-19/F-20)', () {
      test('async keygen/decrypt round-trips to the same key material', () async {
        const password = 'IsolatePassword1!';

        final bundle = await CryptoService.generateAndEncryptKeysAsync(password);
        final decrypted = await CryptoService.decryptPrivateKeyAsync(
          ciphertextBase64: bundle['encryptedPrivateKey']!,
          password: password,
          saltBase64: bundle['salt']!,
          ivBase64: bundle['iv']!,
        );

        final jsonStr = utf8.decode(decrypted);
        final keyData = json.decode(jsonStr) as Map<String, dynamic>;
        expect(keyData['n'], isNotEmpty);
        expect(keyData['d'], isNotEmpty);
        expect(keyData['p'], isNotEmpty);
        expect(keyData['q'], isNotEmpty);
      });

      test('async re-encrypt produces decryptable ciphertext', () async {
        const password = 'IsolatePassword1!';
        const newPassword = 'NewIsolatePassword1!';

        final bundle = await CryptoService.generateAndEncryptKeysAsync(password);
        final privateKeyBytes = await CryptoService.decryptPrivateKeyAsync(
          ciphertextBase64: bundle['encryptedPrivateKey']!,
          password: password,
          saltBase64: bundle['salt']!,
          ivBase64: bundle['iv']!,
        );

        final reEncrypted = await CryptoService.encryptPrivateKeyAsync(
          privateKeyBytes: privateKeyBytes,
          password: newPassword,
        );
        final decryptedAgain = await CryptoService.decryptPrivateKeyAsync(
          ciphertextBase64: reEncrypted['ciphertext']!,
          password: newPassword,
          saltBase64: reEncrypted['salt']!,
          ivBase64: reEncrypted['iv']!,
        );

        expect(decryptedAgain, equals(privateKeyBytes));
      });

      test('batch decrypt matches isolated single decrypts', () async {
        const password = 'IsolatePassword1!';
        final bundle = await CryptoService.generateAndEncryptKeysAsync(password);
        final privateKeyBytes = await CryptoService.decryptPrivateKeyAsync(
          ciphertextBase64: bundle['encryptedPrivateKey']!,
          password: password,
          saltBase64: bundle['salt']!,
          ivBase64: bundle['iv']!,
        );
        final ciphertexts = List.generate(
          3,
          (i) => CryptoService.encryptWithPublicKey(
            plaintext: 'message-$i',
            publicKeyBase64: bundle['publicKey']!,
          ),
        );

        final plaintexts = await CryptoService.decryptBatchWithPrivateKey(
          ciphertexts: ciphertexts,
          privateKeyBytes: privateKeyBytes,
        );

        expect(plaintexts, equals(['message-0', 'message-1', 'message-2']));
      });

      test('batch decrypt isolates corrupt ciphertexts as null', () async {
        const password = 'IsolatePassword1!';
        final bundle = await CryptoService.generateAndEncryptKeysAsync(password);
        final privateKeyBytes = await CryptoService.decryptPrivateKeyAsync(
          ciphertextBase64: bundle['encryptedPrivateKey']!,
          password: password,
          saltBase64: bundle['salt']!,
          ivBase64: bundle['iv']!,
        );

        final plaintexts = await CryptoService.decryptBatchWithPrivateKey(
          ciphertexts: ['not-base64!!', ''],
          privateKeyBytes: privateKeyBytes,
        );

        expect(plaintexts, equals([null, null]));
      });
    });

    group('media hybrid encryption (F-05)', () {
      Future<_Identity> identityFor(String password) async {
        final bundle = await CryptoService.generateAndEncryptKeysAsync(password);
        final private = await CryptoService.decryptPrivateKeyAsync(
          ciphertextBase64: bundle['encryptedPrivateKey']!,
          password: password,
          saltBase64: bundle['salt']!,
          ivBase64: bundle['iv']!,
        );
        return _Identity(bundle['publicKey']!, private);
      }

      final plaintext = Uint8List.fromList(
        List<int>.generate(1024, (i) => i % 251),
      );

      test('owner, participant, and admin can all open the same blob', () async {
        final owner = await identityFor('owner-password');
        final participant = await identityFor('participant-password');
        final admin = await identityFor('admin-password');

        final envelope = await MediaCrypto.buildMediaEnvelope(
          plaintext: plaintext,
          ownerPublicKey: owner.publicKey,
          participantPublicKey: participant.publicKey,
          adminPublicKey: admin.publicKey,
        );

        final viaOwner = await MediaCrypto.decryptMedia(
          ciphertextBase64: envelope['ciphertextBase64']!,
          ivBase64: envelope['ivBase64']!,
          contentHash: envelope['contentHash']!,
          keyOwner: envelope['keyOwner']!,
          keyParticipant: envelope['keyParticipant']!,
          privateKeyBytes: owner.privateKey,
        );
        expect(viaOwner, isNotNull);
        expect(viaOwner, equals(plaintext));

        // The admin wrap is opened with the admin private key directly, since
        // admin decrypts happen in the browser, never on this device.
        final adminAesKey = CryptoService.decryptBytesWithPrivateKey(
          ciphertextBase64: envelope['keyAdmin']!,
          privateKeyBytes: admin.privateKey,
        );
        final viaAdmin = MediaCrypto.decryptBytes(
          ciphertext: base64Decode(envelope['ciphertextBase64']!),
          key: adminAesKey,
          iv: base64Decode(envelope['ivBase64']!),
        );
        expect(viaAdmin, equals(plaintext));
      });

      test('a non-participant cannot unwrap either key envelope', () async {
        final owner = await identityFor('owner-password');
        final participant = await identityFor('participant-password');
        final admin = await identityFor('admin-password');
        final stranger = await identityFor('stranger-password');

        final envelope = await MediaCrypto.buildMediaEnvelope(
          plaintext: plaintext,
          ownerPublicKey: owner.publicKey,
          participantPublicKey: participant.publicKey,
          adminPublicKey: admin.publicKey,
        );

        await expectLater(
          MediaCrypto.decryptMedia(
            ciphertextBase64: envelope['ciphertextBase64']!,
            ivBase64: envelope['ivBase64']!,
            contentHash: envelope['contentHash']!,
            keyOwner: envelope['keyOwner']!,
            keyParticipant: envelope['keyParticipant']!,
            privateKeyBytes: stranger.privateKey,
          ),
          throwsStateError,
        );
      });

      test('a tampered content hash fails the integrity check', () async {
        final owner = await identityFor('owner-password');
        final participant = await identityFor('participant-password');
        final admin = await identityFor('admin-password');

        final envelope = await MediaCrypto.buildMediaEnvelope(
          plaintext: plaintext,
          ownerPublicKey: owner.publicKey,
          participantPublicKey: participant.publicKey,
          adminPublicKey: admin.publicKey,
        );

        final hash = envelope['contentHash']!;
        final flipped = hash.codeUnitAt(5) == 0x31 ? '2' : '1';
        final tamperedHash = hash.replaceRange(5, 6, flipped);
        final result = await MediaCrypto.decryptMedia(
          ciphertextBase64: envelope['ciphertextBase64']!,
          ivBase64: envelope['ivBase64']!,
          contentHash: tamperedHash,
          keyOwner: envelope['keyOwner']!,
          keyParticipant: envelope['keyParticipant']!,
          privateKeyBytes: owner.privateKey,
        );
        expect(result, isNull);
      });
    });
  });
}

