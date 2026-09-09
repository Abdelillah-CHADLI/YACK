import 'package:yack/logic/services/network/http_handler.dart';

/// Represents a contract from the list endpoint with caller's encrypted fields
class ContractListItem {
  final String id;
  final String title;        // Encrypted for caller (decrypted locally)
  final String description;  // Encrypted for caller (decrypted locally)
  final String price;        // Encrypted for caller (decrypted locally)
  final String? detailsHash;

  // Other user info (the party you're contracting with)
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserPublicKey;

  // Whether the caller is userA (creator) or userB (joiner)
  final bool isUserA;

  final String status;

  // Signature status
  final bool userASigned;
  final bool userBSigned;

  // Agreement status
  final bool agreedUserA;
  final bool agreedUserB;

  // Dispute status
  final bool disputedUserA;
  final bool disputedUserB;

  // F-32: per-party reasons/timestamps and full dispute/resolution state
  final String? disputeReasonUserA;
  final String? disputeReasonUserB;
  final DateTime? disputedAtUserA;
  final DateTime? disputedAtUserB;
  final String? disputeState;
  final String? resolutionOutcome;
  final String? resolutionNote;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  final String? hash;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ContractListItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.detailsHash,
    this.otherUserId,
    this.otherUserName,
    this.otherUserPublicKey,
    this.isUserA = true,
    required this.status,
    this.userASigned = false,
    this.userBSigned = false,
    this.agreedUserA = false,
    this.agreedUserB = false,
    this.disputedUserA = false,
    this.disputedUserB = false,
    this.disputeReasonUserA,
    this.disputeReasonUserB,
    this.disputedAtUserA,
    this.disputedAtUserB,
    this.disputeState,
    this.resolutionOutcome,
    this.resolutionNote,
    this.resolvedAt,
    this.resolvedBy,
    this.hash,
    this.createdAt,
    this.updatedAt,
  });

  factory ContractListItem.fromJson(Map<String, dynamic> json) {
    // Extract other user info from nested object
    final otherUser = json['otherUser'];
    String? otherUserId;
    String? otherUserName;
    String? otherUserPublicKey;

    if (otherUser is Map) {
      otherUserId = otherUser['_id']?.toString();
      final firstName = otherUser['firstName']?.toString() ?? '';
      final lastName = otherUser['lastName']?.toString() ?? '';
      otherUserName = '$firstName $lastName'.trim();
      if (otherUserName.isEmpty) otherUserName = null;
      otherUserPublicKey = otherUser['publicKey']?.toString();
    }

    return ContractListItem(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      detailsHash: json['detailsHash']?.toString(),
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      otherUserPublicKey: otherUserPublicKey,
      isUserA: json['isUserA'] == true,
      status: json['status']?.toString() ?? 'pending',
      userASigned: json['userASign'] == true || json['userASigned'] == true,
      userBSigned: json['userBSign'] == true || json['userBSigned'] == true,
      agreedUserA: json['agreedUserA'] == true,
      agreedUserB: json['agreedUserB'] == true,
      disputedUserA: json['disputedUserA'] == true,
      disputedUserB: json['disputedUserB'] == true,
      disputeReasonUserA: json['disputeReasonUserA']?.toString(),
      disputeReasonUserB: json['disputeReasonUserB']?.toString(),
      disputedAtUserA: _parseDate(json['disputedAtUserA']),
      disputedAtUserB: _parseDate(json['disputedAtUserB']),
      disputeState: json['disputeState']?.toString(),
      resolutionOutcome: json['resolutionOutcome']?.toString(),
      resolutionNote: json['resolutionNote']?.toString(),
      resolvedAt: _parseDate(json['resolvedAt']),
      resolvedBy: json['resolvedBy']?.toString(),
      hash: json['hash']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
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
      'title': title,
      'description': description,
      'price': price,
      'detailsHash': detailsHash,
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'otherUserPublicKey': otherUserPublicKey,
      'isUserA': isUserA,
      'status': status,
      'userASigned': userASigned,
      'userBSigned': userBSigned,
      'agreedUserA': agreedUserA,
      'agreedUserB': agreedUserB,
      'disputedUserA': disputedUserA,
      'disputedUserB': disputedUserB,
      'disputeReasonUserA': disputeReasonUserA,
      'disputeReasonUserB': disputeReasonUserB,
      'disputedAtUserA': disputedAtUserA?.toIso8601String(),
      'disputedAtUserB': disputedAtUserB?.toIso8601String(),
      'disputeState': disputeState,
      'resolutionOutcome': resolutionOutcome,
      'resolutionNote': resolutionNote,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolvedBy': resolvedBy,
      'hash': hash,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class ContractListService {
  ContractListService({HttpHandler? httpHandler})
      : _http = httpHandler ?? HttpHandler();

  final HttpHandler _http;

  /// Fetch all contracts involving the caller.
  /// Returns only caller's encrypted fields (title, description, price).
  /// Paged API responses are walked until `hasMore` is false (F-14).
  Future<List<ContractListItem>> list() async {
    const int pageSize = 100; // backend upper bound
    final contracts = <ContractListItem>[];
    var offset = 0;
    var hasMore = true;

    while (hasMore) {
      final response = await _http.get(
        '/contracts/list?limit=$pageSize&offset=$offset',
      );
      final page = _parseContractList(response);
      contracts.addAll(page);
      hasMore = _hasMore(response, offset, page.length);
      offset += page.length;
      // Guard against a misbehaving server that reports hasMore forever.
      if (hasMore && page.isEmpty) hasMore = false;
    }

    return contracts;
  }

  /// Whether the response has another page of contracts.
  static bool _hasMore(dynamic response, int offset, int pageLength) {
    if (response is! Map) return false;
    final pagination = response['pagination'];
    if (pagination is Map) {
      final explicit = pagination['hasMore'];
      if (explicit is bool) return explicit;
      final total = pagination['total'];
      if (total is int) return offset + pageLength < total;
    }
    // Legacy/unpaginated responses contain the whole list in one page.
    return false;
  }

  /// F-51: fetch a single contract by id (participant-gated on the backend).
  /// Returns null when the caller is not a participant or the id is malformed.
  Future<ContractListItem?> fetch(String contractId) async {
    final response = await _http.get('/contracts/$contractId');
    if (response is Map && response['contract'] is Map) {
      return ContractListItem.fromJson(response['contract'] as Map<String, dynamic>);
    }
    return null;
  }

  List<ContractListItem> _parseContractList(dynamic response) {
    final List<dynamic> contracts;

    if (response is List) {
      contracts = response;
    } else if (response is Map) {
      contracts = response['contracts'] ?? response['data'] ?? [];
    } else {
      contracts = [];
    }

    return contracts
        .whereType<Map<String, dynamic>>()
        .map((json) => ContractListItem.fromJson(json))
        .toList();
  }
}

