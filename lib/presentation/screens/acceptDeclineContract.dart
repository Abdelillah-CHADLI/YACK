import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';
import 'package:yack/presentation/widgets/secondaryActionButton.dart';
import 'package:yack/presentation/widgets/yack_ui.dart';

/// Readable, document-led review used by both agreement participants.
class AcceptDeclineContractScreen extends StatefulWidget {
  final String title;
  final double price;
  final String? description;
  final String userFirstName;
  final String userLastName;
  final bool isUserA;

  const AcceptDeclineContractScreen({
    super.key,
    required this.title,
    required this.price,
    required this.userFirstName,
    required this.userLastName,
    this.description,
    this.isUserA = false,
  });

  @override
  State<AcceptDeclineContractScreen> createState() =>
      _AcceptDeclineContractScreenState();
}

class _AcceptDeclineContractScreenState
    extends State<AcceptDeclineContractScreen> {
  String? _translatedTitle;
  String? _translatedDescription;
  bool _isTranslating = false;

  String get _displayName {
    final value = '${widget.userFirstName} ${widget.userLastName}'.trim();
    return value.isEmpty ? TranslationHandler.get('unknown') : value;
  }

  Future<void> _requestTranslation() async {
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.translate),
            title: Text(TranslationHandler.get('translate_contract')),
            content: Text(
              TranslationHandler.get('translation_privacy_disclosure'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(TranslationHandler.get('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(TranslationHandler.get('continue_action')),
              ),
            ],
          ),
        ) ??
        false;
    if (approved) await _translateContent();
  }

  Future<void> _translateContent() async {
    if (_isTranslating) return;
    setState(() => _isTranslating = true);

    try {
      final target = TranslationHandler.currentLanguage;
      var source = 'en';
      final sample = '${widget.title} ${widget.description ?? ''}';
      if (sample.contains(RegExp(r'[\u0600-\u06FF]'))) {
        source = 'ar';
      } else if (sample.contains(
        RegExp(r'[àâäéèêëïîôùûüÿæœçÀÂÄÉÈÊËÏÎÔÙÛÜŸÆŒÇ]'),
      )) {
        source = 'fr';
      }

      if (source == target) {
        if (mounted) {
          SnackBarHandler.showMessage(
            context,
            TranslationHandler.get('content_already_in_language'),
          );
        }
        return;
      }

      Future<String> translate(String text) async {
        if (text.trim().isEmpty) return '';
        final uri = Uri.https('api.mymemory.translated.net', '/get', {
          'q': text,
          'langpair': '$source|$target',
        });
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) {
          throw StateError('Translation request failed');
        }
        final payload = json.decode(response.body);
        return payload['responseData']?['translatedText']?.toString() ?? text;
      }

      final results = await Future.wait([
        translate(widget.title),
        translate(widget.description ?? ''),
      ]);
      if (mounted) {
        setState(() {
          _translatedTitle = results[0];
          _translatedDescription = results[1];
        });
      }
    } catch (error) {
      debugPrint('[ContractReview] Translation failed: $error');
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('translation_failed'),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final description = (_translatedDescription?.trim().isNotEmpty ?? false)
        ? _translatedDescription!
        : (widget.description?.trim().isNotEmpty ?? false)
        ? widget.description!
        : TranslationHandler.get('accept_decline_description');

    return Scaffold(
      appBar: AppBar(title: Text(TranslationHandler.get('contract_review'))),
      body: SafeArea(
        top: false,
        child: YackContent(
          maxWidth: 680,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: ListView(
            children: [
              YackPageHeading(
                eyebrow: TranslationHandler.get('review_before_signing'),
                title: _translatedTitle ?? widget.title,
                subtitle: TranslationHandler.resolve(
                  'from_user',
                  params: {'name': _displayName},
                ),
              ),
              const SizedBox(height: 22),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        border: Border(
                          bottom: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              TranslationHandler.get('agreement_terms'),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (_translatedTitle != null)
                            Text(
                              TranslationHandler.get('translated'),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TranslationHandler.get('description'),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            description,
                            textAlign: TextAlign.start,
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 18),
                          Text(
                            TranslationHandler.get('price_label'),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${widget.price.toStringAsFixed(2)} '
                            '${TranslationHandler.get('currency')}',
                            textDirection: TextDirection.ltr,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              YackNotice(
                message: TranslationHandler.get('binding_warning'),
                tone: YackNoticeTone.warning,
                icon: Icons.draw_outlined,
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _isTranslating ? null : _requestTranslation,
                icon: _isTranslating
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.translate),
                label: Text(TranslationHandler.get('translate_contract')),
              ),
              const SizedBox(height: 18),
              PrimaryActionButton(
                action: TranslationHandler.get('accept_contract'),
                icon: Icons.draw_outlined,
                onClick: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 10),
              SecondaryActionButton(
                action: TranslationHandler.get('decline_contract'),
                destructive: true,
                icon: Icons.close,
                onClick: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
