import 'package:flutter/material.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';

enum SettingType { switchTile, radioTile }

class SettingOption<T> {
  final String title;
  final String? subtitle;
  final SettingType type;
  final T value;
  final T? groupValue; // used for radio
  final ValueChanged<T> onChanged;

  SettingOption({
    required this.title,
    this.subtitle,
    required this.type,
    required this.value,
    this.groupValue,
    required this.onChanged,
  });
}

class SettingsSheet<T> extends StatelessWidget {
  final String title;
  final List<SettingOption<T>> options;
  final VoidCallback? onApply;
  final String? applyLabel;

  const SettingsSheet({
    super.key,
    required this.title,
    required this.options,
    this.onApply,
    this.applyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: AppTheme.normal,
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
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
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: options.map((opt) {
                        if (opt.type == SettingType.switchTile) {
                          return SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text(
                              opt.title,
                              style: theme.textTheme.titleSmall,
                            ),
                            subtitle: opt.subtitle != null
                                ? Text(opt.subtitle!)
                                : null,
                            value: opt.value as bool,
                            onChanged: (v) => opt.onChanged(v as T),
                          );
                        }
                        return RadioListTile<T>(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          title: Text(
                            opt.title,
                            style: theme.textTheme.titleSmall,
                          ),
                          subtitle: opt.subtitle != null
                              ? Text(opt.subtitle!)
                              : null,
                          value: opt.value,
                          groupValue: opt.groupValue,
                          onChanged: (v) {
                            if (v != null) opt.onChanged(v);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (onApply != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onApply,
                    child: Text(applyLabel ?? TranslationHandler.get('done')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
