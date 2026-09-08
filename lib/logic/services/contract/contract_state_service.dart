import 'package:yack/logic/services/network/http_handler.dart';
import 'package:yack/logic/services/auth/cryptoService.dart';

class ContractStateService {
  ContractStateService({HttpHandler? httpHandler})
      : _http = httpHandler ?? HttpHandler();

  final HttpHandler _http;
  String? _cachedReviewKey;

  Future<String> _reviewPublicKey() async {
    final cached = _cachedReviewKey;
    if (cached != null && cached.isNotEmpty) return cached;
    final response = await _http.get('/support/review-key');
    final value = response is Map ? response['publicKey']?.toString() : null;
    if (value == null || value.isEmpty) {
      throw StateError('Review key is unavailable.');
    }
    _cachedReviewKey = value;
    return value;
  }

  Future<String> accept(String contractId) async {
    final response = await _http.post(
      '/contracts/accept',
      body: {'contractId': contractId},
    );
    // The backend may return "completed" when both parties have agreed.
    // Persist the authoritative status, falling back to "accepted".
    if (response is Map) {
      final status = response['status']?.toString();
      if (status != null && status.isNotEmpty) return status;
    }
    return 'accepted';
  }

  Future<String> dispute(String contractId, {String? reason}) async {
    final body = {'contractId': contractId};
    final normalized = reason?.trim() ?? '';
    if (normalized.isNotEmpty) {
      // F-12: the reason is wrapped in an RSA-OAEP envelope for the admin
      // review key so it never travels or persists in plaintext. The backend
      // stores only the ciphertext and keeps it out of /contracts/list.
      final reviewKey = await _reviewPublicKey();
      body['encryptedReason'] = CryptoService.encryptWithPublicKey(
        plaintext: normalized,
        publicKeyBase64: reviewKey,
      );
    }
    final response = await _http.post('/contracts/dispute', body: body);
    if (response is Map) {
      final status = response['status']?.toString();
      if (status != null && status.isNotEmpty) return status;
    }
    return 'disputed';
  }
}

