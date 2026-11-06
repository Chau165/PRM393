import '../../core/network/api_client.dart';

const expiryLabels = {
  'Expired': 'Hết hạn',
  'NearExpiry': 'Sắp hết hạn',
  'Valid': 'Còn hạn',
};

// DateOnly values remain strings: converting to local/UTC time can change a day.
String? validBatchDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null || parsed.year < 1 || parsed.year > 9999) return null;
  return parsed.toIso8601String().substring(0, 10) == value ? value : null;
}

class ServerBatch {
  const ServerBatch({
    required this.id,
    required this.vaccineId,
    required this.vaccineCode,
    required this.vaccineName,
    required this.batchNo,
    required this.manufacturedAt,
    required this.expiresAt,
    required this.expiryStatus,
    required this.daysToExpiry,
    required this.version,
    this.etag,
  });
  final int id, vaccineId, daysToExpiry;
  final String vaccineCode,
      vaccineName,
      batchNo,
      expiresAt,
      expiryStatus,
      version;
  final String? manufacturedAt, etag;
  factory ServerBatch.fromJson(Map<String, dynamic> j, {String? etag}) =>
      ServerBatch(
        id: j['id'] as int,
        vaccineId: j['vaccineId'] as int,
        vaccineCode: j['vaccineCode'] as String,
        vaccineName: j['vaccineName'] as String,
        batchNo: j['batchNo'] as String,
        manufacturedAt: j['manufacturedAt'] as String?,
        expiresAt: j['expiresAt'] as String,
        expiryStatus: j['expiryStatus'] as String,
        daysToExpiry: j['daysToExpiry'] as int,
        version: j['version'] as String,
        etag: etag,
      );
}

class BatchPage {
  BatchPage.fromJson(Map<String, dynamic> j)
    : items = (j['items'] as List)
          .map((x) => ServerBatch.fromJson(x as Map<String, dynamic>))
          .toList(),
      page = j['page'] as int,
      totalPages = j['totalPages'] as int,
      totalItems = j['totalItems'] as int;
  final List<ServerBatch> items;
  final int page, totalPages, totalItems;
}

class BatchWarehouse {
  BatchWarehouse.fromJson(Map<String, dynamic> j)
    : id = j['warehouseId'] as int,
      name = j['warehouseName'] as String,
      onHand = j['onHand'] as int,
      reserved = j['reserved'] as int,
      available = j['available'] as int;
  final int id, onHand, reserved, available;
  final String name;
}

class BatchMovement {
  BatchMovement.fromJson(Map<String, dynamic> j)
    : id = j['id'] as int,
      stockSegmentId = j['stockSegmentId'] as int,
      warehouseId = j['warehouseId'] as int,
      quantityDelta = j['quantityDelta'] as int,
      sourceType = j['sourceType'] as String,
      sourceId = j['sourceId'] as int,
      sourceDetailId = j['sourceDetailId'] as int,
      documentNo = j['documentNo'] as String,
      effectiveDate = j['effectiveDate'] as String,
      postedAt = j['postedAt'] as String;
  final int id,
      stockSegmentId,
      warehouseId,
      quantityDelta,
      sourceId,
      sourceDetailId;
  final String sourceType, documentNo, effectiveDate, postedAt;
}

class BatchTrace {
  BatchTrace.fromJson(Map<String, dynamic> j)
    : batch = ServerBatch.fromJson(j['batch'] as Map<String, dynamic>),
      warehouses = (j['warehouses'] as List)
          .map((x) => BatchWarehouse.fromJson(x as Map<String, dynamic>))
          .toList(),
      movements = ((j['movements'] as Map)['items'] as List)
          .map((x) => BatchMovement.fromJson(x as Map<String, dynamic>))
          .toList(),
      page = (j['movements'] as Map)['page'] as int,
      totalPages = (j['movements'] as Map)['totalPages'] as int,
      totalItems = (j['movements'] as Map)['totalItems'] as int;
  final ServerBatch batch;
  final List<BatchWarehouse> warehouses;
  final List<BatchMovement> movements;
  final int page, totalPages, totalItems;
}

class BatchRepository {
  BatchRepository(this.api);
  final ApiClient api;
  Future<BatchPage> list({
    int page = 1,
    int pageSize = 20,
    String search = '',
    String sort = 'expiresAt',
    Map<String, String> filters = const {},
  }) async => BatchPage.fromJson(
    await api.request(
      'GET',
      'batches',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        'sort': sort,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        ...filters,
      },
    ),
  );
  ServerBatch _detail(ApiResponse r) {
    if (r.etag == null) {
      throw const ApiException('Không đọc được phiên bản lô. Hãy tải lại.');
    }
    return ServerBatch.fromJson(r.data, etag: r.etag);
  }

  String _etag(ServerBatch b) {
    if (b.etag == null) {
      throw const ApiException('Cần tải chi tiết lô trước khi thay đổi.');
    }
    return b.etag!;
  }

  Future<ServerBatch> get(int id) async =>
      _detail(await api.requestWithResponse('GET', 'batches/$id'));
  Future<ServerBatch> create({
    required int vaccineId,
    required String batchNo,
    String? manufacturedAt,
    required String expiresAt,
  }) async => _detail(
    await api.requestWithResponse(
      'POST',
      'batches',
      body: {
        'vaccineId': vaccineId,
        'batchNo': batchNo.trim(),
        'manufacturedAt': manufacturedAt,
        'expiresAt': expiresAt,
      },
    ),
  );
  Future<ServerBatch> update(
    ServerBatch b, {
    String? manufacturedAt,
    required String expiresAt,
  }) async => _detail(
    await api.requestWithResponse(
      'PUT',
      'batches/${b.id}',
      ifMatch: _etag(b),
      body: {'manufacturedAt': manufacturedAt, 'expiresAt': expiresAt},
    ),
  );
  Future<void> delete(ServerBatch b) async {
    await api.request('DELETE', 'batches/${b.id}', ifMatch: _etag(b));
  }

  Future<BatchTrace> trace(
    int id, {
    int? warehouseId,
    int page = 1,
    int pageSize = 20,
  }) async => BatchTrace.fromJson(
    await api.request(
      'GET',
      'batches/$id/trace',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (warehouseId != null) 'warehouseId': '$warehouseId',
      },
    ),
  );
}
