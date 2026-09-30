import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

enum AppButtonStyle { primary, secondary, text }

/// The one button used across the app. Always at least 48dp tall.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = AppButtonStyle.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final text = Text(label);
    final iconWidget = icon == null ? null : Icon(icon, size: 20);
    const minSize = Size(AppSpacing.minTouch, AppSpacing.minTouch);

    switch (style) {
      case AppButtonStyle.primary:
        return iconWidget == null
            ? FilledButton(onPressed: onPressed, child: text)
            : FilledButton.icon(
                onPressed: onPressed,
                icon: iconWidget,
                label: text,
              );
      case AppButtonStyle.secondary:
        return iconWidget == null
            ? OutlinedButton(onPressed: onPressed, child: text)
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: iconWidget,
                label: text,
              );
      case AppButtonStyle.text:
        return iconWidget == null
            ? TextButton(
                onPressed: onPressed,
                style: TextButton.styleFrom(minimumSize: minSize),
                child: text,
              )
            : TextButton.icon(
                onPressed: onPressed,
                style: TextButton.styleFrom(minimumSize: minSize),
                icon: iconWidget,
                label: text,
              );
    }
  }
}
