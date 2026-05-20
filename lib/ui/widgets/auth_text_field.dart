import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../sportal_colors.dart';
import '../sportal_text_styles.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.hintText,
    this.leadingIcon,
    this.leadingSvgAsset,
    required this.leadingColor,
    required this.onChanged,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.trailingIcon,
    this.trailingColor = SportalColors.textSecondary,
    this.onTrailingTap,
    this.isError = false,
  }) : assert(
         leadingIcon != null || leadingSvgAsset != null,
         'Provide either leadingIcon or leadingSvgAsset',
       );

  final String hintText;
  final IconData? leadingIcon;
  final String? leadingSvgAsset;
  final Color leadingColor;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? trailingIcon;
  final Color trailingColor;
  final VoidCallback? onTrailingTap;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final Widget leadingWidget;
    if (leadingSvgAsset != null) {
      leadingWidget = SvgPicture.asset(
        leadingSvgAsset!,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(leadingColor, BlendMode.srcIn),
      );
    } else {
      leadingWidget = Icon(leadingIcon, color: leadingColor, size: 20);
    }

    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: SportalColors.fieldBackground,
        borderRadius: BorderRadius.circular(10),
        border: isError
            ? Border.all(color: SportalColors.errorRed, width: 1.5)
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: Row(
        children: [
          leadingWidget,
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: keyboardType,
              obscureText: obscureText,
              style: SportalTextStyles.b1,
              cursorColor: SportalColors.primaryBlue,
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                hintStyle: SportalTextStyles.b1.copyWith(
                  color: SportalColors.textSecondary,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (trailingIcon != null)
            GestureDetector(
              onTap: onTrailingTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Icon(trailingIcon, color: trailingColor, size: 22),
              ),
            ),
        ],
      ),
    );
  }
}
