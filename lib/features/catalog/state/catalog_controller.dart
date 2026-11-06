import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/catalog_repository.dart';

class CatalogController extends ChangeNotifier {
  CatalogController(this.repository);
  final CatalogRepository repository;
  List<CatalogItem> items = [];
  int page = 1, pageSize = 20, totalItems = 0, totalPages = 0;
  String search = '',
      sort = 'code',
      manufacturerFilterLabel = 'Tất cả nhà sản xuất';
  Map<String, String> filters = {};
  bool loading = false;
  String? error;
  int _generation = 0;
  bool _disposed = false;
  Future<void> load({
    int? page,
    int? pageSize,
    String? search,
    String? sort,
    Map<String, String>? filters,
  }) async {
    final generation = ++_generation, sentToken = repository.api.token;
    this.page = page ?? this.page;
    this.pageSize = pageSize ?? this.pageSize;
    this.search = search ?? this.search;
    this.sort = sort ?? this.sort;
    this.filters = Map.of(filters ?? this.filters);
    loading = true;
    items = [];
    error = null;
    _emit();
    try {
      final result = await repository.list(
        page: this.page,
        pageSize: this.pageSize,
        search: this.search,
        sort: this.sort,
        filters: this.filters,
      );
      if (!_current(generation, sentToken)) return;
      if (result.totalPages > 0 && this.page > result.totalPages) {
        await load(page: result.totalPages);
        return;
      }
      items = result.items;
      totalItems = result.totalItems;
      totalPages = result.totalPages;
      this.page = totalPages == 0 ? 1 : result.page;
    } on ApiException catch (e) {
      if (_current(generation, sentToken)) {
        error = e.message;
        totalItems = 0;
        totalPages = 0;
      }
    } catch (_) {
      if (_current(generation, sentToken)) {
        error = 'Không đọc được danh mục. Vui lòng tải lại.';
      }
    } finally {
      if (_current(generation, sentToken)) {
        loading = false;
        _emit();
      }
    }
  }

  bool _current(int generation, String? token) =>
      !_disposed && generation == _generation && token == repository.api.token;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
