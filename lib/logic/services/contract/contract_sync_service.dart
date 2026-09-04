import 'package:hive/hive.dart';
import 'package:yack/data/repositories/isar_adapter.dart';
import 'package:yack/logic/services/contract/contract_list_service.dart';
import 'package:yack/logic/services/auth/cryptoService.dart';
import 'package:yack/logic/services/auth/decrypted_key_cache.dart';

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
      print('[ContractSyncService] Sync already in progress, awaiting it...');
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
      print('[ContractSyncService] Starting contract sync...');

      // Get current user ID and the process-memory private key.
      final userBox = await Hive.openBox('user');
      final currentUserId = userBox.get('userId')?.toString();

      final privateKeyBytes = DecryptedKeyCache.value;

      if (privateKeyBytes == null) {
        print(
          '[ContractSyncService] No decrypted private key found. User must unlock account first.',
        );
        return 0;
      }

      // Fetch contracts from backend
      final contracts = await _listService.list();
      print(
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
            print(
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
            print(
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
            print(
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
            hash: contract.hash,
            createdAt: contract.createdAt,
            updatedAt: contract.updatedAt,
          );

          await saveContractFromListItem(
            decryptedItem,
            currentUserId: currentUserId,
          );
          syncedCount++;
        } catch (e) {
          print(
            '[ContractSyncService] Failed to sync contract ${contract.id}: $e',
          );
        }
      }

      _lastSyncTime = DateTime.now();
      print(
        '[ContractSyncService] Sync complete. Synced $syncedCount contracts.',
      );

      return syncedCount;
    } catch (e) {
      print('[ContractSyncService] Sync failed: $e');
      rethrow;
    }
  }

  /// Sync a single contract by ID
  Future<bool> syncSingleContract(String contractId) async {
    try {
      // For now, we sync all contracts
      // TODO: Add endpoint to fetch single contract
      await syncContracts();
      return true;
    } catch (e) {
      print(
        '[ContractSyncService] Failed to sync single contract $contractId: $e',
      );
      return false;
    }
  }
}
