import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:yack/data/repositories/isar_adapter.dart';
import 'package:yack/logic/services/contract/contract_list_service.dart';
import 'package:yack/logic/services/auth/cryptoService.dart';
import 'package:yack/logic/services/auth/decrypted_key_cache.dart';
import 'package:yack/logic/services/debug_logger.dart';

/// Service to sync contracts from backend to local Isar database.
/// Should be called after user authentication/login and after user has unlocked their account.
/// Contracts are stored DECRYPTED in Isar for easy display.
class ContractSyncService {
  ContractSyncService({ContractListService? listService})
    : _listService = listService ?? ContractListService();

  final ContractListService _listService;

  static Future<int>? _activeSync;
  static DateTime? _lastSyncTime;

  /// Whether a sync is currently in progress
  bool get isSyncing => _activeSync != null;

  /// Last successful sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Sync all contracts from backend to Isar.
  /// Uses the process-memory private key set during account unlock.
  /// All contracts are stored DECRYPTED in Isar.
  ///
  /// Returns the number of contracts synced.
  Future<int> syncContracts() {
    final activeSync = _activeSync;
    if (activeSync != null) {
      logDebug('[ContractSyncService] Sync already in progress, awaiting it...');
      return activeSync;
    }

    late final Future<int> operation;
    operation = _performSync().whenComplete(() {
      if (identical(_activeSync, operation)) {
        _activeSync = null;
      }
    });
    _activeSync = operation;
    return operation;
  }

  Future<int> _performSync() async {
    try {
      logDebug('[ContractSyncService] Starting contract sync...');

      // Get the process-memory private key.
      final privateKeyBytes = DecryptedKeyCache.value;

      if (privateKeyBytes == null) {
        logDebug(
          '[ContractSyncService] No decrypted private key found. User must unlock account first.',
        );
        return 0;
      }

      // Fetch contracts from backend
      final contracts = await _listService.list();
      logDebug(
        '[ContractSyncService] Fetched ${contracts.length} contracts from backend',
      );

      if (contracts.isEmpty) {
        _lastSyncTime = DateTime.now();
        return 0;
      }

      // Process each contract - decrypt and store
      int syncedCount = 0;
      for (final contract in contracts) {
        try {
          if (await _decryptAndSave(contract, privateKeyBytes)) {
            syncedCount++;
          }
        } catch (e) {
          logDebug(
            '[ContractSyncService] Failed to sync contract ${contract.id}: $e',
          );
        }
      }

      _lastSyncTime = DateTime.now();
      logDebug(
        '[ContractSyncService] Sync complete. Synced $syncedCount contracts.',
      );

      return syncedCount;
    } catch (e) {
      logDebug('[ContractSyncService] Sync failed: $e');
      rethrow;
    }
  }

  /// Decrypts a single list item with the unlocked key and persists it.
  /// Returns whether the contract was successfully stored.
  Future<bool> _decryptAndSave(
    ContractListItem contract,
    Uint8List privateKeyBytes,
  ) async {
    // Decrypt contract fields using private key
    String title = contract.title;
    String description = contract.description;
    String price = contract.price;

    try {
      title = CryptoService.decryptWithPrivateKey(
        ciphertextBase64: contract.title,
        privateKeyBytes: privateKeyBytes,
      );
    } catch (e) {
      title = 'ERROR';
      logDebug(
        '[ContractSyncService] Failed to decrypt title for ${contract.id}: $e',
      );
      // Keep original value (may be encrypted or empty)
    }

    try {
      description = CryptoService.decryptWithPrivateKey(
        ciphertextBase64: contract.description,
        privateKeyBytes: privateKeyBytes,
      );
    } catch (e) {
      description = 'ERROR';
      logDebug(
        '[ContractSyncService] Failed to decrypt description for ${contract.id}: $e',
      );
    }

    try {
      price = CryptoService.decryptWithPrivateKey(
        ciphertextBase64: contract.price,
        privateKeyBytes: privateKeyBytes,
      );
    } catch (e) {
      price = 'ERROR';
      logDebug(
        '[ContractSyncService] Failed to decrypt price for ${contract.id}: $e',
      );
    }

    // Create item with DECRYPTED values for storage
    final decryptedItem = ContractListItem(
      id: contract.id,
      title: title,
      description: description,
      price: price,
      detailsHash: contract.detailsHash,
      otherUserId: contract.otherUserId,
      otherUserName: contract.otherUserName,
      otherUserPublicKey: contract.otherUserPublicKey,
      isUserA: contract.isUserA,
      status: contract.status,
      userASigned: contract.userASigned,
      userBSigned: contract.userBSigned,
      agreedUserA: contract.agreedUserA,
      agreedUserB: contract.agreedUserB,
      disputedUserA: contract.disputedUserA,
      disputedUserB: contract.disputedUserB,
      disputeReasonUserA: contract.disputeReasonUserA,
      disputeReasonUserB: contract.disputeReasonUserB,
      disputedAtUserA: contract.disputedAtUserA,
      disputedAtUserB: contract.disputedAtUserB,
      disputeState: contract.disputeState,
      resolutionOutcome: contract.resolutionOutcome,
      resolutionNote: contract.resolutionNote,
      resolvedAt: contract.resolvedAt,
      resolvedBy: contract.resolvedBy,
      hash: contract.hash,
      createdAt: contract.createdAt,
      updatedAt: contract.updatedAt,
    );

    final currentUserBox = await Hive.openBox('user');
    final currentUserId = currentUserBox.get('userId')?.toString();
    await saveContractFromListItem(
      decryptedItem,
      currentUserId: currentUserId,
    );
    return true;
  }

  /// Sync a single contract by ID (F-51): fetches just that contract instead
  /// of re-running the whole list.
  Future<bool> syncSingleContract(String contractId) async {
    try {
      final privateKeyBytes = DecryptedKeyCache.value;
      if (privateKeyBytes == null) {
        logDebug(
          '[ContractSyncService] No decrypted private key found. User must unlock account first.',
        );
        return false;
      }

      final contract = await _listService.fetch(contractId);
      if (contract == null) {
        logDebug(
          '[ContractSyncService] Contract $contractId not found for this user.',
        );
        return false;
      }

      final synced = await _decryptAndSave(contract, privateKeyBytes);
      if (synced) {
        _lastSyncTime = DateTime.now();
        logDebug(
          '[ContractSyncService] Synced contract $contractId.',
        );
      }
      return synced;
    } catch (e) {
      logDebug(
        '[ContractSyncService] Failed to sync single contract $contractId: $e',
      );
      return false;
    }
  }
}
