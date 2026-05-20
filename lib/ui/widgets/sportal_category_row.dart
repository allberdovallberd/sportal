import 'package:flutter/material.dart';

import '../sportal_colors.dart';
import '../sportal_text_styles.dart';

/// Horizontal scrollable row of pill-style category chips.
///
/// Inactive chips are pure white with a soft drop shadow (no outline).
/// Active chip uses [SportalColors.primaryBlue].
/// Padding behaviour: a small leading inset before the first chip,
/// but no trailing gap when scrolling reaches the right edge.
class SportalCategoryRow<T> extends StatelessWidget {
  const SportalCategoryRow({
    super.key,
    required this.items,
    required this.selectedKey,
    required this.keyOf,
    required this.labelOf,
    required this.onSelected,
    this.allLabel = 'Hemmesi',
    this.height = 36,
  });

  final List<T> items;
  final String? selectedKey;
  final String? Function(T item) keyOf;
  final String Function(T item) labelOf;
  final ValueChanged<String?> onSelected;
  final String allLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Vertical padding adds breathing room so the chip drop-shadow can
    // render fully (otherwise the shadow gets visually clipped by the row's
    // own bounds, which made the chips look flat).
    return SizedBox(
      height: height + 16,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        // clipBehavior none so the drop-shadows on each chip are never
        // scissored by the ListView's own bounding box.
        clipBehavior: Clip.none,
        // Leading inset so first chip isn't flush to the screen edge.
        // Tiny trailing inset so the right-most chip's shadow isn't clipped.
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final key = isAll ? null : keyOf(items[index - 1]);
          final label = isAll ? allLabel : labelOf(items[index - 1]);
          final isActive = selectedKey == key;

          return SizedBox(
            height: height,
            child: _CategoryPill(
              label: label,
              active: isActive,
              onTap: () => onSelected(key),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active ? SportalColors.primaryBlue : Colors.white;
    final fg = active ? Colors.white : const Color(0xFF1A2349);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: active
                    ? Colors.black.withValues(alpha: 0.32)
                    : Colors.black.withValues(alpha: 0.32),
                blurRadius: active ? 16 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            style: SportalTextStyles.b2.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
