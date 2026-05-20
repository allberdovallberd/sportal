import '../../../core/network/sportal_api_config.dart';

class SportCategoryModel {
  const SportCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.newsCount,
  });

  final String id;
  final String name;
  final String slug;
  final int newsCount;

  factory SportCategoryModel.fromJson(Map<String, dynamic> json) {
    return SportCategoryModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      newsCount:
          int.tryParse(
            (json['news_count'] ?? json['newsCount'] ?? 0).toString(),
          ) ??
          0,
    );
  }
}

class NewsModel {
  const NewsModel({
    required this.id,
    required this.title,
    required this.content,
    required this.thumbnail,
    required this.categoryId,
    required this.categoryName,
    required this.publishedAt,
    required this.createdAt,
    this.likesCount = 0,
    this.sharesCount = 0,
    this.isLiked = false,
    this.authorEmail = '',
  });

  final String id;
  final String title;
  final String content;
  final String thumbnail;
  final String categoryId;
  final String categoryName;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final int likesCount;
  final int sharesCount;
  final bool isLiked;
  final String authorEmail;

  DateTime? get displayDate => publishedAt ?? createdAt;

  String resolveThumbnail(SportalApiConfig config) {
    if (thumbnail.isEmpty) {
      return '';
    }

    if (thumbnail.startsWith('http://') || thumbnail.startsWith('https://')) {
      return thumbnail;
    }

    if (thumbnail.startsWith('/')) {
      return '${config.uploadBaseUrl}$thumbnail';
    }

    return '${config.uploadBaseUrl}/$thumbnail';
  }

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'];
    final categoryMap = categoryJson is Map<String, dynamic>
        ? categoryJson
        : const <String, dynamic>{};

    DateTime? tryParseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    final authorJson = json['author'];
    final authorMap = authorJson is Map<String, dynamic>
        ? authorJson
        : const <String, dynamic>{};

    return NewsModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      thumbnail: (json['thumbnail'] ?? '').toString(),
      categoryId:
          (json['category_id'] ?? json['categoryId'] ?? categoryMap['id'] ?? '')
              .toString(),
      categoryName:
          (categoryMap['name'] ??
                  json['category_name'] ??
                  json['categoryName'] ??
                  'Sport')
              .toString(),
      publishedAt: tryParseDate(json['published_at'] ?? json['publishedAt']),
      createdAt: tryParseDate(json['created_at'] ?? json['createdAt']),
      likesCount:
          int.tryParse(
            (json['likes_count'] ?? json['likesCount'] ?? 0).toString(),
          ) ??
          0,
      sharesCount:
          int.tryParse(
            (json['shares_count'] ?? json['sharesCount'] ?? 0).toString(),
          ) ??
          0,
      isLiked: json['is_liked'] == true || json['isLiked'] == true,
      authorEmail: (authorMap['email'] ?? json['author_email'] ?? '')
          .toString(),
    );
  }
}
