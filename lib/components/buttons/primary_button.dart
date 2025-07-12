import 'package:flutter/material.dart';
import '../app_colors.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed; // Now nullable
  final double? width;
  final double? height;
  final double? fontSize;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width = 250,
    this.height = 60,
    this.fontSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: isEnabled
            ? AppColors.primaryGradient
            : LinearGradient(
          colors: [
            AppColors.primaryOrange.withValues(alpha: 0.3),
            AppColors.primaryOrange.withValues(alpha: 0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: isEnabled ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            spreadRadius: 3,
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: isEnabled ? onPressed : null,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                fontFamily: 'AlfaSlabOne',
                color: isEnabled
                    ? AppColors.white
                    : AppColors.white.withValues(alpha: 0.5),
                letterSpacing: 2.0,
                shadows: isEnabled ? const [
                  Shadow(
                    offset: Offset(2, 2),
                    blurRadius: 4,
                    color: Colors.black45,
                  ),
                ] : const [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 2,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}