import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/logic/services/snackBarHandler.dart';
import 'package:yack/logic/services/user/user_service.dart';
import 'settingsSheet.dart';

class LanguageSettingsSheet extends StatefulWidget {
  const LanguageSettingsSheet({super.key});

  @override
  State<LanguageSettingsSheet> createState() => _LanguageSettingsSheetState();
}

class _LanguageSettingsSheetState extends State<LanguageSettingsSheet> {
  late String _selectedLanguage;

  final Map<String, String> _languageFlags = const {
    'ar': '🇩🇿',
    'en': '🇺🇸',
    'fr': '🇫🇷',
  };

  @override
  void initState() {
    super.initState();
    _selectedLanguage = TranslationHandler.currentLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSheet<String>(
      title: TranslationHandler.get('language_settings'),
      options: [
        for (final languageCode in _languageFlags.keys)
          SettingOption<String>(
            title:
                '${_languageFlags[languageCode]} ${TranslationHandler.get(_languageNameKey(languageCode))}',
            type: SettingType.radioTile,
            value: languageCode,
            groupValue: _selectedLanguage,
            onChanged: (value) {
              setState(() => _selectedLanguage = value);
            },
          ),
      ],
      applyLabel: TranslationHandler.get('apply'),
      onApply: () async {
        final box = Hive.box('user');
        var serverUpdated = true;
        try {
          await UserService().updateProfile(language: _selectedLanguage);
        } catch (_) {
          serverUpdated = false;
        }
        await TranslationHandler.changeLanguage(_selectedLanguage);
        await box.put('language', _selectedLanguage);
        if (!context.mounted) return;
        if (serverUpdated) {
          SnackBarHandler.showSuccess(
            context,
            TranslationHandler.get('language_updated'),
          );
        } else {
          SnackBarHandler.showWarning(
            context,
            TranslationHandler.get('language_updated_device_only'),
          );
        }
        Navigator.pop(context);
      },
    );
  }

  String _languageNameKey(String code) {
    switch (code) {
      case 'fr':
        return 'french';
      case 'ar':
        return 'arabic';
      case 'en':
      default:
        return 'english';
    }
  }
}
