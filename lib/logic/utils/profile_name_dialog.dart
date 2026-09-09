import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/logic/utils/validator.dart';
import 'package:yack/presentation/widgets/inputFormWidget.dart';
import 'package:yack/presentation/widgets/primaryActionButton.dart';

import '../services/auth/account_service.dart';

Future<void> showEditNameDialog(BuildContext context) async {
  final userBox = Hive.box('user');
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _EditNameDialog(
      initialFirstName:
          userBox.get('firstName', defaultValue: '')?.toString() ?? '',
      initialLastName:
          userBox.get('lastName', defaultValue: '')?.toString() ?? '',
    ),
  );

  if (saved == true && context.mounted) {
    SnackBarHandler.showSuccess(
      context,
      TranslationHandler.get('name_updated_successfully'),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({
    required this.initialFirstName,
    required this.initialLastName,
  });

  final String initialFirstName;
  final String initialLastName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.initialFirstName);
    _lastNameController = TextEditingController(text: widget.initialLastName);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      await AccountService().updateProfileName(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
    } catch (_) {
      if (mounted) {
        SnackBarHandler.showError(
          context,
          TranslationHandler.get('error_updating_name'),
        );
      }
      return;
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: color.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        TranslationHandler.get('edit_name'),
        textAlign: TextAlign.center,
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: min(480, MediaQuery.sizeOf(context).width),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextFormField(
                  controller: _firstNameController,
                  hintText: TranslationHandler.get('first_name'),
                  labelText: TranslationHandler.get('first_name'),
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      Validator.name(value, fieldName: 'first_name'),
                ),
                const SizedBox(height: 12),
                CustomTextFormField(
                  controller: _lastNameController,
                  hintText: TranslationHandler.get('last_name'),
                  labelText: TranslationHandler.get('last_name'),
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      Validator.name(value, fieldName: 'last_name'),
                ),
                const SizedBox(height: 20),
                PrimaryActionButton(
                  action: TranslationHandler.get('save'),
                  onClick: _save,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    TranslationHandler.get('cancel'),
                    style: TextStyle(color: color.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
