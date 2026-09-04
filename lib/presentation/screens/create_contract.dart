import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:yack/logic/cubits/contract/temp_contract_cubit.dart';
import 'package:yack/logic/cubits/contract/temp_contract_state.dart';
import 'package:yack/logic/services/auth/cryptoService.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/screens/shareContract.dart';
import 'package:yack/presentation/screens/scan_contract.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

class CreateContractScreen extends StatefulWidget {
  const CreateContractScreen({super.key});

  @override
  State<CreateContractScreen> createState() => _CreateContractScreenState();
}

class _CreateContractScreenState extends State<CreateContractScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  bool _navigating = false;

  bool get _hasDraft =>
      _titleController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty ||
      _priceController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String _generateDetailsHash(String title, String description, String price) {
    return sha256.convert(utf8.encode('$title|$description|$price')).toString();
  }

  Future<String?> _getUserPublicKey() async {
    try {
      return (await Hive.openBox('user')).get('publicKey')?.toString();
    } catch (_) {
      return null;
    }
  }

  String? _encryptedFieldValidator(String? value, {bool required = false}) {
    final text = value?.trim() ?? '';
    if (required && text.isEmpty) {
      return TranslationHandler.get('title_required');
    }
    if (!CryptoService.canEncryptWithRsa(text)) {
      return TranslationHandler.get('encrypted_field_too_long');
    }
    return null;
  }

  String? _priceValidator(String? value) {
    final normalized = (value ?? '').trim().replaceAll(',', '.');
    final price = double.tryParse(normalized);
    if (price == null || price < 0) {
      return TranslationHandler.get('invalid_price');
    }
    return null;
  }

  Future<void> _onCreateContract() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final price = double.parse(
      _priceController.text.trim().replaceAll(',', '.'),
    );
    final priceString = price.toStringAsFixed(2);
    final publicKey = await _getUserPublicKey();

    if (!mounted) return;
    if (publicKey == null || publicKey.isEmpty) {
      SnackBarHandler.showError(
        context,
        TranslationHandler.get('missing_public_key'),
      );
      return;
    }

    try {
      context.read<TempContractCubit>().create(
        titleUserA: CryptoService.encryptWithPublicKey(
          plaintext: title,
          publicKeyBase64: publicKey,
        ),
        descriptionUserA: CryptoService.encryptWithPublicKey(
          plaintext: description,
          publicKeyBase64: publicKey,
        ),
        priceUserA: CryptoService.encryptWithPublicKey(
          plaintext: priceString,
          publicKeyBase64: publicKey,
        ),
        detailsHash: _generateDetailsHash(title, description, priceString),
      );
    } catch (error) {
      debugPrint('[CreateContractScreen] Encryption failed: $error');
      SnackBarHandler.showError(
        context,
        TranslationHandler.get('encrypted_field_too_long'),
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasDraft || _navigating) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.edit_note_outlined),
            title: Text(TranslationHandler.get('discard_draft_title')),
            content: Text(TranslationHandler.get('discard_draft_message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(TranslationHandler.get('keep_editing')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: Text(TranslationHandler.get('discard')),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<TempContractCubit, TempContractState>(
      listener: (context, state) async {
        if (state is TempContractSuccess && !_navigating) {
          _navigating = true;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShareContractScreen(
                tempContract: state.contract,
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim(),
                price:
                    double.tryParse(
                      _priceController.text.trim().replaceAll(',', '.'),
                    ) ??
                    0,
              ),
            ),
          );
          if (mounted) _navigating = false;
        } else if (state is TempContractError) {
          SnackBarHandler.showError(context, state.message);
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final discard = await _confirmDiscard();
          if (discard && context.mounted) Navigator.pop(context);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(TranslationHandler.get('new_contract')),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                final discard = await _confirmDiscard();
                if (discard && context.mounted) Navigator.pop(context);
              },
            ),
          ),
          body: SafeArea(
            top: false,
            child: YackContent(
              maxWidth: 680,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    YackPageHeading(
                      title: TranslationHandler.get('draft_agreement'),
                      subtitle: TranslationHandler.get('create_contract_desc'),
                    ),
                    const SizedBox(height: 24),
                    YackNotice(
                      message: TranslationHandler.get(
                        'contract_encryption_note',
                      ),
                      icon: Icons.lock_outline,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      TranslationHandler.get('agreement_terms'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _titleController,
                      maxLines: 1,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      autofillHints: const [AutofillHints.name],
                      validator: (value) =>
                          _encryptedFieldValidator(value, required: true),
                      decoration: InputDecoration(
                        labelText: TranslationHandler.get('title'),
                        hintText: TranslationHandler.get('title_hint'),
                        prefixIcon: const Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 5,
                      maxLines: 8,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      validator: _encryptedFieldValidator,
                      decoration: InputDecoration(
                        labelText: TranslationHandler.get('description'),
                        hintText: TranslationHandler.get('description_hint'),
                        helperText: TranslationHandler.get(
                          'encrypted_field_helper',
                        ),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        validator: _priceValidator,
                        onFieldSubmitted: (_) => _onCreateContract(),
                        decoration: InputDecoration(
                          labelText: TranslationHandler.get('price'),
                          hintText: TranslationHandler.get('price_hint'),
                          prefixIcon: const Icon(Icons.payments_outlined),
                          suffixText: TranslationHandler.get('currency'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    BlocBuilder<TempContractCubit, TempContractState>(
                      builder: (context, state) => PrimaryActionButton(
                        isLoading: state is TempContractLoading,
                        onClick: state is TempContractLoading
                            ? null
                            : _onCreateContract,
                        action: TranslationHandler.get('continue_to_invite'),
                        icon: Icons.arrow_forward,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScanContractScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(TranslationHandler.get('join_instead')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
