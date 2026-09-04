import 'package:flutter/material.dart';
import 'package:yack/logic/services/translation_handler.dart';
import 'package:yack/presentation/theme/theme.dart';

class CustomTextFormField extends StatefulWidget {
  final String hintText;
  final String? labelText;
  final bool isPassword;
  final Color? fillColor;
  final IconData? icon;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? helperText;
  final ValueChanged<String>? onFieldSubmitted;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final int maxLines;

  const CustomTextFormField({
    super.key,
    required this.hintText,
    this.labelText,
    this.isPassword = false,
    this.fillColor,
    this.icon,
    this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.helperText,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  State<CustomTextFormField> createState() => _CustomTextFormFieldState();
}

class _CustomTextFormFieldState extends State<CustomTextFormField> {
  late final TextEditingController _internalController;
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;

    // Use external controller if available, otherwise create once
    _internalController = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    // Only dispose if WE created the controller
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final contentDirection =
        widget.keyboardType == TextInputType.emailAddress ||
            widget.keyboardType == TextInputType.phone ||
            widget.keyboardType == TextInputType.number ||
            widget.keyboardType ==
                const TextInputType.numberWithOptions(decimal: true)
        ? TextDirection.ltr
        : null;

    return TextFormField(
      textDirection: contentDirection,
      controller: _internalController,
      obscureText: widget.isPassword ? _obscureText : false,
      textAlign: TextAlign.start,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onFieldSubmitted,
      textCapitalization: widget.textCapitalization,
      enabled: widget.enabled,
      autocorrect: !widget.isPassword,
      enableSuggestions: !widget.isPassword,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: widget.labelText ?? widget.hintText,
        hintText: widget.hintText,
        helperText: widget.helperText,
        prefixIcon: widget.icon != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(widget.icon, size: 22),
              )
            : null,
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: TranslationHandler.get(
                  _obscureText ? 'show_password' : 'hide_password',
                ),
                icon: AnimatedSwitcher(
                  duration: AppTheme.fast,
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    key: ValueKey(_obscureText),
                    color: color.onSurfaceVariant,
                  ),
                ),
                onPressed: () => setState(() {
                  _obscureText = !_obscureText;
                }),
              )
            : null,
      ),
      validator: widget.validator,
    );
  }
}
