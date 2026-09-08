import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart';
import 'package:yack/logic/services/auth/cryptoService.dart';

/// F-05: hybrid encryption for media blobs.
///
/// Each upload generates a fresh random AES-256 key and a 96-bit nonce. The
/// plaintext bytes are encrypted with AES-256-GCM (the auth tag is appended to
/// the ciphertext, matching the app's private-key format), and the AES key is
/// RSA-OAEP-SHA256 wrapped for three recipients: the uploader, the other
/// contract party, and the platform admin review key. Only the ciphertext is
/// ever uploaded, so the Cloudinary blob holds no recoverable plaintext and
/// no server-side decryption key exists.
///
/// The CPU-heavy work (AES over multi-megabyte blobs plus RSA wraps) runs on a
/// background isolate so the UI isolate never freezes (F-19 pattern).
class MediaCrypto {
  MediaCrypto._();

  static const int _aesKeyLength = 32;
  static const int _nonceLength = 12;

  static Uint8List _randomBytes(int length) {
    final rand = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rand.nextInt(256)));
  }

  static Uint8List generateAesKey() => _randomBytes(_aesKeyLength);

  static Uint8List generateNonce() => _randomBytes(_nonceLength);

  static Uint8List encryptBytes({
    required Uint8List plaintext,
    required Uint8List key,
    required Uint8List iv,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    return cipher.process(plaintext);
  }

  static Uint8List decryptBytes({
    required Uint8List ciphertext,
    required Uint8List key,
    required Uint8List iv,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    return cipher.process(ciphertext);
  }

  /// Builds the full encrypted-media payload on a background isolate.
  /// Returns the wire-ready fields consumed by the backend upload endpoints.
  static Future<Map<String, String>> buildMediaEnvelope({
    required Uint8List plaintext,
    required String ownerPublicKey,
    required String participantPublicKey,
    required String adminPublicKey,
  }) {
    return Isolate.run(() {
      final key = generateAesKey();
      final iv = generateNonce();
      final ciphertext = encryptBytes(plaintext: plaintext, key: key, iv: iv);

      return {
        'ciphertextBase64': base64Encode(ciphertext),
        'ivBase64': base64Encode(iv),
        'contentHash': crypto.sha256.convert(plaintext).toString(),
        'keyOwner': CryptoService.encryptBytesWithPublicKey(
          plaintext: key,
          publicKeyBase64: ownerPublicKey,
        ),
        'keyParticipant': CryptoService.encryptBytesWithPublicKey(
          plaintext: key,
          publicKeyBase64: participantPublicKey,
        ),
        'keyAdmin': CryptoService.encryptBytesWithPublicKey(
          plaintext: key,
          publicKeyBase64: adminPublicKey,
        ),
      };
    });
  }

  /// Decrypts a fetched media blob on a background isolate. Tries the owner
  /// key-wrap first, then the participant wrap (one of the two matches this
  /// device's private key). Returns `null` when the plaintext does not match
  /// its stored SHA-256 (integrity failure); throws when neither envelope can
  /// be unwrapped or the GCM tag is invalid.
  static Future<Uint8List?> decryptMedia({
    required String ciphertextBase64,
    required String ivBase64,
    required String contentHash,
    required String keyOwner,
    required String keyParticipant,
    required Uint8List privateKeyBytes,
  }) {
    return Isolate.run(() {
      final iv = base64Decode(ivBase64);
      final ciphertext = base64Decode(ciphertextBase64);

      Uint8List? key;
      for (final wrap in [keyOwner, keyParticipant]) {
        if (wrap.isEmpty) continue;
        try {
          final candidate = CryptoService.decryptBytesWithPrivateKey(
            ciphertextBase64: wrap,
            privateKeyBytes: privateKeyBytes,
          );
          if (candidate.length == _aesKeyLength) {
            key = candidate;
            break;
          }
        } catch (_) {
          // Not the envelope this device can open; try the next one.
        }
      }
      if (key == null) {
        throw StateError('No decryptable key envelope for this device');
      }

      final plaintext = decryptBytes(ciphertext: ciphertext, key: key, iv: iv);
      final digest = crypto.sha256.convert(plaintext).toString();
      if (contentHash.isNotEmpty && digest != contentHash) {
        return null;
      }
      return plaintext;
    });
  }
}