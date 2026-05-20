import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../sportal_colors.dart';
import '../sportal_text_styles.dart';

/// Shared search field used across Home, Federations, and other list pages.
///
/// Renders a soft surface input with a leading search icon, an optional
/// trailing clear (X) button that appears only when text is present, and
/// debounced/onSubmitted callbacks suitable for search-as-you-type flows.
class SportalSearchBar extends StatelessWidget {
  const SportalSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Gözleg...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: SportalColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: SportalTextStyles.b2.copyWith(fontSize: 15, height: 1.2),
        textAlignVertical: TextAlignVertical.center,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: SportalTextStyles.b2.copyWith(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 44,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset(
              'assets/icons/search.svg',
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                Colors.white.withValues(alpha: 0.65),
                BlendMode.srcIn,
              ),
              placeholderBuilder: (_) => Icon(
                Icons.search_rounded,
                color: Colors.white.withValues(alpha: 0.65),
                size: 18,
              ),
            ),
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                onPressed: () {
                  controller.clear();
                  onClear?.call();
                  onChanged?.call('');
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
