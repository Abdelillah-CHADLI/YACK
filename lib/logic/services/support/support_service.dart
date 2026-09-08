import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:mime/mime.dart';
import 'package:yack/data/db/models/contract.dart';
import 'package:yack/data/db/models/message.dart';
import 'package:yack/logic/services/auth/cryptoService.dart';
import 'package:yack/logic/services/auth/decrypted_key_cache.dart';
import 'package:yack/logic/services/media/media_crypto.dart';
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

class SupportAttachment {
  const SupportAttachment({
    required this.id,
    this.whoId,
    required this.originalFilename,
    required this.url,
    this.mimeType,
    this.size,
    this.encryptionVersion = 0,
    this.iv,
    this.contentHash,
    this.keyOwner,
    this.keyParticipant,
    this.keyAdmin,
    required this.createdAt,
  });

  final String id;
  final String? whoId;
  final String originalFilename;
  final String url;
  final String? mimeType;
  final int? size;
  final int encryptionVersion;
  final String? iv;
  final String? contentHash;
  final String? keyOwner;
  final String? keyParticipant;
  final String? keyAdmin;
  final DateTime createdAt;

  bool get isImage => (mimeType ?? '').startsWith('image/');

  /// F-05: version 1 attachments are AES-256-GCM ciphertext; version 0 are
  /// legacy plaintext Cloudinary URLs.
  bool get isEncrypted => encryptionVersion == 1;

  /// F-05: download and decrypt this attachment for the current device.
  /// Returns null for integrity failures; throws when undecryptable or when
  /// the account is still locked.
  Future<Uint8List?> downloadDecryptedBytes() async {
    if (!isEncrypted || url.isEmpty) return null;
    final key = DecryptedKeyCache.value;
    if (key == null) {
      throw StateError('Unlock your account before opening attachments.');
    }
    final bytes = await HttpHandler().fetchBytes(url);
    return MediaCrypto.decryptMedia(
      ciphertextBase64: base64Encode(bytes),
      ivBase64: iv ?? '',
      contentHash: contentHash ?? '',
      keyOwner: keyOwner ?? '',
      keyParticipant: keyParticipant ?? '',
      privateKeyBytes: key,
    );
  }

  factory SupportAttachment.fromJson(Map<String, dynamic> json) {
    return SupportAttachment(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      whoId: json['who']?.toString(),
      originalFilename: json['originalFilename']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      mimeType: json['mimeType']?.toString(),
      size: json['size'] is int ? json['size'] as int : null,
      encryptionVersion:
          json['encryptionVersion'] is int
              ? json['encryptionVersion'] as int
              : 0,
      iv: json['iv']?.toString(),
      contentHash: json['contentHash']?.toString(),
      keyOwner: json['keyOwner']?.toString(),
      keyParticipant: json['keyParticipant']?.toString(),
      keyAdmin: json['keyAdmin']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
    );
  }
}

class SupportConversation {
  const SupportConversation({
    required this.id,
    required this.status,
    required this.reviewAccessGranted,
    required this.messages,
    this.attachments = const [],
  });

  final String id;
  final String status;
  final bool reviewAccessGranted;
  final List<SupportMessage> messages;
  final List<SupportAttachment> attachments;
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
      attachments: _parseAttachments(payload['attachments']),
    );
  }

  List<SupportAttachment> _parseAttachments(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((entry) {
      final json = Map<String, dynamic>.from(entry);
      return SupportAttachment.fromJson(json);
    }).toList();
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

  Future<void> uploadAttachment({
    required String contractId,
    required File file,
    String? filename,
    required String otherPartyPublicKey,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('The selected file is empty.');
    }
    final actualFilename =
        filename ?? file.path.split(Platform.pathSeparator).last;
    final mimeType = lookupMimeType(actualFilename, headerBytes: bytes);

    // F-05: encrypt the bytes client-side, wrapping the AES key for the
    // uploader, the other contract party, and the admin review key. Only the
    // ciphertext reaches the backend/Cloudinary.
    final userBox = await Hive.openBox('user');
    final ownerPublicKey = userBox.get('publicKey')?.toString() ?? '';
    if (ownerPublicKey.isEmpty) {
      throw StateError('Your account encryption key is unavailable.');
    }
    final adminPublicKey = await _getReviewPublicKey();
    final envelope = await MediaCrypto.buildMediaEnvelope(
      plaintext: bytes,
      ownerPublicKey: ownerPublicKey,
      participantPublicKey: otherPartyPublicKey,
      adminPublicKey: adminPublicKey,
    );

    await _http.post(
      '/support/attachments',
      body: {
        'contractId': contractId,
        'file': {
          'filename': actualFilename,
          'buffer': envelope['ciphertextBase64'],
          'mimeType': mimeType,
          'size': bytes.length,
          'encryptionVersion': 1,
          'encryption': 'AES-256-GCM',
          'iv': envelope['ivBase64'],
          'contentHash': envelope['contentHash'],
          'keyOwner': envelope['keyOwner'],
          'keyParticipant': envelope['keyParticipant'],
          'keyAdmin': envelope['keyAdmin'],
        },
      },
    );
  }

  Future<List<SupportAttachment>> getAttachments(String contractId) async {
    final response = await _http.get(
      '/support/attachments?contractId=${Uri.encodeQueryComponent(contractId)}',
    );
    return _parseAttachments(
      response is Map ? response['attachments'] : null,
    );
  }

  Future<void> deleteAttachment({
    required String contractId,
    required String attachmentId,
  }) async {
    await _http.delete(
      '/support/attachments/$attachmentId?contractId=${Uri.encodeQueryComponent(contractId)}',
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
