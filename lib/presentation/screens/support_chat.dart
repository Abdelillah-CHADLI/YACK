import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:yack/data/db/models/contract.dart';
import 'package:yack/data/db/models/message.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/support/support_service.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/main.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key, required this.contractId});

  final int contractId;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final SupportService _service = SupportService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Contract? _contract;
  SupportConversation? _conversation;
  Timer? _pollTimer;
  bool _loading = true;
  bool _sending = false;
  bool _grantingAccess = false;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final contract = await isar.contracts.get(widget.contractId);
      final externalId = contract?.externalId;
      if (contract == null || externalId == null || externalId.isEmpty) {
        throw StateError('Contract unavailable');
      }
      if (mounted) {
        setState(() => _contract = contract);
      }
      final conversation = await _service.getConversation(externalId);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('support_load_failed'),
        );
      }
    }
  }

  Future<void> _send() async {
    final contractId = _contract?.externalId;
    final message = _messageController.text.trim();
    if (_sending || contractId == null || message.isEmpty) return;

    setState(() => _sending = true);
    try {
      await _service.sendMessage(contractId: contractId, plaintext: message);
      _messageController.clear();
      await _load(silent: true);
    } catch (_) {
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('support_send_failed'),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _grantAccess() async {
    final contract = _contract;
    if (_grantingAccess || contract == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(TranslationHandler.get('share_case_with_support')),
        content: Text(TranslationHandler.get('share_case_explanation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(TranslationHandler.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(TranslationHandler.get('share_securely')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _grantingAccess = true);
    try {
      final messages = await isar.messages
          .filter()
          .contractIdEqualTo(widget.contractId)
          .sortByCreatedAt()
          .findAll();
      await _service.grantReviewAccess(contract: contract, messages: messages);
      await _load(silent: true);
      if (mounted) {
        SnackBarHandler.showSuccess(
          context,
          TranslationHandler.get('case_shared_with_support'),
        );
      }
    } catch (_) {
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('support_share_failed'),
        );
      }
    } finally {
      if (mounted) setState(() => _grantingAccess = false);
    }
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(TranslationHandler.get('support_chat')),
        actions: [
          IconButton(
            tooltip: TranslationHandler.get('refresh'),
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: conversation?.reviewAccessGranted == true
                        ? YackNotice(
                            tone: YackNoticeTone.positive,
                            icon: Icons.verified_user_outlined,
                            message: TranslationHandler.get(
                              'support_access_granted',
                            ),
                          )
                        : YackNotice(
                            tone: YackNoticeTone.warning,
                            icon: Icons.lock_outline,
                            message: TranslationHandler.get(
                              'support_access_needed',
                            ),
                            action: TextButton(
                              onPressed: _grantingAccess ? null : _grantAccess,
                              child: Text(
                                _grantingAccess
                                    ? TranslationHandler.get('sharing')
                                    : TranslationHandler.get('share_case'),
                              ),
                            ),
                          ),
                  ),
                  Expanded(
                    child: conversation == null || conversation.messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.support_agent_outlined,
                                    size: 40,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    TranslationHandler.get(
                                      'support_empty_message',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                            itemCount: conversation.messages.length,
                            itemBuilder: (context, index) {
                              final message = conversation.messages[index];
                              final mine = !message.isFromSupport;
                              return Align(
                                alignment: mine
                                    ? AlignmentDirectional.centerEnd
                                    : AlignmentDirectional.centerStart,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 520,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? colors.primary
                                        : colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mine
                                            ? TranslationHandler.get('you')
                                            : TranslationHandler.get('support'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: mine
                                                  ? colors.onPrimary.withValues(
                                                      alpha: .8,
                                                    )
                                                  : colors.primary,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        message.content,
                                        style: TextStyle(
                                          color: mine
                                              ? colors.onPrimary
                                              : colors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (conversation?.status == 'closed')
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        TranslationHandler.get('support_case_closed'),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(
                          top: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: TranslationHandler.get(
                                  'support_message_hint',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: TranslationHandler.get('send'),
                            onPressed: _sending ? null : _send,
                            icon: _sending
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_outlined),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
