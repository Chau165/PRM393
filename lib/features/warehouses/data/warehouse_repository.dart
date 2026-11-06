import '../../../core/network/api_client.dart';

class ServerWarehouse {
  const ServerWarehouse({
    required this.id,
    required this.code,
    required this.name,
    required this.version,
    this.etag,
  });
  final int id;
  final String code;
  final String name;
  final String version;
  final String? etag;
  factory ServerWarehouse.fromJson(Map<String, dynamic> json, {String? etag}) =>
      ServerWarehouse(
        id: json['id'] as int,
        code: json['code'] as String,
        name: json['name'] as String,
        version: json['version'] as String,
        etag: etag,
      );
}

class WarehousePageResult {
  const WarehousePageResult(
    this.items,
    this.page,
    this.pageSize,
    this.totalItems,
    this.totalPages,
  );
  final List<ServerWarehouse> items;
  final int page, pageSize, totalItems, totalPages;
}

class WarehouseRepository {
  WarehouseRepository(this.api);
  final ApiClient api;
  Future<WarehousePageResult> list({
    int page = 1,
    int pageSize = 20,
    String search = '',
    String sort = 'code',
  }) async {
    final data = await api.request(
      'GET',
      'warehouses',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        'sort': sort,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return WarehousePageResult(
      (data['items'] as List)
          .map((x) => ServerWarehouse.fromJson(x as Map<String, dynamic>))
          .toList(),
      data['page'] as int,
      data['pageSize'] as int,
      data['totalItems'] as int,
      data['totalPages'] as int,
    );
  }

  Future<ServerWarehouse> get(int id) async =>
      _detail(await api.requestWithResponse('GET', 'warehouses/$id'));
  Future<ServerWarehouse> create(String code, String name) async => _detail(
    await api.requestWithResponse(
      'POST',
      'warehouses',
      body: {'code': code.trim(), 'name': name.trim()},
    ),
  );
  Future<ServerWarehouse> update(
    ServerWarehouse current,
    String code,
    String name,
  ) async => _detail(
    await api.requestWithResponse(
      'PUT',
      'warehouses/${current.id}',
      ifMatch: _version(current),
      body: {'code': code.trim(), 'name': name.trim()},
    ),
  );
  Future<void> delete(ServerWarehouse current) async {
    await api.request(
      'DELETE',
      'warehouses/${current.id}',
      ifMatch: _version(current),
    );
  }

  ServerWarehouse _detail(ApiResponse response) {
    if (response.etag == null || response.etag!.isEmpty) {
      throw const ApiException(
        'Không thể xác định phiên bản kho. Vui lòng tải lại dữ liệu.',
      );
    }
    return ServerWarehouse.fromJson(response.data, etag: response.etag);
  }

  String _version(ServerWarehouse current) {
    if (current.etag == null) {
      throw const ApiException('Cần tải chi tiết kho trước khi thay đổi.');
    }
    return current.etag!;
  }
}
