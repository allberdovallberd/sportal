import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/sportal_api_client.dart';
import '../../../core/network/sportal_api_providers.dart';
import '../models/home_models.dart';

class HomeApiClient {
  HomeApiClient({required SportalApiClient api}) : _api = api;

  final SportalApiClient _api;

  Future<List<SportCategoryModel>> fetchCategories() async {
    final response = await _api.get('/categories');
    final data = _extractItems(response['data']);

    return data
        .whereType<Map<String, dynamic>>()
        .map(SportCategoryModel.fromJson)
        .toList();
  }

  Future<List<NewsModel>> fetchNews({
    String? categoryId,
    String? search,
    int page = 1,
    int limit = 100,
  }) async {
    final response = await _api.get(
      '/news',
      query: <String, dynamic>{
        'page': page,
        'per_page': limit,
        if (categoryId != null && categoryId.isNotEmpty)
          'category_id': categoryId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    final data = _extractItems(response['data']);

    return data
        .whereType<Map<String, dynamic>>()
        .map(NewsModel.fromJson)
        .toList();
  }

  Future<NewsModel?> fetchNewsById(String id) async {
    if (id.trim().isEmpty) {
      return null;
    }

    final response = await _api.get('/news/${id.trim()}');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    return NewsModel.fromJson(data);
  }

  /// Toggles like on a news item. Returns the new liked state.
  Future<bool> likeNews({required String id, String? accessToken}) async {
    final response = await _api.post(
      '/news/$id/like',
      accessToken: accessToken,
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data['liked'] == true;
    }
    return false;
  }

  /// Tracks a share event for a news item.
  Future<void> shareNews({
    required String id,
    required String platform,
    String? accessToken,
  }) async {
    await _api.post(
      '/news/$id/share',
      accessToken: accessToken,
      body: {'platform': platform},
    );
  }

  List<dynamic> _extractItems(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) {
        return items;
      }
    }
    return const <dynamic>[];
  }
}

final homeApiClientProvider = Provider<HomeApiClient>((ref) {
  final api = ref.watch(sportalApiClientProvider);
  return HomeApiClient(api: api);
});
