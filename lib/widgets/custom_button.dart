import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final ButtonStyle? style;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.style,
    this.isOutlined = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ??
        (isOutlined
            ? OutlinedButton.styleFrom(
                foregroundColor:
                    foregroundColor ?? Theme.of(context).colorScheme.primary,
                side: BorderSide(
                  color:
                      foregroundColor ?? Theme.of(context).colorScheme.primary,
                ),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              )
            : ElevatedButton.styleFrom(
                backgroundColor:
                    backgroundColor ?? Theme.of(context).colorScheme.primary,
                foregroundColor: foregroundColor ?? Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ));

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isOutlined
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: effectiveStyle,
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: effectiveStyle,
      child: child,
    );
  }
}
