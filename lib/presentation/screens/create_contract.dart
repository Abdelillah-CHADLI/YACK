import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:yack/logic/cubits/contract/temp_contract_cubit.dart';
import 'package:yack/logic/cubits/contract/temp_contract_state.dart';
import 'package:yack/logic/services/auth/cryptoService.dart';
import 'package:yack/presentation/screens/scan_contract.dart';
import 'package:yack/presentation/screens/shareContract.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/presentation/theme/theme.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/secondaryActionButton.dart';

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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String _generateDetailsHash(String title, String description, String price) {
    final combined = '$title|$description|$price';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String?> _getUserPublicKey() async {
    try {
      final box = await Hive.openBox('user');
      return box.get('publicKey')?.toString();
    } catch (_) {
      return null;
    }
  }

  void _onCreateContract() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);
    if (price == null || price < 0) {
      SnackBarHandler.showError(context, TranslationHandler.get('invalid_price'));
      return;
    }
    final priceStr = price.toStringAsFixed(2);

    final publicKey = await _getUserPublicKey();
    if (publicKey == null || publicKey.isEmpty) {
      SnackBarHandler.showError(context, TranslationHandler.get('missing_public_key'));
      return;
    }

    final detailsHash = _generateDetailsHash(title, description, priceStr);

    final titleUserA = CryptoService.encryptWithPublicKey(
      plaintext: title,
      publicKeyBase64: publicKey,
    );
    final descriptionUserA = CryptoService.encryptWithPublicKey(
      plaintext: description,
      publicKeyBase64: publicKey,
    );
    final priceUserA = CryptoService.encryptWithPublicKey(
      plaintext: priceStr,
      publicKeyBase64: publicKey,
    );

    context.read<TempContractCubit>().create(
      titleUserA: titleUserA,
      descriptionUserA: descriptionUserA,
      priceUserA: priceUserA,
      detailsHash: detailsHash,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return BlocListener<TempContractCubit, TempContractState>(
      listener: (context, state) {
        if (state is TempContractSuccess) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShareContractScreen(
                tempContract: state.contract,
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim(),
                price: double.tryParse(_priceController.text.trim()) ?? 0,
              ),
            ),
          );
        } else if (state is TempContractError) {
          SnackBarHandler.showError(context, state.message);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            TranslationHandler.get('new_contract'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              // --- Header ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: colors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        TranslationHandler.get('create_contract_desc'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Title ---
              _buildFieldLabel(
                context,
                TranslationHandler.get('title'),
                Icons.title_rounded,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                maxLines: 1,
                textInputAction: TextInputAction.next,
                style: theme.textTheme.bodyLarge,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? TranslationHandler.get('title_required')
                    : null,
                decoration: InputDecoration(
                  hintText: TranslationHandler.get('title_hint'),
                  prefixIcon: Icon(
                    Icons.short_text_rounded,
                    color: colors.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Description ---
              _buildFieldLabel(
                context,
                TranslationHandler.get('description'),
                Icons.description_outlined,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: TranslationHandler.get('description_hint'),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8, top: 12),
                    child: Icon(
                      Icons.notes_rounded,
                      color: colors.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),

              // --- Price ---
              _buildFieldLabel(
                context,
                TranslationHandler.get('price'),
                Icons.attach_money_rounded,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: TranslationHandler.get('price_hint'),
                  prefixIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(AppTheme.radiusMd),
                        bottomLeft: Radius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: Text(
                      TranslationHandler.get('currency'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),

              const SizedBox(height: 32),

              // --- Actions ---
              BlocBuilder<TempContractCubit, TempContractState>(
                builder: (context, state) {
                  final isLoading = state is TempContractLoading;
                  return Column(
                    children: [
                      PrimaryActionButton(
                        isLoading: isLoading,
                        onClick: isLoading ? null : _onCreateContract,
                        action: TranslationHandler.get('add_contract'),
                      ),
                      const SizedBox(height: 12),
                      SecondaryActionButton(
                        onClick: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ScanContractScreen(),
                            ),
                          );
                        },
                        action: TranslationHandler.get('scan_contract_qr'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(BuildContext context, String text, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
