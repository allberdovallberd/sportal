import 'package:flutter/material.dart';

import '../sportal_colors.dart';
import '../sportal_text_styles.dart';

class SportalPrimaryButton extends StatelessWidget {
  const SportalPrimaryButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          disabledBackgroundColor: SportalColors.disabledButton,
          disabledForegroundColor: Colors.white,
          backgroundColor: SportalColors.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(29),
          ),
          textStyle: SportalTextStyles.h3.copyWith(fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }
}
