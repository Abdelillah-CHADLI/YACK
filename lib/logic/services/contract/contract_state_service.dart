import 'package:yack/logic/services/network/http_handler.dart';

class ContractStateService {
  ContractStateService({HttpHandler? httpHandler})
      : _http = httpHandler ?? HttpHandler();

  final HttpHandler _http;

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
    if (reason != null && reason.isNotEmpty) {
      body['reason'] = reason;
    }
    final response = await _http.post('/contracts/dispute', body: body);
    if (response is Map) {
      final status = response['status']?.toString();
      if (status != null && status.isNotEmpty) return status;
    }
    return 'disputed';
  }
}

