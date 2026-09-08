import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:yack/data/db/models/contract.dart';
import 'package:yack/data/db/models/message.dart';
import 'package:yack/logic/services/auth/cryptoService.dart';
import 'package:yack/logic/services/auth/decrypted_key_cache.dart';
import 'package:yack/logic/services/network/http_handler.dart';

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.senderType,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String senderType;
  final String content;
  final DateTime createdAt;

  bool get isFromSupport => senderType == 'admin';
}

class SupportConversation {
  const SupportConversation({
    required this.id,
    required this.status,
    required this.reviewAccessGranted,
    required this.messages,
  });

  final String id;
  final String status;
  final bool reviewAccessGranted;
  final List<SupportMessage> messages;
}

class SupportService {
  SupportService({HttpHandler? httpHandler})
    : _http = httpHandler ?? HttpHandler();

  final HttpHandler _http;
  String? _reviewPublicKey;

  Future<String> _getReviewPublicKey() async {
    final cached = _reviewPublicKey;
    if (cached != null && cached.isNotEmpty) return cached;

    final response = await _http.get('/support/review-key');
    final value = response is Map ? response['publicKey']?.toString() : null;
    if (value == null || value.isEmpty) {
      throw StateError('Support review key is unavailable.');
    }
    _reviewPublicKey = value;
    return value;
  }

  Future<SupportConversation> getConversation(String contractId) async {
    final response = await _http.get(
      '/support/thread?contractId=${Uri.encodeQueryComponent(contractId)}',
    );
    final payload = response is Map ? response['thread'] : null;
    if (payload is! Map) {
      throw StateError('Invalid support conversation response.');
    }

    final privateKey = _requirePrivateKey();
    final rawMessages = payload['messages'] is List
        ? payload['messages'] as List
        : const [];
    final messages = rawMessages.whereType<Map>().map((raw) {
      final ciphertext = raw['content']?.toString() ?? '';
      final plaintext = CryptoService.decryptWithPrivateKey(
        ciphertextBase64: ciphertext,
        privateKeyBytes: privateKey,
      );
      final expectedHash = raw['contentHash']?.toString().toLowerCase() ?? '';
      final actualHash = sha256.convert(utf8.encode(plaintext)).toString();
      if (expectedHash.isNotEmpty && expectedHash != actualHash) {
        throw StateError('A support message failed its integrity check.');
      }
      return SupportMessage(
        id: raw['_id']?.toString() ?? '',
        senderType: raw['senderType']?.toString() ?? 'admin',
        content: plaintext,
        createdAt:
            DateTime.tryParse(raw['createdAt']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
      );
    }).toList();

    return SupportConversation(
      id: payload['_id']?.toString() ?? '',
      status: payload['status']?.toString() ?? 'open',
      reviewAccessGranted: payload['reviewAccessGranted'] == true,
      messages: messages,
    );
  }

  Future<void> sendMessage({
    required String contractId,
    required String plaintext,
  }) async {
    final value = plaintext.trim();
    if (value.isEmpty) return;
    if (!CryptoService.canEncryptWithRsa(value)) {
      throw ArgumentError('Support messages must be shorter.');
    }

    final box = await Hive.openBox('user');
    final userPublicKey = box.get('publicKey')?.toString() ?? '';
    if (userPublicKey.isEmpty) {
      throw StateError('Your account encryption key is unavailable.');
    }
    final adminPublicKey = await _getReviewPublicKey();

    await _http.post(
      '/support/messages',
      body: {
        'contractId': contractId,
        'contentForUser': CryptoService.encryptWithPublicKey(
          plaintext: value,
          publicKeyBase64: userPublicKey,
        ),
        'contentForAdmin': CryptoService.encryptWithPublicKey(
          plaintext: value,
          publicKeyBase64: adminPublicKey,
        ),
        'contentHash': sha256.convert(utf8.encode(value)).toString(),
      },
    );
  }

  Future<void> grantReviewAccess({
    required Contract contract,
    required List<Message> messages,
  }) async {
    final contractId = contract.externalId;
    if (contractId == null || contractId.isEmpty) {
      throw StateError('Contract ID is unavailable.');
    }
    final adminPublicKey = await _getReviewPublicKey();

    String encrypt(String value) {
      if (!CryptoService.canEncryptWithRsa(value)) {
        throw ArgumentError('A case field is too long to share securely.');
      }
      return CryptoService.encryptWithPublicKey(
        plaintext: value,
        publicKeyBase64: adminPublicKey,
      );
    }

    await _http.post(
      '/support/review-access',
      body: {
        'contractId': contractId,
        'titleForAdmin': encrypt(contract.title),
        'descriptionForAdmin': encrypt(contract.description),
        'priceForAdmin': encrypt(contract.price),
        'messages': messages
            .map(
              (message) => {
                'sourceMessageId': message.externalId,
                'senderId': message.senderId,
                'senderName': [message.senderFirstName, message.senderLastName]
                    .whereType<String>()
                    .where((part) => part.isNotEmpty)
                    .join(' '),
                'contentForAdmin': encrypt(message.content),
                'contentHash':
                    message.contentHash ??
                    sha256.convert(utf8.encode(message.content)).toString(),
                'createdAt': message.createdAt.toUtc().toIso8601String(),
              },
            )
            .toList(),
      },
    );
  }

  Uint8List _requirePrivateKey() {
    final key = DecryptedKeyCache.value;
    if (key == null) {
      throw StateError('Unlock your account before opening support chat.');
    }
    return key;
  }
}
