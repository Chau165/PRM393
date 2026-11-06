import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'batch_dialog.dart';
import 'batch_repository.dart';

class BatchController extends ChangeNotifier {
  BatchController(this.repository);
  final BatchRepository repository;
  BatchPage? data;
  int page = 1, pageSize = 20;
  String search = '', sort = 'expiresAt', vaccineLabel = 'Tất cả vaccine';
  Map<String, String> filters = {};
  bool loading = false, _disposed = false;
  String? error;
  int _generation = 0;
  Future<void> load({
    int? page,
    int? pageSize,
    String? search,
    String? sort,
    Map<String, String>? filters,
  }) async {
    if (_disposed) return;
    final generation = ++_generation, token = repository.api.token;
    this.page = page ?? this.page;
    this.pageSize = pageSize ?? this.pageSize;
    this.search = search ?? this.search;
    this.sort = sort ?? this.sort;
    this.filters = Map.of(filters ?? this.filters);
    loading = true;
    error = null;
    data = null;
    notifyListeners();
    bool active() =>
        !_disposed &&
        generation == _generation &&
        token == repository.api.token;
    try {
      final result = await repository.list(
        page: this.page,
        pageSize: this.pageSize,
        search: this.search,
        sort: this.sort,
        filters: this.filters,
      );
      if (!active()) return;
      if (result.totalPages > 0 && this.page > result.totalPages) {
        await load(page: result.totalPages);
        return;
      }
      data = result;
      this.page = result.totalPages == 0 ? 1 : result.page;
    } on ApiException catch (e) {
      if (active()) error = batchError(e);
    } catch (_) {
      if (active()) error = 'Không đọc được danh sách lô.';
    } finally {
      if (active()) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
