import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive/hive.dart';
import 'package:yack/logic/cubits/contract/temp_contract_cubit.dart';
import 'package:yack/logic/cubits/contract/temp_contract_state.dart';
import 'package:yack/logic/cubits/contract/contract_sync_cubit.dart';
import 'package:yack/logic/services/auth/cryptoService.dart';
import 'package:yack/logic/services/notification/contract_notification_handler.dart';
import 'package:yack/logic/services/notification/notification_service.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/presentation/theme/theme.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/secondaryActionButton.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/screens/acceptDeclineContract.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

class ScanContractScreen extends StatefulWidget {
  const ScanContractScreen({super.key});

  @override
  State<ScanContractScreen> createState() => _ScanContractScreenState();
}

class _ScanContractScreenState extends State<ScanContractScreen>
    with WidgetsBindingObserver {
  bool _isScanning = false;
  bool _isProcessing = false;
  bool _navigatingAway = false;
  bool _isWaitingForUserASign = false;
  bool _userBSigned = false; // Track if User B has signed
  bool _reviewApproved = false;
  bool _showManualInput = false;
  MobileScannerController? scannerController;
  StreamSubscription<ContractNotificationEvent>? _notificationSubscription;
  StreamSubscription<RemoteMessage>? _firebaseSubscription;
  final TextEditingController _linkController = TextEditingController();

  // Scanned contract data
  String? _scannedTempId;
  String? _scannedTitle;
  String? _scannedDescription;
  double? _scannedPrice;
  String? _scannedUserAName;
  String? _scannedCreatorId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isScanning || scannerController == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      scannerController?.stop();
    } else if (state == AppLifecycleState.resumed) {
      scannerController?.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    _firebaseSubscription?.cancel();
    _linkController.dispose();
    scannerController?.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    if (!mounted || _navigatingAway) return;
    _navigatingAway = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    });
  }

  /// Setup notification listener for User B after joining to listen for User A's actions
  void _setupNotificationListenerForTempContract(String tempId) {
    _notificationSubscription?.cancel();
    _firebaseSubscription?.cancel();

    final handler = NotificationService().contractHandler;

    // Listen via ContractNotificationHandler
    _notificationSubscription = handler.eventsForTempContract(tempId).listen((
      event,
    ) async {
      switch (event.type) {
        case ContractNotificationType.contractSign:
          // User A signed the contract
          if (_isWaitingForUserASign && _userBSigned) {
            // Both users have signed - sync and complete
            await _syncAndNavigateHome();
          }
          break;
        default:
          break;
      }
    });

    // Also listen directly to Firebase messages as fallback
    _firebaseSubscription = FirebaseMessaging.onMessage.listen((message) async {
      final data = message.data;
      if (data.isEmpty) return;

      final notifTempId = data['tempId']?.toString();
      // Only handle notifications for our temp contract
      if (notifTempId != tempId) {
        return;
      }

      final type = data['type']?.toString() ?? '';

      if (type == 'contractSign' && _isWaitingForUserASign && _userBSigned) {
        // Both users have signed - sync and complete
        await _syncAndNavigateHome();
      }
    });
  }

  /// Sync contracts and navigate home
  Future<void> _syncAndNavigateHome() async {
    // Sync contracts from backend to get the finalized contract with decrypted data
    context.read<ContractSyncCubit>().sync();

    if (mounted) {
      SnackBarHandler.showSuccess(
        context,
        TranslationHandler.get('contract_saved_successfully'),
      );
    }
    _navigateToHome();
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      scannerController = MobileScannerController();
    });
  }

  void _stopScanning() {
    scannerController?.stop();
    scannerController?.dispose();
    scannerController = null;
    if (mounted && !_navigatingAway) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  /// Get user's public key from Hive cache
  Future<String?> _getUserPublicKey() async {
    try {
      final box = await Hive.openBox('user');
      return box.get('publicKey')?.toString();
    } catch (_) {
      return null;
    }
  }

  // Process scanned QR code - store and process like manual input
  void _onQRScanned(String code) {
    _isProcessing = false;

    // Stop scanning first
    _stopScanning();

    // Store the scanned code in the controller
    _linkController.text = code;

    // Show manual input section with the scanned code
    setState(() {
      _showManualInput = true;
    });

    // Auto-trigger join after UI updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isProcessing) {
        _onManualLinkSubmit();
      }
    });
  }

  /// Process manual link input (yack://contract?data=...)
  void _onManualLinkSubmit() async {
    final input = _linkController.text.trim();
    if (input.isEmpty) {
      SnackBarHandler.showError(
        context,
        TranslationHandler.get('field_required_generic'),
      );
      return;
    }

    if (_isProcessing) return;
    _isProcessing = true;

    setState(() => _showManualInput = false);

    // Handle full QR code data format
    if (input.startsWith('yack://contract?data=')) {
      await _processFullDataUrl(input);
    } else {
      SnackBarHandler.showError(
        context,
        TranslationHandler.get('invalid_contract_qr'),
      );
      _isProcessing = false;
      if (mounted) setState(() {});
    }
  }

  /// Process full data URL with embedded contract preview info
  Future<void> _processFullDataUrl(String code) async {
    try {
      // Decode Base64 contract data
      final uri = Uri.parse(code);
      final encodedData = uri.queryParameters['data'];
      if (encodedData == null || encodedData.isEmpty) {
        throw FormatException('Missing contract data');
      }

      final jsonString = utf8.decode(base64Url.decode(encodedData));
      final Map<String, dynamic> jsonMap = json.decode(jsonString);

      // Extract contract data
      _scannedTempId = jsonMap['tempId']?.toString();
      _scannedTitle = jsonMap['title']?.toString() ?? '';
      _scannedDescription = jsonMap['description']?.toString() ?? '';
      _scannedPrice = (jsonMap['price'] is num)
          ? (jsonMap['price'] as num).toDouble()
          : double.tryParse(jsonMap['price']?.toString() ?? '0') ?? 0;
      _scannedUserAName = jsonMap['userAName']?.toString();
      _scannedCreatorId = jsonMap['creatorId']?.toString();

      if (_scannedTempId == null || _scannedTempId!.isEmpty) {
        throw FormatException('Missing tempId');
      }

      if (_scannedCreatorId != null &&
          _scannedCreatorId == FirebaseAuth.instance.currentUser?.uid) {
        throw const FormatException('Cannot join your own contract');
      }

      if (!CryptoService.canEncryptWithRsa(_scannedTitle!) ||
          !CryptoService.canEncryptWithRsa(_scannedDescription!)) {
        throw const FormatException('Contract content is too long');
      }

      if (!mounted) return;

      // Review before joining. Dismissing or declining does not bind the user
      // to the temporary contract on the backend.
      final approved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AcceptDeclineContractScreen(
            title: _scannedTitle!.isEmpty
                ? TranslationHandler.get('contract')
                : _scannedTitle!,
            price: _scannedPrice ?? 0,
            userFirstName: (_scannedUserAName?.trim().isNotEmpty ?? false)
                ? _scannedUserAName!
                : TranslationHandler.get('unknown'),
            userLastName: '',
            description: _scannedDescription ?? '',
          ),
        ),
      );

      if (approved != true || !mounted) {
        _isProcessing = false;
        setState(() {});
        return;
      }
      _reviewApproved = true;
      setState(() {});

      // Get user B's public key for encryption
      final publicKey = await _getUserPublicKey();
      if (publicKey == null || publicKey.isEmpty) {
        if (mounted) {
          SnackBarHandler.showError(
            context,
            TranslationHandler.get('missing_public_key'),
          );
        }
        _isProcessing = false;
        if (mounted) setState(() {});
        return;
      }

      // Encrypt fields for user B using their own public key
      final titleUserB = CryptoService.encryptWithPublicKey(
        plaintext: _scannedTitle!,
        publicKeyBase64: publicKey,
      );
      final descriptionUserB = CryptoService.encryptWithPublicKey(
        plaintext: _scannedDescription!,
        publicKeyBase64: publicKey,
      );
      final priceUserB = CryptoService.encryptWithPublicKey(
        plaintext: _scannedPrice!.toStringAsFixed(2),
        publicKeyBase64: publicKey,
      );

      // Join only after explicit review and approval.
      if (!mounted) return;
      context.read<TempContractCubit>().join(
        tempId: _scannedTempId!,
        titleUserB: titleUserB,
        descriptionUserB: descriptionUserB,
        priceUserB: priceUserB,
      );
    } on FormatException catch (error) {
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get(
            error.message == 'Cannot join your own contract'
                ? 'cannot_join_own_contract'
                : error.message == 'Contract content is too long'
                ? 'contract_content_invalid'
                : 'failed_to_decode_contract',
          ),
        );
        setState(() => _isProcessing = false);
      }
    } catch (error) {
      debugPrint('[ScanContractScreen] Could not process invite: $error');
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('failed_to_decode_contract'),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TempContractCubit, TempContractState>(
      listener: (context, state) async {
        if (state is TempContractJoinSuccess &&
            state.contract.tempId != _scannedTempId) {
          return;
        }
        if (state is TempContractSignSuccess &&
            state.contract.tempId != _scannedTempId) {
          return;
        }
        if (state is TempContractJoinSuccess) {
          // Setup notification listener for User A's signature
          _setupNotificationListenerForTempContract(state.contract.tempId);
          if (_reviewApproved) {
            context.read<TempContractCubit>().sign(state.contract.tempId);
          }
        } else if (state is TempContractSignSuccess) {
          // User B has signed
          setState(() {
            _userBSigned = true;
          });

          if (state.contractId != null && state.contractId!.isNotEmpty) {
            // Both users signed - contract is finalized, sync and go home
            await _syncAndNavigateHome();
          } else {
            // User B signed but User A hasn't signed yet - wait for notification
            setState(() {
              _isWaitingForUserASign = true;
              _isProcessing = false;
            });

            // Keep loading dialog showing while waiting
            if (mounted) {
              SnackBarHandler.showMessage(
                context,
                TranslationHandler.get('waiting_for_user_a_sign'),
              );
            }
          }
        } else if (state is TempContractError) {
          if (mounted) {
            SnackBarHandler.showError(context, state.message);
            setState(() {
              _isProcessing = false;
              _isWaitingForUserASign = false;
              _reviewApproved = false;
            });
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(
            TranslationHandler.get('scan'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        body: _isScanning
            ? Stack(
                children: [
                  MobileScanner(
                    controller: scannerController,
                    onDetect: (capture) {
                      if (_isProcessing) return;

                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final String? code = barcodes.first.rawValue;
                        if (code != null) {
                          _isProcessing = true;
                          scannerController?.stop();
                          _onQRScanned(code);
                        }
                      }
                    },
                  ),
                  Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final frameSize =
                            (constraints.biggest.shortestSide * .72)
                                .clamp(220.0, 340.0)
                                .toDouble();
                        return Container(
                          width: frameSize,
                          height: frameSize,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.yackGreen,
                              width: 4,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Stack(
                            children: [
                              // Corner decorations
                              Positioned(
                                top: -2,
                                left: -2,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: AppTheme.yackGreen,
                                        width: 8,
                                      ),
                                      left: BorderSide(
                                        color: AppTheme.yackGreen,
                                        width: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: AppTheme.yackGreen,
                                        width: 8,
                                      ),
                                      right: BorderSide(
                                        color: AppTheme.yackGreen,
                                        width: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -2,
                                left: -2,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: AppTheme.yackGreen,
                                        width: 8,
                                      ),
                                      left: BorderSide(
                                        color: AppTheme.yackGreen,
                                        width: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: AppTheme.yackGreen,
                                        width: 8,
                                      ),
                                      right: BorderSide(
                                        color: AppTheme.yackGreen,
                                        width: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  PositionedDirectional(
                    bottom: 100,
                    start: 20,
                    end: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: Text(
                          TranslationHandler.get('place_code_in_frame'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    bottom: 30,
                    start: 20,
                    end: 20,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: SecondaryActionButton(
                          action: TranslationHandler.get('stop_scanning'),
                          icon: Icons.close,
                          onClick: _stopScanning,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : _isWaitingForUserASign
            ? _buildWaitingState(context)
            : _isProcessing
            ? _buildProcessingState(context)
            : _buildInstructions(context),
      ),
    );
  }

  Widget _buildProcessingState(BuildContext context) {
    return YackContent(
      maxWidth: 560,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 32,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 20),
              Text(
                TranslationHandler.get('joining_contract'),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                TranslationHandler.get('joining_contract_desc'),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingState(BuildContext context) {
    return YackContent(
      maxWidth: 560,
      child: YackEmptyState(
        icon: Icons.hourglass_top_outlined,
        title: TranslationHandler.get('waiting_for_user_a_sign'),
        message: TranslationHandler.get('waiting_for_signature_desc'),
        action: OutlinedButton.icon(
          onPressed: _navigateToHome,
          icon: const Icon(Icons.home_outlined),
          label: Text(TranslationHandler.get('back_to_contracts')),
        ),
      ),
    );
  }

  Widget _buildInstructions(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return YackContent(
      maxWidth: 620,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            YackPageHeading(
              eyebrow: TranslationHandler.get('join_agreement'),
              title: TranslationHandler.get('scan_contract_qr_code'),
              subtitle: TranslationHandler.get('scan_instructions'),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.surface,
                border: Border.all(color: color.outlineVariant),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Column(
                children: [
                  _buildInstructionItem(
                    context,
                    Icons.lightbulb_outline,
                    TranslationHandler.get('instruction_good_lighting'),
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionItem(
                    context,
                    Icons.center_focus_strong,
                    TranslationHandler.get('instruction_center_code'),
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionItem(
                    context,
                    Icons.flash_auto,
                    TranslationHandler.get('instruction_auto_scan'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            PrimaryActionButton(
              action: TranslationHandler.get('start_scanning'),
              icon: Icons.qr_code_scanner,
              onClick: _startScanning,
            ),
            const SizedBox(height: 24),

            // Divider with "OR" text
            Row(
              children: [
                Expanded(
                  child: Divider(color: color.outline.withValues(alpha: 0.5)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    TranslationHandler.get('or'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: color.outline.withValues(alpha: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Manual link paste section
            if (!_showManualInput)
              SecondaryActionButton(
                action: TranslationHandler.get('enter_link_manually'),
                icon: Icons.link,
                onClick: () => setState(() => _showManualInput = true),
              ),

            if (_showManualInput) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: color.outline.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationHandler.get('paste_contract_link'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _linkController,
                      decoration: InputDecoration(
                        hintText: 'yack://...',
                        prefixIcon: const Icon(Icons.link),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _onManualLinkSubmit(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryActionButton(
                            action: TranslationHandler.get('cancel'),
                            onClick: () {
                              setState(() {
                                _showManualInput = false;
                                _linkController.clear();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryActionButton(
                            action: TranslationHandler.get('join_contract'),
                            icon: Icons.arrow_forward,
                            onClick: _onManualLinkSubmit,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(
    BuildContext context,
    IconData icon,
    String text,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
