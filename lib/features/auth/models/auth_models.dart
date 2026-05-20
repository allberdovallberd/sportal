enum SportalUserRole { admin, user, guest }

SportalUserRole parseSportalRole(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'admin':
      return SportalUserRole.admin;
    case 'user':
      return SportalUserRole.user;
    default:
      return SportalUserRole.guest;
  }
}

class SportalUser {
  const SportalUser({
    required this.id,
    required this.email,
    required this.role,
    required this.isVerified,
    this.username,
    this.avatar,
  });

  final String id;
  final String email;
  final SportalUserRole role;
  final bool isVerified;
  final String? username;
  final String? avatar;

  factory SportalUser.fromJson(Map<String, dynamic> json) {
    final rawAvatar = json['avatar'];
    final rawUsername = json['username'];
    return SportalUser(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: parseSportalRole(json['role']?.toString()),
      isVerified: json['is_verified'] == true || json['isVerified'] == true,
      username: rawUsername is String && rawUsername.trim().isNotEmpty
          ? rawUsername
          : null,
      avatar: rawAvatar is String && rawAvatar.trim().isNotEmpty
          ? rawAvatar
          : null,
    );
  }
}

class AuthSuccessPayload {
  const AuthSuccessPayload({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final SportalUser user;

  factory AuthSuccessPayload.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return AuthSuccessPayload(
      accessToken: (json['access_token'] ?? json['accessToken'] ?? '')
          .toString(),
      refreshToken: (json['refresh_token'] ?? json['refreshToken'] ?? '')
          .toString(),
      user: SportalUser.fromJson(
        userJson is Map<String, dynamic> ? userJson : const <String, dynamic>{},
      ),
    );
  }
}
