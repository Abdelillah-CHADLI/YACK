import 'package:flutter/material.dart';

class TitleWidget extends StatelessWidget {
  final String text;

  const TitleWidget({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text,
        style: theme.textTheme.headlineMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}
