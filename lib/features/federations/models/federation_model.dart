class FederationModel {
  const FederationModel({
    required this.id,
    required this.name,
    required this.description,
    required this.contacts,
    required this.logo,
    required this.thumbnail,
    required this.president,
    required this.address,
    required this.phone,
    required this.email,
  });

  final String id;
  final String name;
  final String description;
  final String contacts;
  final String logo;
  final String thumbnail;
  final String president;
  final String address;
  final String phone;
  final String email;

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static String _extractPhone(String text) {
    if (text.isEmpty) return '';
    final matches = RegExp(r'(\+?\d[\d\-\s]{6,}\d)').allMatches(text);
    if (matches.isEmpty) return '';
    return matches.first.group(0)?.trim() ?? '';
  }

  static String _extractEmail(String text) {
    if (text.isEmpty) return '';
    final match = RegExp(
      r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
    ).firstMatch(text);
    return match?.group(0)?.trim() ?? '';
  }

  factory FederationModel.fromJson(Map<String, dynamic> json) {
    final contactsDynamic = json['contacts'];
    final contactsMap = contactsDynamic is Map<String, dynamic>
        ? contactsDynamic
        : null;
    final contactsText = contactsMap != null
        ? contactsMap.entries
              .where((entry) => _string(entry.value).isNotEmpty)
              .map((entry) => '${entry.key}: ${_string(entry.value)}')
              .join('\n')
        : _string(contactsDynamic);

    final phone = _string(
      json['phone'] ?? json['phone_number'] ?? contactsMap?['phone'],
    );
    final email = _string(json['email'] ?? contactsMap?['email']);

    return FederationModel(
      id: _string(json['id']),
      name: _string(json['name']),
      description: _string(json['description']),
      contacts: contactsText,
      logo: _string(json['logo']),
      thumbnail: _string(json['thumbnail']),
      president: _string(json['president']),
      address: _string(json['address']),
      phone: phone.isEmpty ? _extractPhone(contactsText) : phone,
      email: email.isEmpty ? _extractEmail(contactsText) : email,
    );
  }
}
