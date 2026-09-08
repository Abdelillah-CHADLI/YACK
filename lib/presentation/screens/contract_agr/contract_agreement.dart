import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';
import 'package:yack/data/db/models/contract.dart';
import 'package:yack/data/db/models/message.dart';
import 'package:yack/data/db/models/mediaFile.dart';
import 'package:yack/data/repositories/isar_adapter.dart';
import 'package:yack/logic/cubits/contract/contract_state_cubit.dart';
import 'package:yack/logic/cubits/message/message_cubit.dart';
import 'package:yack/logic/cubits/message/message_state.dart';
import 'package:yack/logic/cubits/media/media_cubit.dart';
import 'package:yack/logic/cubits/media/media_state.dart';
import 'package:yack/logic/services/auth/cryptoService.dart';
import 'package:yack/logic/services/auth/decrypted_key_cache.dart';
import 'package:yack/logic/services/contract/contract_sync_service.dart';
import 'package:yack/logic/services/notification/contract_notification_handler.dart';
import 'package:yack/logic/services/notification/notification_service.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/main.dart';
import 'package:yack/presentation/theme/theme.dart';

class ContractAgreement extends StatefulWidget {
  final int contractId;
  const ContractAgreement({super.key, required this.contractId});

  @override
  State<ContractAgreement> createState() => _ContractAgreementState();
}

class _DisputeDialog extends StatefulWidget {
  const _DisputeDialog();

  @override
  State<_DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<_DisputeDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(TranslationHandler.get('dispute_contract')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(TranslationHandler.get('dispute_contract_warning')),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              labelText: TranslationHandler.get('dispute_reason_optional'),
            ),
            maxLines: 3,
            maxLength: 190,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(TranslationHandler.get('cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () =>
              Navigator.pop(context, _reasonController.text.trim()),
          child: Text(TranslationHandler.get('dispute')),
        ),
      ],
    );
  }
}

class _ContractAgreementState extends State<ContractAgreement> {
  static const int _maxAttachmentBytes = 6 * 1024 * 1024;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final ContractSyncService _contractSyncService = ContractSyncService();

  String _currentUserId = '';
  String? _externalContractId;
  Uint8List? _privateKeyBytes;
  String? _otherUserPublicKey;

  StreamSubscription<ContractNotificationEvent>? _notificationSubscription;
  bool _isLoading = true;
  bool _isSendingMessage = false;
  bool _isUploadingMedia = false;
  bool _isUpdatingContract = false;

  @override
  void initState() {
    super.initState();
    _loadContractAndKeys();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  /// Load contract from Isar and user keys from Hive
  Future<void> _loadContractAndKeys() async {
    try {
      // Load contract from Isar
      final contract = await isar.contracts.get(widget.contractId);
      if (contract == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _externalContractId = contract.externalId;

      // Get current user ID from Hive
      final userBox = await Hive.openBox('user');
      _currentUserId = userBox.get('userId')?.toString() ?? '';

      // Read the private key from the process-memory unlock cache.
      _privateKeyBytes = DecryptedKeyCache.value;

      // Determine other user's public key
      final isUserA = contract.userAId == _currentUserId;
      _otherUserPublicKey = isUserA
          ? contract.userBPublicKey
          : contract.userAPublicKey;

      if (mounted) setState(() => _isLoading = false);
      // Render cached activity immediately, then refresh both streams without
      // holding the agreement behind a network request.
      unawaited(Future.wait([_syncMessages(), _syncMedia()]));
    } catch (e) {
      debugPrint('[ContractAgreement] Error loading contract: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Subscribe to FCM notifications for real-time updates
  void _subscribeToNotifications() {
    final handler = NotificationService().contractHandler;

    _notificationSubscription = handler.events.listen((event) async {
      if (!mounted) return;
      // Only process events for this contract
      if (_externalContractId == null) return;
      if (event.contractId != _externalContractId) return;

      debugPrint(
        '[ContractAgreement] Received notification: ${event.type}, userId: ${event.userId}',
      );

      switch (event.type) {
        case ContractNotificationType.contractAccept:
          SnackBarHandler.showSuccess(
            context,
            TranslationHandler.get(
              'notification_other_accepted',
            ).replaceAll('{name}', event.username ?? 'User'),
          );
          // Sync is handled by notification handler - UI will update via StreamBuilder
          break;

        case ContractNotificationType.contractDispute:
          SnackBarHandler.showError(
            context,
            TranslationHandler.get(
              'notification_contract_disputed',
            ).replaceAll('{name}', event.username ?? 'User'),
          );
          // Sync is handled by notification handler - UI will update via StreamBuilder
          break;

        case ContractNotificationType.contractMessage:
          // Sync messages from backend
          await _syncMessages();
          break;

        case ContractNotificationType.contractMedia:
          // Sync media from backend
          await _syncMedia();
          break;

        default:
          break;
      }
    });
  }

  /// Sync messages from backend and decrypt them
  Future<void> _syncMessages() async {
    if (_externalContractId == null || _privateKeyBytes == null) return;

    try {
      final messageCubit = context.read<MessageCubit>();
      await messageCubit.loadMessages(contractId: _externalContractId!);

      final state = messageCubit.state;
      if (state is MessagesLoaded) {
        // F-20: skip already-persisted messages and decrypt the pending batch
        // on a background isolate so opening a chat never janks the UI.
        final knownIds = await getKnownMessageExternalIds(
          contractId: widget.contractId,
        );
        final pending = state.messages
            .where((msg) => !knownIds.contains(msg.id))
            .toList();
        final plaintexts = await CryptoService.decryptBatchWithPrivateKey(
          ciphertexts: pending.map((msg) => msg.content).toList(),
          privateKeyBytes: _privateKeyBytes!,
        );

        for (var i = 0; i < pending.length; i++) {
          final msg = pending[i];
          final plaintext = plaintexts[i];
          await saveMessageToIsar(
            contractId: widget.contractId,
            externalId: msg.id,
            senderId: msg.senderId,
            senderFirstName: msg.senderFirstName,
            senderLastName: msg.senderLastName,
            content: plaintext ?? '[Unable to decrypt]',
            contentHash: msg.contentHash,
            createdAt: msg.createdAt,
          );
        }

        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[ContractAgreement] Error syncing messages: $e');
    }
  }

  /// Sync media from backend
  Future<void> _syncMedia() async {
    if (_externalContractId == null) return;

    try {
      final mediaCubit = context.read<MediaCubit>();
      await mediaCubit.loadMedia(contractId: _externalContractId!);

      final state = mediaCubit.state;
      if (state is MediaListLoaded) {
        for (final media in state.mediaList) {
          await saveMediaToIsar(
            contractId: widget.contractId,
            externalId: media.id,
            senderId: media.senderId,
            senderName: media.senderName,
            originalFilename: media.originalFilename,
            content: media.content,
            url: media.url,
            mimeType: media.mimeType,
            createdAt: media.createdAt,
          );
        }
      }
    } catch (e) {
      debugPrint('[ContractAgreement] Error syncing media: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Send encrypted message to backend
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_externalContractId == null) return;
    if (_privateKeyBytes == null || _otherUserPublicKey == null) {
      SnackBarHandler.showError(
        context,
        TranslationHandler.get('error_encryption_keys_missing'),
      );
      return;
    }
    if (!CryptoService.canEncryptWithRsa(text)) {
      SnackBarHandler.showWarning(
        context,
        TranslationHandler.get('message_too_long_to_encrypt'),
      );
      return;
    }

    setState(() => _isSendingMessage = true);
    final messageCubit = context.read<MessageCubit>();

    try {
      // Get sender's public key from Hive
      final userBox = await Hive.openBox('user');
      final myPublicKey = userBox.get('publicKey')?.toString();

      if (myPublicKey == null) {
        throw Exception('Sender public key not found');
      }

      // Encrypt message for sender (self) and recipient
      final contentForSender = CryptoService.encryptWithPublicKey(
        plaintext: text,
        publicKeyBase64: myPublicKey,
      );
      final contentForRecipient = CryptoService.encryptWithPublicKey(
        plaintext: text,
        publicKeyBase64: _otherUserPublicKey!,
      );

      // Create SHA256 hash of plaintext for verification
      final contentHash = sha256.convert(utf8.encode(text)).toString();

      // Send to backend
      final sent = await messageCubit.sendMessage(
        contractId: _externalContractId!,
        contentForSender: contentForSender,
        contentForRecipient: contentForRecipient,
        contentHash: contentHash,
      );
      if (!sent) {
        if (mounted) {
          SnackBarHandler.showError(
            context,
            TranslationHandler.get('error_sending_message'),
          );
        }
        return;
      }

      // Sync messages from server to get all messages including the one we just sent
      await _syncMessages();

      if (_messageController.text.trim() == text) {
        _messageController.clear();
      }
      _scrollToBottom();
    } catch (e) {
      debugPrint('[ContractAgreement] Error sending message: $e');
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('error_sending_message'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  /// Send media file to backend
  Future<void> _sendMedia(String filePath) async {
    if (_externalContractId == null) return;

    setState(() => _isUploadingMedia = true);
    final mediaCubit = context.read<MediaCubit>();
    try {
      final file = File(filePath);
      final filename = filePath.split(Platform.pathSeparator).last;
      if (await file.length() > _maxAttachmentBytes) {
        if (mounted) {
          SnackBarHandler.showWarning(
            context,
            TranslationHandler.get('attachment_too_large'),
          );
        }
        return;
      }

      // Upload to backend
      final uploaded = await mediaCubit.uploadMedia(
        contractId: _externalContractId!,
        file: file,
        filename: filename,
      );
      if (!uploaded) {
        if (mounted) {
          SnackBarHandler.showError(
            context,
            TranslationHandler.get('error_uploading_media'),
          );
        }
        return;
      }

      // Sync to get the real data from server
      await _syncMedia();

      if (mounted) {
        SnackBarHandler.showSuccess(
          context,
          TranslationHandler.get('media_uploaded_success'),
        );
      }
    } catch (e) {
      debugPrint('[ContractAgreement] Error sending media: $e');
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('error_uploading_media'),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  /// Accept contract
  Future<void> _acceptContract() async {
    if (_externalContractId == null) return;

    setState(() => _isUpdatingContract = true);
    final contractCubit = context.read<ContractStateCubit>();
    try {
      final accepted = await contractCubit.accept(_externalContractId!);
      if (!accepted) {
        if (mounted) {
          SnackBarHandler.showError(
            context,
            TranslationHandler.get('error_accepting_contract'),
          );
        }
        return;
      }

      if (mounted) {
        SnackBarHandler.showSuccess(
          context,
          TranslationHandler.get('contract_accepted'),
        );
      }

      // Sync from backend to get updated status
      await _syncContract();
    } catch (e) {
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('error_accepting_contract'),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingContract = false);
    }
  }

  /// Dispute contract
  Future<void> _disputeContract({String? reason}) async {
    if (_externalContractId == null) return;

    setState(() => _isUpdatingContract = true);
    final contractCubit = context.read<ContractStateCubit>();
    try {
      final disputed = await contractCubit.dispute(
        _externalContractId!,
        reason: reason,
      );
      if (!disputed) {
        if (mounted) {
          SnackBarHandler.showError(
            context,
            TranslationHandler.get('error_disputing_contract'),
          );
        }
        return;
      }

      if (mounted) {
        SnackBarHandler.showWarning(
          context,
          TranslationHandler.get('contract_disputed'),
        );
      }

      // Sync from backend to get updated status
      await _syncContract();
    } catch (e) {
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('error_disputing_contract'),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingContract = false);
    }
  }

  /// Sync contract from backend
  Future<void> _syncContract() async {
    try {
      await _contractSyncService.syncContracts();
      debugPrint('[ContractAgreement] Contract synced from backend');
    } catch (e) {
      debugPrint('[ContractAgreement] Error syncing contract: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<Contract?>(
      stream: isar.contracts.watchObject(
        widget.contractId,
        fireImmediately: true,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            body: Center(
              child: Text(TranslationHandler.get('error_contract_not_found')),
            ),
          );
        }

        final contract = snapshot.data!;

        return _buildPage(context, contract);
      },
    );
  }

  Widget _buildPage(BuildContext context, Contract contract) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _privateKeyBytes == null
              ? TranslationHandler.get('agreement_locked_title')
              : contract.title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: TranslationHandler.get('contract_details'),
            onPressed: _privateKeyBytes == null
                ? null
                : () => _showContractDetails(contract),
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border.symmetric(
                  vertical: BorderSide(color: colors.outlineVariant),
                ),
              ),
              child: Column(
                children: [
                  _buildStatusSection(context, contract),
                  Expanded(child: _buildMessagesList()),
                  _buildChatInputBar(colors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context, Contract contract) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isUserA = contract.userAId == _currentUserId;
    final myAccepted = isUserA
        ? contract.userAAccepted
        : contract.userBAccepted;
    final otherAccepted = isUserA
        ? contract.userBAccepted
        : contract.userAAccepted;
    final isActionable =
        contract.status == ContractStatus.active ||
        contract.status == ContractStatus.pending;
    final waiting = myAccepted && !otherAccepted && isActionable;
    final statusColor = waiting
        ? AppTheme.statusOrange
        : _statusColor(contract.status, colors);
    final statusText = waiting
        ? TranslationHandler.get('waiting_for_other_accept')
        : _getStatusText(contract.status);

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  waiting
                      ? Icons.hourglass_empty
                      : _statusIcon(contract.status),
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      TranslationHandler.get('agreement_activity_desc'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    TranslationHandler.get('price'),
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${contract.price} ${TranslationHandler.get('currency')}',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ],
          ),
          if (contract.status == ContractStatus.disputed) ...[
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pushNamed(
                context,
                '/support-chat',
                arguments: widget.contractId,
              ),
              icon: const Icon(Icons.support_agent_outlined),
              label: Text(TranslationHandler.get('contact_support')),
            ),
          ],
          if (isActionable && !waiting) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                    ),
                    onPressed: _isUpdatingContract
                        ? null
                        : () => _showDisputeConfirmation(context),
                    icon: const Icon(Icons.report_problem_outlined),
                    label: Text(TranslationHandler.get('dispute')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isUpdatingContract || myAccepted
                        ? null
                        : () => _showAcceptConfirmation(context),
                    icon: _isUpdatingContract
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      myAccepted
                          ? TranslationHandler.get('accepted')
                          : TranslationHandler.get('accept'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAcceptConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(TranslationHandler.get('accept_contract')),
        content: Text(TranslationHandler.get('accept_contract_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TranslationHandler.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(TranslationHandler.get('accept')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _acceptContract();
  }

  Future<void> _showDisputeConfirmation(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _DisputeDialog(),
    );
    if (reason != null && mounted) {
      await _disputeContract(reason: reason.isEmpty ? null : reason);
    }
  }

  /// Refresh all data from backend
  Future<void> _onRefresh() async {
    await Future.wait([_syncContract(), _syncMessages(), _syncMedia()]);
  }

  /// Build messages list from Isar with real-time updates
  Widget _buildMessagesList() {
    return StreamBuilder<List<Message>>(
      stream: isar.messages
          .filter()
          .contractIdEqualTo(widget.contractId)
          .sortByCreatedAt()
          .watch(fireImmediately: true),
      builder: (context, msgSnapshot) {
        return StreamBuilder<List<MediaFile>>(
          stream: isar.mediaFiles
              .filter()
              .contractIdEqualTo(widget.contractId)
              .sortByCreatedAt()
              .watch(fireImmediately: true),
          builder: (context, mediaSnapshot) {
            final messages = msgSnapshot.data ?? [];
            final mediaFiles = mediaSnapshot.data ?? [];

            if (_privateKeyBytes == null ||
            (messages.isEmpty && mediaFiles.isEmpty)) {
              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _privateKeyBytes == null
                                ? Icons.lock_outline
                                : Icons.forum_outlined,
                            size: 36,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _privateKeyBytes == null
                                ? TranslationHandler.get(
                                    'agreement_locked_title',
                                  )
                                : TranslationHandler.get('no_messages_yet'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _privateKeyBytes == null
                                ? TranslationHandler.get(
                                    'agreement_locked_desc',
                                  )
                                : TranslationHandler.get(
                                    'no_activity_yet_desc',
                                  ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Combine messages and media into a single sorted list
            final List<dynamic> allItems = [...messages, ...mediaFiles];
            allItems.sort((a, b) {
              final aTime = a is Message
                  ? a.createdAt
                  : (a as MediaFile).createdAt;
              final bTime = b is Message
                  ? b.createdAt
                  : (b as MediaFile).createdAt;
              return aTime.compareTo(bTime);
            });

            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
                itemCount: allItems.length,
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  if (item is Message) {
                    return _buildMessageBubble(
                      item,
                      item.senderId == _currentUserId,
                    );
                  } else if (item is MediaFile) {
                    return _buildMediaBubble(
                      item,
                      item.senderId == _currentUserId,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    final colors = Theme.of(context).colorScheme;
    final senderName = _getSenderName(message);

    // F-18: contentHash is the only tamper-detection for message plaintext.
    // Show a warning when a stored hash is present but does not match the
    // decrypted content (decryption sentinels are excluded).
    final isDecryptionSentinel =
        message.content.startsWith('[Unable to') ||
        message.content.startsWith('[Unable to decrypt');
    final hashVerified = CryptoService.plaintextMatchesHash(
      plaintext: message.content,
      expectedHex: message.contentHash,
    );
    final showUnverified =
        !isDecryptionSentinel &&
        (message.contentHash?.isNotEmpty ?? false) &&
        !hashVerified;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: colors.surfaceContainerHighest,
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 12, color: colors.onSurface),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 540),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppTheme.radiusMd),
                  topRight: const Radius.circular(AppTheme.radiusMd),
                  bottomLeft: isMe
                      ? const Radius.circular(AppTheme.radiusMd)
                      : const Radius.circular(AppTheme.radiusSm),
                  bottomRight: isMe
                      ? const Radius.circular(AppTheme.radiusSm)
                      : const Radius.circular(AppTheme.radiusMd),
                ),
                color: isMe ? colors.primary : colors.surface,
                border: isMe ? null : Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showUnverified) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 14,
                          color: isMe
                              ? colors.onPrimary.withValues(alpha: .8)
                              : colors.error,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            TranslationHandler.get('unverified_content'),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: isMe
                                      ? colors.onPrimary.withValues(alpha: .8)
                                      : colors.error,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  SelectableText(
                    message.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isMe ? colors.onPrimary : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatTime(message.createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isMe
                          ? colors.onPrimary.withValues(alpha: .72)
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: colors.primary,
              child: Text(
                TranslationHandler.get('you'),
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaBubble(MediaFile media, bool isMe) {
    final colors = Theme.of(context).colorScheme;
    final isUrl = media.url.startsWith('http');
    final isImage =
        media.mimeType?.startsWith('image') == true ||
        media.originalFilename.toLowerCase().endsWith('.png') ||
        media.originalFilename.toLowerCase().endsWith('.jpg') ||
        media.originalFilename.toLowerCase().endsWith('.jpeg');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: colors.surfaceContainerHighest,
              child: Text(
                media.senderName?.isNotEmpty == true
                    ? media.senderName![0].toUpperCase()
                    : '?',
                style: TextStyle(fontSize: 12, color: colors.onSurface),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                color: isMe ? colors.primary : colors.surface,
                border: isMe ? null : Border.all(color: colors.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isImage)
                      isUrl
                          ? Image.network(
                              media.url,
                              fit: BoxFit.cover,
                              width: 300,
                              height: 180,
                              loadingBuilder: (_, child, progress) =>
                                  progress == null
                                  ? child
                                  : Container(
                                      width: 300,
                                      height: 180,
                                      color: colors.surfaceContainerHighest,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                              errorBuilder: (_, __, ___) =>
                                  _buildBrokenImagePlaceholder(colors),
                            )
                          : Image.file(
                              File(media.content),
                              fit: BoxFit.cover,
                              width: 300,
                              height: 180,
                              errorBuilder: (_, __, ___) =>
                                  _buildBrokenImagePlaceholder(colors),
                            )
                    else
                      _buildFilePlaceholder(colors, media.originalFilename),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            media.originalFilename,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: isMe
                                      ? colors.onPrimary
                                      : colors.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(media.createdAt),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: isMe
                                      ? colors.onPrimary.withValues(alpha: .72)
                                      : colors.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: colors.primary,
              child: Text(
                TranslationHandler.get('you'),
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBrokenImagePlaceholder(ColorScheme colors) {
    return Container(
      width: 300,
      height: 180,
      color: colors.surfaceContainerHighest,
      child: Icon(
        Icons.broken_image,
        color: colors.onSurface.withValues(alpha: .5),
      ),
    );
  }

  Widget _buildFilePlaceholder(ColorScheme colors, String filename) {
    final extension = filename.split('.').last.toLowerCase();
    IconData icon;

    switch (extension) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        break;
      case 'mp4':
      case 'mov':
      case 'avi':
        icon = Icons.videocam;
        break;
      default:
        icon = Icons.insert_drive_file;
    }

    return Container(
      width: 300,
      height: 112,
      color: colors.surfaceContainerHighest,
      child: Icon(icon, size: 40, color: colors.primary),
    );
  }

  Widget _buildChatInputBar(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isUploadingMedia) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: TranslationHandler.get('add_attachment'),
                  onPressed: _isUploadingMedia ? null : _showAttachmentOptions,
                  icon: const Icon(Icons.attach_file),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: _privateKeyBytes != null,
                    decoration: InputDecoration(
                      hintText: _privateKeyBytes == null
                          ? TranslationHandler.get('agreement_locked_title')
                          : TranslationHandler.get('type_your_message'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _sendMessage(),
                    style: TextStyle(color: colors.onSurface),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: TranslationHandler.get('send_message'),
                  onPressed: _isSendingMessage || _privateKeyBytes == null
                      ? null
                      : _sendMessage,
                  icon: _isSendingMessage
                      ? SizedBox.square(
                          dimension: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                TranslationHandler.get('choose_file_type'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                TranslationHandler.get('attachment_privacy_note'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(TranslationHandler.get('camera')),
                onTap: _pickImageFromCamera,
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: Text(TranslationHandler.get('gallery')),
                onTap: _pickImageFromGallery,
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: Text(TranslationHandler.get('video')),
                onTap: _pickVideo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    Navigator.pop(context);
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null && mounted) await _sendMedia(image.path);
    } catch (_) {
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('attachment_picker_failed'),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    Navigator.pop(context);
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) await _sendMedia(image.path);
    } catch (_) {
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('attachment_picker_failed'),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    Navigator.pop(context);
    try {
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null && mounted) await _sendMedia(video.path);
    } catch (_) {
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('attachment_picker_failed'),
        );
      }
    }
  }

  void _showContractDetails(Contract contract) {
    final isUserA = contract.userAId == _currentUserId;
    final otherName = isUserA ? contract.userBName : contract.userAName;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;
        final createdDate = MaterialLocalizations.of(
          sheetContext,
        ).formatMediumDate(contract.createdAt.toLocal());
        return FractionallySizedBox(
          heightFactor: .88,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    TranslationHandler.get('contract_details'),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_getStatusText(contract.status)} · $createdDate',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildDetailRow(
                            TranslationHandler.get('contract_title'),
                            contract.title,
                            Icons.title,
                          ),
                          _buildDetailRow(
                            TranslationHandler.get('other_party'),
                            otherName ?? TranslationHandler.get('unknown'),
                            Icons.person_outline,
                          ),
                          _buildDetailRow(
                            TranslationHandler.get('price'),
                            '${contract.price} ${TranslationHandler.get('currency')}',
                            Icons.payments_outlined,
                          ),
                          if (contract.detailsHash?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 8),
                            _buildVerificationBanner(
                              verified: CryptoService.plaintextMatchesHash(
                                plaintext:
                                    '${contract.title}|${contract.description}|${contract.price}',
                                expectedHex: contract.detailsHash,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Text(
                            TranslationHandler.get('description'),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                              border: Border.all(color: colors.outlineVariant),
                            ),
                            child: SelectableText(
                              contract.description,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(TranslationHandler.get('close')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getStatusText(ContractStatus status) {
    switch (status) {
      case ContractStatus.active:
        return TranslationHandler.get('status_active');
      case ContractStatus.accepted:
        return TranslationHandler.get('status_accepted');
      case ContractStatus.pending:
        return TranslationHandler.get('status_pending');
      case ContractStatus.disputed:
        return TranslationHandler.get('status_disputed');
      case ContractStatus.completed:
        return TranslationHandler.get('status_completed');
      case ContractStatus.rejected:
        return TranslationHandler.get('status_rejected');
    }
  }

  Color _statusColor(ContractStatus status, ColorScheme colors) {
    return switch (status) {
      ContractStatus.active => colors.primary,
      ContractStatus.pending => AppTheme.statusOrange,
      ContractStatus.accepted ||
      ContractStatus.completed => AppTheme.statusGreen,
      ContractStatus.disputed => colors.error,
      ContractStatus.rejected => AppTheme.statusGray,
    };
  }

  IconData _statusIcon(ContractStatus status) {
    return switch (status) {
      ContractStatus.active => Icons.play_circle_outline,
      ContractStatus.pending => Icons.schedule_outlined,
      ContractStatus.accepted => Icons.handshake_outlined,
      ContractStatus.completed => Icons.task_alt_outlined,
      ContractStatus.disputed => Icons.report_problem_outlined,
      ContractStatus.rejected => Icons.cancel_outlined,
    };
  }

  Widget _buildDetailRow(String title, String value, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner({required bool verified}) {
    final colors = Theme.of(context).colorScheme;
    final color = verified ? colors.primary : colors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(
            verified ? Icons.verified_outlined : Icons.error_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              TranslationHandler.get(
                verified ? 'details_verified' : 'details_unverified',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSenderName(Message message) {
    if (message.senderId == _currentUserId) {
      return TranslationHandler.get('you');
    }
    final first = message.senderFirstName ?? '';
    final last = message.senderLastName ?? '';
    return '$first $last'.trim().isNotEmpty
        ? '$first $last'.trim()
        : TranslationHandler.get('other_party');
  }

  String _formatTime(DateTime dateTime) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(dateTime.toLocal()));
  }
}
