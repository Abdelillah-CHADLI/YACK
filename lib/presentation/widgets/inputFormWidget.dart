import 'package:flutter/material.dart';
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

    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextFormField(
        textDirection: TextDirection.ltr,
        controller: _internalController,
        obscureText: widget.isPassword ? _obscureText : false,
        textAlign: TextAlign.left,
        maxLines: 1,
        keyboardType: widget.keyboardType,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.normal,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
            fontSize: 14,
            color: color.onSurfaceVariant.withValues(alpha: 0.75),
          ),
          prefixIcon: widget.icon != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(widget.icon, size: 22),
                )
              : null,
          suffixIcon: widget.isPassword
              ? IconButton(
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
      ),
    );
  }
}
