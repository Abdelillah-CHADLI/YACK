import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:mime/mime.dart';
import 'package:yack/logic/services/media/media_crypto.dart';
import 'package:yack/logic/services/network/http_handler.dart';

/// Represents a media entry from the API
/// Maps to backend response structure:
/// {
///   "_id": "...",
///   "who": { "_id": "...", "firstName": "...", "lastName": "..." },
///   "content": "cloudinary/path",
///   "url": "https://cloudinary.com/...",
///   "originalFilename": "proof.png",
///   "mimeType": "image/png",
///   "createdAt": "..."
/// }
class ContractMedia {
  final String id;
  final String senderId;
  final String? senderName;
  final String originalFilename;
  final String content; // Cloudinary path
  final String url; // Full URL for display
  final String? mimeType;
  final int? size;
  final int encryptionVersion;
  final String? iv;
  final String? contentHash;
  final String? keyOwner;
  final String? keyParticipant;
  final String? keyAdmin;
  final DateTime createdAt;

  const ContractMedia({
    required this.id,
    required this.senderId,
    this.senderName,
    required this.originalFilename,
    required this.content,
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

  /// F-05: version 1 records store AES-256-GCM ciphertext plus the RSA-wrapped
  /// AES key envelope. Version 0 records are legacy plaintext Cloudinary URLs.
  bool get isEncrypted => encryptionVersion == 1;

  factory ContractMedia.fromJson(Map<String, dynamic> json) {
    final who = json['who'] ?? json['sender'];
    String senderId;
    String? senderName;

    if (who is Map) {
      senderId = who['_id']?.toString() ?? who['id']?.toString() ?? '';
      final firstName = who['firstName']?.toString() ?? '';
      final lastName = who['lastName']?.toString() ?? '';
      senderName = '$firstName $lastName'.trim();
      if (senderName.isEmpty) senderName = null;
    } else {
      senderId = who?.toString() ?? json['senderId']?.toString() ?? '';
    }

    // Map backend fields: originalFilename, content, url
    final originalFilename =
        json['originalFilename']?.toString() ??
        json['filename']?.toString() ??
        json['name']?.toString() ??
        '';

    final content =
        json['content']?.toString() ?? json['path']?.toString() ?? '';

    final url = json['url']?.toString() ?? content;

    return ContractMedia(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      senderId: senderId,
      senderName: senderName,
      originalFilename: originalFilename,
      content: content,
      url: url,
      mimeType: json['mimeType']?.toString() ?? json['type']?.toString(),
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
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'originalFilename': originalFilename,
      'content': content,
      'url': url,
      'mimeType': mimeType,
      'size': size,
      'encryptionVersion': encryptionVersion,
      'iv': iv,
      'contentHash': contentHash,
      'keyOwner': keyOwner,
      'keyParticipant': keyParticipant,
      'keyAdmin': keyAdmin,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Helper to get display filename
  String get displayFilename =>
      originalFilename.isNotEmpty ? originalFilename : content.split('/').last;
}

class MediaService {
  MediaService({HttpHandler? httpHandler})
    : _http = httpHandler ?? HttpHandler();

  final HttpHandler _http;
  String? _reviewPublicKey;

  /// The platform admin review key, cached per service instance (F-25 pattern).
  Future<String> _getReviewPublicKey() async {
    final cached = _reviewPublicKey;
    if (cached != null && cached.isNotEmpty) return cached;

    final response = await _http.get('/support/review-key');
    final value = response is Map ? response['publicKey']?.toString() : null;
    if (value == null || value.isEmpty) {
      throw StateError('Unable to load the platform encryption key.');
    }
    _reviewPublicKey = value;
    return value;
  }

  /// Store an uploaded media payload and attach metadata to the contract.
  /// POST /media/send
  /// F-05: the file bytes are encrypted with a fresh AES-256-GCM key wrapped
  /// for the uploader, the other contract party, and the admin review key.
  /// Body: { "contractId": "...", "file": { "filename": "...", "buffer": "<ciphertext>", "encryptionVersion": 1, ... } }
  /// Returns: The stored media record
  Future<ContractMedia> send({
    required String contractId,
    required File file,
    String? filename,
    required String otherPartyPublicKey,
  }) async {
    final bytes = await file.readAsBytes();

    final actualFilename =
        filename ?? file.path.split(Platform.pathSeparator).last;
    final mimeType = lookupMimeType(actualFilename, headerBytes: bytes);

    final userBox = await Hive.openBox('user');
    final ownerPublicKey = userBox.get('publicKey')?.toString();
    if (ownerPublicKey == null || ownerPublicKey.isEmpty) {
      throw StateError('Your account encryption key is unavailable.');
    }
    if (otherPartyPublicKey.trim().isEmpty) {
      throw StateError('The other party encryption key is unavailable.');
    }
    final adminPublicKey = await _getReviewPublicKey();

    final envelope = await MediaCrypto.buildMediaEnvelope(
      plaintext: bytes,
      ownerPublicKey: ownerPublicKey,
      participantPublicKey: otherPartyPublicKey,
      adminPublicKey: adminPublicKey,
    );

    final response = await _http.post(
      '/media/send',
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

    return _parseMediaResponse(response);
  }

  /// F-05: download the ciphertext blob and decrypt it for this device.
  /// Returns the plaintext bytes (with the stored SHA-256 verified), or null
  /// if the integrity check fails. Throws when the file is not decryptable.
  Future<Uint8List?> fetchAndDecrypt({
    required ContractMedia media,
    required Uint8List privateKeyBytes,
  }) async {
    if (!media.isEncrypted || media.url.isEmpty) return null;

    final bytes = await _http.fetchBytes(media.url);
    return MediaCrypto.decryptMedia(
      ciphertextBase64: base64Encode(bytes),
      ivBase64: media.iv ?? '',
      contentHash: media.contentHash ?? '',
      keyOwner: media.keyOwner ?? '',
      keyParticipant: media.keyParticipant ?? '',
      privateKeyBytes: privateKeyBytes,
    );
  }

  /// Return all media entries for a contract.
  /// GET /media/all?contractId=...
  /// Paged API responses are walked until `hasMore` is false (F-14).
  Future<List<ContractMedia>> getAll({required String contractId}) async {
    const int pageSize = 100; // backend upper bound
    final all = <ContractMedia>[];
    var offset = 0;
    var hasMore = true;

    while (hasMore) {
      final response = await _http.get(
        '/media/all?contractId=$contractId&limit=$pageSize&offset=$offset',
      );
      final page = _parseMediaList(response);
      all.addAll(page);
      hasMore = _hasMore(response, offset, page.length);
      offset += page.length;
      if (hasMore && page.isEmpty) hasMore = false;
    }

    return all;
  }

  /// Whether the response has another page of media.
  static bool _hasMore(dynamic response, int offset, int pageLength) {
    if (response is! Map) return false;
    final pagination = response['pagination'];
    if (pagination is Map) {
      final explicit = pagination['hasMore'];
      if (explicit is bool) return explicit;
      final total = pagination['total'];
      if (total is int) return offset + pageLength < total;
    }
    return false;
  }

  ContractMedia _parseMediaResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      final media = response['media'] ?? response['data'] ?? response;
      if (media is Map<String, dynamic>) {
        return ContractMedia.fromJson(media);
      }
    }
    throw Exception('Invalid media response');
  }

  List<ContractMedia> _parseMediaList(dynamic response) {
    final List<dynamic> mediaList;

    if (response is Map) {
      mediaList = response['media'] ?? response['data'] ?? [];
    } else if (response is List) {
      mediaList = response;
    } else {
      mediaList = [];
    }

    return mediaList
        .whereType<Map<String, dynamic>>()
        .map((json) => ContractMedia.fromJson(json))
        .toList();
  }
}
