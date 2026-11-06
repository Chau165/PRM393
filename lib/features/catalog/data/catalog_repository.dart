import '../../../core/network/api_client.dart';

enum CatalogResource { organizations, vaccines }

const organizationKinds = <String, String>{
  'Manufacturer': 'Nhà sản xuất',
  'Supplier': 'Nhà cung cấp',
  'Recipient': 'Đơn vị nhận',
  'Carrier': 'Đơn vị vận chuyển',
};

class CatalogItem {
  const CatalogItem({
    required this.resource,
    required this.id,
    required this.code,
    required this.name,
    required this.version,
    this.etag,
    this.country,
    this.kind,
    this.manufacturerId,
    this.manufacturerName,
    this.dosesPerVial,
    this.vialsPerPack,
    this.storageMin,
    this.storageMax,
    this.storageReviewRequired = false,
  });
  final CatalogResource resource;
  final int id;
  final String code, name, version;
  final String? etag, country, kind, manufacturerName;
  final int? manufacturerId, dosesPerVial, vialsPerPack;
  final double? storageMin, storageMax;
  final bool storageReviewRequired;
  factory CatalogItem.fromJson(
    CatalogResource resource,
    Map<String, dynamic> json, {
    String? etag,
  }) => CatalogItem(
    resource: resource,
    id: json['id'] as int,
    code: json['code'] as String,
    name: json['name'] as String,
    version: json['version'] as String,
    etag: etag,
    country: resource == CatalogResource.organizations
        ? json['country'] as String
        : null,
    kind: resource == CatalogResource.organizations
        ? json['kind'] as String
        : null,
    manufacturerId: resource == CatalogResource.vaccines
        ? json['manufacturerId'] as int
        : null,
    manufacturerName: resource == CatalogResource.vaccines
        ? json['manufacturerName'] as String
        : null,
    dosesPerVial: resource == CatalogResource.vaccines
        ? json['dosesPerVial'] as int
        : null,
    vialsPerPack: resource == CatalogResource.vaccines
        ? json['vialsPerPack'] as int
        : null,
    storageMin: resource == CatalogResource.vaccines
        ? (json['storageMin'] as num).toDouble()
        : null,
    storageMax: resource == CatalogResource.vaccines
        ? (json['storageMax'] as num).toDouble()
        : null,
    storageReviewRequired: json['storageReviewRequired'] as bool? ?? false,
  );
}

class CatalogPageResult {
  const CatalogPageResult(
    this.items,
    this.page,
    this.pageSize,
    this.totalItems,
    this.totalPages,
  );
  final List<CatalogItem> items;
  final int page, pageSize, totalItems, totalPages;
}

class CatalogRepository {
  CatalogRepository(this.api, this.resource);
  final ApiClient api;
  final CatalogResource resource;
  String get path => resource.name;
  Future<CatalogPageResult> list({
    int page = 1,
    int pageSize = 20,
    String search = '',
    String sort = 'code',
    Map<String, String> filters = const {},
  }) async {
    final data = await api.request(
      'GET',
      path,
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        'sort': sort,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        ...filters,
      },
    );
    return CatalogPageResult(
      (data['items'] as List)
          .map((x) => CatalogItem.fromJson(resource, x as Map<String, dynamic>))
          .toList(),
      data['page'] as int,
      data['pageSize'] as int,
      data['totalItems'] as int,
      data['totalPages'] as int,
    );
  }

  Future<CatalogItem> get(int id) async =>
      _detail(await api.requestWithResponse('GET', '$path/$id'));
  Future<CatalogItem> create(Map<String, Object?> body) async =>
      _detail(await api.requestWithResponse('POST', path, body: body));
  Future<CatalogItem> update(
    CatalogItem current,
    Map<String, Object?> body,
  ) async => _detail(
    await api.requestWithResponse(
      'PUT',
      '$path/${current.id}',
      ifMatch: _etag(current),
      body: body,
    ),
  );
  Future<void> delete(CatalogItem current) async {
    await api.request('DELETE', '$path/${current.id}', ifMatch: _etag(current));
  }

  String _etag(CatalogItem item) {
    if (item.resource != resource || item.etag == null) {
      throw const ApiException('Cần tải lại chi tiết trước khi thay đổi.');
    }
    return item.etag!;
  }

  CatalogItem _detail(ApiResponse response) {
    if (response.etag == null) {
      throw const ApiException(
        'Không thể xác định phiên bản dữ liệu. Vui lòng tải lại.',
      );
    }
    return CatalogItem.fromJson(resource, response.data, etag: response.etag);
  }
}
