import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/home_models.dart';
import '../services/home_api_client.dart';

final homeRefreshKeyProvider = StateProvider<int>((ref) => 0);

final selectedHomeCategoryIdProvider = StateProvider<String?>((ref) => null);

final homeSearchQueryProvider = StateProvider<String>((ref) => '');
final homeVisibleCountProvider = StateProvider<int>((ref) => 20);

final homeCategoriesProvider = FutureProvider<List<SportCategoryModel>>((
  ref,
) async {
  ref.watch(homeRefreshKeyProvider);
  final api = ref.watch(homeApiClientProvider);
  return api.fetchCategories();
});

final homeNewsProvider = FutureProvider<List<NewsModel>>((ref) async {
  ref.watch(homeRefreshKeyProvider);
  final api = ref.watch(homeApiClientProvider);
  final categoryId = ref.watch(selectedHomeCategoryIdProvider);
  final search = ref.watch(homeSearchQueryProvider);
  return api.fetchNews(categoryId: categoryId, search: search, limit: 100);
});

final homeNewsDetailProvider = FutureProvider.family<NewsModel, String>((
  ref,
  newsId,
) async {
  final api = ref.watch(homeApiClientProvider);
  final detail = await api.fetchNewsById(newsId);
  if (detail == null) {
    throw StateError('News not found');
  }
  return detail;
});
