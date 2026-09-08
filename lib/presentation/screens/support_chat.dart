import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();

  Contract? _contract;
  SupportConversation? _conversation;
  Timer? _pollTimer;
  bool _loading = true;
  bool _sending = false;
  bool _grantingAccess = false;
  bool _uploading = false;

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

  Future<void> _sendAttachment(File file, {String? filename}) async {
    final contractId = _contract?.externalId;
    if (_uploading || contractId == null) return;

    if (await file.length() > _maxAttachmentBytes) {
      if (mounted) {
        SnackBarHandler.showWarning(
          context,
          TranslationHandler.get('attachment_too_large'),
        );
      }
      return;
    }

    setState(() => _uploading = true);
    try {
      await _service.uploadAttachment(
        contractId: contractId,
        file: file,
        filename: filename,
      );
      await _load(silent: true);
      if (mounted) {
        SnackBarHandler.showSuccess(
          context,
          TranslationHandler.get('file_uploaded_success'),
        );
      }
    } catch (_) {
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('error_uploading_file'),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteAttachment(SupportAttachment attachment) async {
    final contractId = _contract?.externalId;
    if (contractId == null) return;
    try {
      await _service.deleteAttachment(
        contractId: contractId,
        attachmentId: attachment.id,
      );
      await _load(silent: true);
    } catch (_) {
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('error_uploading_file'),
        );
      }
    }
  }

  Future<void> _showAttachmentPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(TranslationHandler.get('document')),
              onTap: _pickDocument,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    Navigator.pop(context);
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null && mounted) {
        await _sendAttachment(
          File(image.path),
          filename: image.name.isNotEmpty ? image.name : null,
        );
      }
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
      if (image != null && mounted) {
        await _sendAttachment(
          File(image.path),
          filename: image.name.isNotEmpty ? image.name : null,
        );
      }
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
      if (video != null && mounted) {
        await _sendAttachment(
          File(video.path),
          filename: video.name.isNotEmpty ? video.name : null,
        );
      }
    } catch (_) {
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('attachment_picker_failed'),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    Navigator.pop(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'csv'],
      );
      final files = result?.files;
      if (files == null || files.isEmpty) return;
      final picked = files.first;
      final path = picked.path;
      final file = path != null ? File(path) : null;
      if (file != null && mounted) {
        await _sendAttachment(file, filename: picked.name);
      }
    } catch (_) {
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('attachment_picker_failed'),
        );
      }
    }
  }

  void _previewAttachment(SupportAttachment attachment) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: Image.network(attachment.url),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                attachment.originalFilename,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection(SupportConversation conversation) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 96,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final attachment in conversation.attachments)
            Container(
              width: 196,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: attachment.isImage
                          ? () => _previewAttachment(attachment)
                          : null,
                      child: attachment.isImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                attachment.url,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _attachmentIcon(colors),
                              ),
                            )
                          : _attachmentIcon(colors),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attachment.originalFilename,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            attachment.isImage
                                ? TranslationHandler.get('preview_image')
                                : TranslationHandler.get('support_attachment'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.primary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: TranslationHandler.get('remove_attachment'),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => _deleteAttachment(attachment),
                    ),
                  ],
                ),
              ),
            ),
          if (_uploading)
            Container(
              width: 120,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    TranslationHandler.get('uploading_file'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _attachmentIcon(ColorScheme colors) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.insert_drive_file_outlined, color: colors.primary),
    );
  }

  static const int _maxAttachmentBytes = 6 * 1024 * 1024;

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
                  if (conversation == null ||
                      (conversation.attachments.isEmpty && !_uploading))
                    const SizedBox.shrink()
                  else
                    _buildAttachmentsSection(conversation),
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
                          IconButton(
                            tooltip: TranslationHandler.get('attach_file'),
                            onPressed: _uploading || conversation?.status == 'closed'
                                ? null
                                : _showAttachmentPicker,
                            icon: _uploading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.attach_file),
                          ),
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
