import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:yack/data/models/contract/temp_contract.dart';
import 'package:yack/data/repositories/isar_adapter.dart';
import 'package:yack/logic/cubits/contract/temp_contract_cubit.dart';
import 'package:yack/logic/cubits/contract/temp_contract_state.dart';
import 'package:yack/logic/services/contract/contract_sync_service.dart';
import 'package:yack/logic/services/contract/temp_contract_service.dart';
import 'package:yack/logic/services/notification/contract_notification_handler.dart';
import 'package:yack/logic/services/notification/notification_service.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/screens/acceptDeclineContract.dart';
import 'package:yack/presentation/theme/theme.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/secondaryActionButton.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

/// Invitation hand-off for the creator of a temporary agreement.
class ShareContractScreen extends StatefulWidget {
  final TempContract tempContract;
  final String title;
  final String description;
  final double price;

  const ShareContractScreen({
    super.key,
    required this.tempContract,
    required this.title,
    required this.description,
    required this.price,
  });

  @override
  State<ShareContractScreen> createState() => _ShareContractScreenState();
}

class _ShareContractScreenState extends State<ShareContractScreen> {
  late final String _qrData;
  late final String _shareText;
  bool _userBJoined = false;
  bool _userASigned = false;
  bool _userBSigned = false;
  bool _isSigning = false;
  bool _isPolling = false;
  bool _isCompleting = false;
  bool _isCancelling = false;
  bool _allowPop = false;
  String? _userBName;
  StreamSubscription<ContractNotificationEvent>? _notificationSubscription;
  StreamSubscription<RemoteMessage>? _firebaseSubscription;
  Timer? _statusPollTimer;
  final TempContractService _tempContractService = TempContractService();
  final ContractSyncService _contractSyncService = ContractSyncService();

  @override
  void initState() {
    super.initState();
    _generateShareData();
    _setupNotificationListener();
    _startStatusPolling();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _firebaseSubscription?.cancel();
    _statusPollTimer?.cancel();
    super.dispose();
  }

  void _setupNotificationListener() {
    final handler = NotificationService().contractHandler;
    _notificationSubscription = handler
        .eventsForTempContract(widget.tempContract.tempId)
        .listen(_handleContractEvent);
    _firebaseSubscription = FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      if (data['tempId']?.toString() != widget.tempContract.tempId) return;
      switch (data['type']?.toString()) {
        case 'contractJoin':
          _handleUserBJoined(data['username']?.toString() ?? '');
          break;
        case 'contractSign':
          _handleUserBSigned(data['contractId']?.toString());
          break;
      }
    });
  }

  void _handleContractEvent(ContractNotificationEvent event) {
    switch (event.type) {
      case ContractNotificationType.contractJoin:
        _handleUserBJoined(event.username ?? '');
        break;
      case ContractNotificationType.contractSign:
        _handleUserBSigned(event.contractId);
        break;
      default:
        break;
    }
  }

  void _handleUserBJoined(String username) {
    if (!mounted || _userBJoined) return;
    setState(() {
      _userBJoined = true;
      _userBName = username.trim();
    });
    SnackBarHandler.showMessage(
      context,
      TranslationHandler.get('participant_joined_ready'),
    );
  }

  void _handleUserBSigned(String? contractId) {
    if (!mounted || _userBSigned) return;
    setState(() => _userBSigned = true);
    SnackBarHandler.showMessage(
      context,
      '${_userBName ?? ''} ${TranslationHandler.get('has_signed_contract')}',
    );
    if (_userASigned) unawaited(_completeContract(contractId));
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    unawaited(_pollStatus());
    _statusPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_pollStatus()),
    );
  }

  Future<void> _pollStatus() async {
    if (_isPolling || _isCompleting || !mounted) return;
    _isPolling = true;
    try {
      final status = await _tempContractService.getStatus(
        widget.tempContract.tempId,
      );
      if (!mounted) return;
      if (status.isUnavailable) {
        _statusPollTimer?.cancel();
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('invitation_no_longer_available'),
        );
        setState(() => _allowPop = true);
        Navigator.of(context).pop();
        return;
      }
      if (status.isFinalized) {
        await _completeContract(status.contractId);
        return;
      }
      setState(() {
        _userBJoined = status.userBId != null;
        _userASigned = status.userASigned;
        _userBSigned = status.userBSigned;
        if (status.userBName?.isNotEmpty ?? false) {
          _userBName = status.userBName;
        }
      });
    } catch (_) {
      // Keep the invitation usable; a later poll or FCM event can recover.
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _completeContract(String? contractId) async {
    if (_isCompleting || !mounted) return;
    _isCompleting = true;
    _statusPollTimer?.cancel();
    try {
      await _contractSyncService.syncContracts();
      if (contractId != null &&
          await getContractByExternalId(contractId) == null) {
        throw StateError('Finalized agreement was not returned by the server');
      }
      if (!mounted) return;
      SnackBarHandler.showSuccess(
        context,
        TranslationHandler.get('contract_saved_successfully'),
      );
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/home', (_) => false);
    } catch (_) {
      if (!mounted) return;
      _isCompleting = false;
      SnackBarHandler.showError(
        context,
        TranslationHandler.get('contract_unavailable'),
      );
      _startStatusPolling();
    }
  }

  Future<void> _reviewAndSign() async {
    if (_isSigning) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AcceptDeclineContractScreen(
          title: widget.title,
          price: widget.price,
          userFirstName: (_userBName?.isNotEmpty ?? false)
              ? _userBName!
              : TranslationHandler.get('unknown'),
          userLastName: '',
          description: widget.description,
          isUserA: true,
        ),
      ),
    );

    if (!mounted || result == null) return;
    if (result == false) {
      SnackBarHandler.showMessage(
        context,
        TranslationHandler.get('contract_declined'),
      );
      await _leave(force: true);
      return;
    }

    setState(() {
      _isSigning = true;
      _userASigned = true;
    });
    context.read<TempContractCubit>().sign(widget.tempContract.tempId);
  }

  void _generateShareData() {
    final normalizedPrice = widget.price.toStringAsFixed(2);
    final detailsHash = sha256
        .convert(
          utf8.encode('${widget.title}|${widget.description}|$normalizedPrice'),
        )
        .toString();
    final shareData = {
      'tempId': widget.tempContract.tempId,
      'title': widget.title,
      'description': widget.description,
      'price': widget.price,
      'detailsHash': detailsHash,
      'userAName': widget.tempContract.userAName ?? '',
      'creatorId': FirebaseAuth.instance.currentUser?.uid ?? '',
    };
    final encoded = base64Url.encode(utf8.encode(json.encode(shareData)));
    _qrData = 'yack://contract?data=$encoded';
    _shareText = _qrData;
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (mounted) {
      SnackBarHandler.showSuccess(
        context,
        TranslationHandler.get('link_copied'),
      );
    }
  }

  Future<void> _leave({bool force = false}) async {
    if (_isCancelling || _isCompleting) return;
    var confirmed = force;
    if (!force) {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.logout_outlined),
              title: Text(TranslationHandler.get('leave_invitation_title')),
              content: Text(TranslationHandler.get('leave_invitation_message')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(TranslationHandler.get('stay')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(TranslationHandler.get('leave')),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!mounted || !confirmed) return;
    setState(() => _isCancelling = true);
    try {
      await _tempContractService.cancel(widget.tempContract.tempId);
      if (!mounted) return;
      _statusPollTimer?.cancel();
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      SnackBarHandler.showError(
        context,
        TranslationHandler.get('invitation_cancel_failed'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return BlocListener<TempContractCubit, TempContractState>(
      listener: (context, state) async {
        if (state is TempContractSignSuccess) {
          if (state.contract.tempId != widget.tempContract.tempId) return;
          setState(() {
            _userASigned = true;
            _isSigning = false;
          });
          if ((state.contractId?.isNotEmpty ?? false) || _userBSigned) {
            await _completeContract(state.contractId);
          }
        } else if (state is TempContractError && _isSigning) {
          setState(() {
            _isSigning = false;
            _userASigned = false;
          });
          SnackBarHandler.showError(context, state.message);
        }
      },
      child: PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(TranslationHandler.get('share_contract')),
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: _leave,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: SafeArea(
            top: false,
            child: YackContent(
              maxWidth: 680,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: ListView(
                children: [
                  YackPageHeading(
                    eyebrow: TranslationHandler.get('invitation_ready'),
                    title: widget.title,
                    subtitle:
                        '${widget.price.toStringAsFixed(2)} ${TranslationHandler.get('currency')}',
                  ),
                  const SizedBox(height: 22),
                  _buildProgress(context),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Column(
                      children: [
                        Semantics(
                          label: TranslationHandler.get('contract_qr_label'),
                          image: true,
                          child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(16),
                            child: QrImageView(
                              data: _qrData,
                              version: QrVersions.auto,
                              size: 210,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                color: Colors.black,
                                eyeShape: QrEyeShape.square,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                color: Colors.black,
                                dataModuleShape: QrDataModuleShape.square,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _userBJoined
                              ? TranslationHandler.resolve(
                                  'participant_joined',
                                  params: {
                                    'name': (_userBName?.isNotEmpty ?? false)
                                        ? _userBName!
                                        : TranslationHandler.get('other_party'),
                                  },
                                )
                              : TranslationHandler.get('scan_contract_prompt'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _copyToClipboard,
                          icon: const Icon(Icons.copy_outlined),
                          label: Text(TranslationHandler.get('copy_link')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  YackNotice(
                    message: TranslationHandler.get('invitation_expiry_note'),
                    tone: YackNoticeTone.warning,
                    icon: Icons.timer_outlined,
                  ),
                  const SizedBox(height: 22),
                  if (_userBJoined && !_userASigned)
                    PrimaryActionButton(
                      action: TranslationHandler.get('review_and_sign'),
                      icon: Icons.fact_check_outlined,
                      onClick: _isSigning ? null : _reviewAndSign,
                      isLoading: _isSigning,
                    )
                  else if (_userASigned && !_userBSigned)
                    YackNotice(
                      message: TranslationHandler.get(
                        'waiting_for_signature_desc',
                      ),
                      tone: YackNoticeTone.neutral,
                      icon: Icons.hourglass_top_outlined,
                    )
                  else if (!_userBJoined)
                    YackNotice(
                      message: TranslationHandler.get('waiting_for_user_b'),
                      icon: Icons.person_search_outlined,
                    ),
                  const SizedBox(height: 12),
                  SecondaryActionButton(
                    action: TranslationHandler.get('leave'),
                    icon: Icons.arrow_back,
                    onClick: _isCancelling ? null : _leave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(BuildContext context) {
    final steps = [
      (TranslationHandler.get('created'), true),
      (TranslationHandler.get('participant_joined_step'), _userBJoined),
      (TranslationHandler.get('you_signed'), _userASigned),
      (TranslationHandler.get('both_signed'), _userASigned && _userBSigned),
    ];
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label: steps.where((step) => step.$2).map((step) => step.$1).join(', '),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      steps[index].$2
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: steps[index].$2
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      size: 22,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      steps[index].$1,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: steps[index].$2
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < steps.length - 1)
                Container(width: 12, height: 1, color: colors.outlineVariant),
            ],
          ],
        ),
      ),
    );
  }
}
