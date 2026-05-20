enum ChannelPriority { high, priority, normal }

class TvChannel {
  const TvChannel({
    required this.name,
    required this.url,
    required this.priority,
    this.logo,
  });

  final String name;
  final String url;
  final ChannelPriority priority;
  final String? logo;

  factory TvChannel.fromJson(Map<String, dynamic> json) {
    return TvChannel(
      name: (json['name'] as String).trim(),
      url: json['url'] as String,
      priority: _parsePriority(json['priority'] as String?),
      logo: (json['logo'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['logo'] as String?,
    );
  }

  static ChannelPriority _parsePriority(String? value) {
    switch (value) {
      case 'high':
        return ChannelPriority.high;
      case 'priority':
        return ChannelPriority.priority;
      default:
        return ChannelPriority.normal;
    }
  }
}
