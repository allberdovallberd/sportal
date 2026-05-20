String stripHtmlToPlainText(String raw) {
  if (raw.trim().isEmpty) {
    return '';
  }

  var text = raw;
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
  text = text.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ');
  text = text.replaceAll(RegExp(r'</li>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  text = _decodeHtmlEntities(text);
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  return text.trim();
}

String _decodeHtmlEntities(String input) {
  var text = input
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
    final codePoint = int.tryParse(match.group(1) ?? '');
    if (codePoint == null) {
      return match.group(0) ?? '';
    }
    return String.fromCharCode(codePoint);
  });

  return text;
}
