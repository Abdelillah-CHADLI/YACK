import 'package:yack/data/repositories/isar_adapter.dart';
import 'package:yack/logic/services/auth/cryptoService.dart';
import 'package:yack/logic/services/auth/decrypted_key_cache.dart';
import 'package:yack/logic/services/debug_logger.dart';
import 'package:yack/logic/services/message/message_service.dart';

/// Service to sync messages from backend to local Isar database.
/// Messages are stored DECRYPTED in Isar for easy display.
class MessageSyncService {
  MessageSyncService({MessageService? messageService})
    : _messageService = messageService ?? MessageService();

  final MessageService _messageService;

  static final Map<String, Future<int>> _activeSyncs = {};
  static DateTime? _lastSyncTime;

  /// Whether a sync is currently in progress
  bool get isSyncing => _activeSyncs.isNotEmpty;

  /// Last successful sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Sync all messages for a specific contract from backend to Isar.
  /// Uses the process-memory private key set during account unlock.
  /// All messages are stored DECRYPTED in Isar.
  ///
  /// Returns the number of messages synced.
  Future<int> syncMessagesForContract({
    required String externalContractId,
    required int localContractId,
    int? limit,
  }) {
    final syncKey = '$externalContractId:$localContractId:${limit ?? 'all'}';
    final activeSync = _activeSyncs[syncKey];
    if (activeSync != null) {
      logDebug(
        '[MessageSyncService] Matching sync already in progress, awaiting it...',
      );
      return activeSync;
    }

    late final Future<int> operation;
    operation =
        _performSync(
          externalContractId: externalContractId,
          localContractId: localContractId,
          limit: limit,
        ).whenComplete(() {
          if (identical(_activeSyncs[syncKey], operation)) {
            _activeSyncs.remove(syncKey);
          }
        });
    _activeSyncs[syncKey] = operation;
    return operation;
  }

  Future<int> _performSync({
    required String externalContractId,
    required int localContractId,
    int? limit,
  }) async {
    try {
      logDebug(
        '[MessageSyncService] Starting message sync for contract $externalContractId...',
      );

      final privateKeyBytes = DecryptedKeyCache.value;

      if (privateKeyBytes == null) {
        logDebug(
          '[MessageSyncService] No decrypted private key found. User must unlock account first.',
        );
        return 0;
      }

      // Fetch messages from backend
      final messages = await _messageService.getAll(
        contractId: externalContractId,
        limit: limit,
      );
      logDebug(
        '[MessageSyncService] Fetched ${messages.length} messages from backend',
      );

      if (messages.isEmpty) {
        _lastSyncTime = DateTime.now();
        return 0;
      }

      // F-20: skip rows already persisted so previously decrypted messages are
      // never re-decrypted, and decrypt the pending batch on a background
      // isolate so long chats never jank the UI.
      final knownIds = await getKnownMessageExternalIds(
        contractId: localContractId,
      );
      final pending = messages
          .where((msg) => !knownIds.contains(msg.id))
          .toList();
      if (pending.isEmpty) {
        _lastSyncTime = DateTime.now();
        return 0;
      }

      final plaintexts = await CryptoService.decryptBatchWithPrivateKey(
        ciphertexts: pending.map((msg) => msg.content).toList(),
        privateKeyBytes: privateKeyBytes,
      );

      // Persist each message to Isar
      int syncedCount = 0;
      for (var i = 0; i < pending.length; i++) {
        try {
          final msg = pending[i];
          final decryptedContent =
              plaintexts[i] ?? '[Unable to decrypt message]';
          if (plaintexts[i] == null) {
            logDebug(
              '[MessageSyncService] Failed to decrypt message ${msg.id}',
            );
          }

          await saveMessageToIsar(
            contractId: localContractId,
            externalId: msg.id,
            senderId: msg.senderId,
            senderFirstName: msg.senderFirstName,
            senderLastName: msg.senderLastName,
            content: decryptedContent,
            contentHash: msg.contentHash,
            createdAt: msg.createdAt,
          );
          syncedCount++;
        } catch (e) {
          logDebug('[MessageSyncService] Failed to sync message ${pending[i].id}: $e');
        }
      }

      _lastSyncTime = DateTime.now();
      logDebug(
        '[MessageSyncService] Sync complete. Synced $syncedCount messages.',
      );

      return syncedCount;
    } catch (e) {
      logDebug('[MessageSyncService] Sync failed: $e');
      rethrow;
    }
  }

  /// Sync messages for all contracts
  Future<int> syncAllMessages() async {
    try {
      final contracts = await getAllContractsFromIsar();
      int totalSynced = 0;

      for (final contract in contracts) {
        if (contract.externalId != null) {
          final count = await syncMessagesForContract(
            externalContractId: contract.externalId!,
            localContractId: contract.id,
          );
          totalSynced += count;
        }
      }

      return totalSynced;
    } catch (e) {
      logDebug('[MessageSyncService] Failed to sync all messages: $e');
      rethrow;
    }
  }
}
