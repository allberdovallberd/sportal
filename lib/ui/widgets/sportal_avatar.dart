import 'package:flutter/material.dart';

import '../../core/network/sportal_api_config.dart';

/// Reusable circular user avatar.
///
/// Renders the user's avatar image when [avatar] is provided, otherwise falls
/// back to a deterministic colored circle showing the first letter of the
/// user's [name] (or `?` when name is empty).
///
/// [avatar] may be either an absolute URL (`https://...`) or a relative path
/// returned by the backend (e.g. `/sport/uploads/avatar_xxx.jpg`); both forms
/// are resolved against [SportalApiConfig.uploadBaseUrl].
class SportalAvatar extends StatelessWidget {
  const SportalAvatar({
    super.key,
    required this.name,
    this.avatar,
    this.size = 36,
    this.borderColor,
  });

  final String name;
  final String? avatar;
  final double size;
  final Color? borderColor;

  static const List<Color> _palette = [
    Color(0xFF4B90FF),
    Color(0xFFEF5DA8),
    Color(0xFF7DD3FC),
    Color(0xFFFFB454),
    Color(0xFF34D399),
    Color(0xFFA78BFA),
    Color(0xFFF472B6),
    Color(0xFF60A5FA),
  ];

  String? _resolvedUrl() {
    final raw = avatar?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    final base = SportalApiConfig.current.uploadBaseUrl.replaceFirst(
      RegExp(r'/$'),
      '',
    );
    return raw.startsWith('/') ? '$base$raw' : '$base/$raw';
  }

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final ch = trimmed.characters.first.toUpperCase();
    return ch;
  }

  Color get _bgColor {
    if (name.isEmpty) return _palette.first;
    final hash = name.codeUnits.fold<int>(0, (a, c) => (a + c) & 0x7fffffff);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl();
    final border = borderColor != null
        ? Border.all(color: borderColor!, width: 1.5)
        : null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _bgColor,
        border: border,
        image: url != null
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: url == null
          ? Text(
              _initial,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w700,
                fontSize: size * 0.42,
                height: 1,
              ),
            )
          : null,
    );
  }
}
