import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/core/network/api_client.dart';
import 'package:warehouse/features/auth/data/auth_repository.dart';
import 'package:warehouse/features/batches/batch_repository.dart';
import 'package:warehouse/features/catalog/data/catalog_repository.dart';

void main() {
  final base = Platform.environment['WAREHOUSE_LIVE_API_URL'];
  test(
    'Batch Flutter CRUD, ETag and scoped trace against real ASP.NET/SQL',
    () async {
      final api = ApiClient(baseUrl: base!),
          staffApi = ApiClient(baseUrl: base);
      try {
        final password = Platform.environment['Seed__Password']!;
        api.token = (await AuthRepository(api).login('admin', password)).token;
        final staff = await AuthRepository(staffApi)
            .login('staff.hcm', password);
        staffApi.token = staff.token;
        final admin = BatchRepository(api), worker = BatchRepository(staffApi);
        final vaccine = (await CatalogRepository(
          api,
          CatalogResource.vaccines,
        ).list(search: 'TRACE-VAC')).items.single;
        final b = await worker.create(
          vaccineId: vaccine.id,
          batchNo: 'FLUTTER-LIVE',
          expiresAt: '2030-01-01',
        );
        expect(b.manufacturedAt, isNull);
        expect(b.etag, '"${b.version}"');
        await expectLater(
          admin.create(
            vaccineId: vaccine.id,
            batchNo: b.batchNo,
            expiresAt: '2030-01-02',
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.existingBatchId, 'existing ID', b.id)
                .having((e) => e.code, 'code', 'BATCH_METADATA_CONFLICT'),
          ),
        );
        final empty = await worker.trace(b.id);
        expect(empty.warehouses, isEmpty);
        expect(empty.movements, isEmpty);
        final updated = await admin.update(
          await admin.get(b.id),
          manufacturedAt: null,
          expiresAt: '2030-01-02',
        );
        expect(updated.etag, isNot(b.etag));
        await expectLater(
          admin.delete(b),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 412),
          ),
        );
        await expectLater(
          worker.update(updated, expiresAt: '2030-01-03'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 403),
          ),
        );
        final used = (await admin.list(search: 'TRACE-LOT')).items.single;
        final detail = await admin.get(used.id);
        await expectLater(
          admin.delete(detail),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'RESOURCE_IN_USE',
            ),
          ),
        );
        final trace = await worker.trace(used.id, pageSize: 1);
        expect(trace.warehouses.single.id, staff.user.warehouses.single.id);
        expect(trace.warehouses.single.onHand, 160);
        expect(trace.warehouses.single.reserved, 20);
        expect(trace.warehouses.single.available, 55);
        expect(trace.movements.length, 1);
        expect(trace.totalPages, greaterThan(1));
        final second = await worker.trace(used.id, pageSize: 1, page: 2);
        expect(second.warehouses.single.available, 55);
        expect(second.movements.single.id, isNot(trace.movements.single.id));
        final all = await admin.trace(used.id);
        final other = all.warehouses.firstWhere(
          (w) => w.id != staff.user.warehouses.single.id,
        );
        await expectLater(
          worker.trace(used.id, warehouseId: other.id),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 403),
          ),
        );
        final scoped = await admin.trace(used.id, warehouseId: other.id);
        expect(scoped.warehouses.single.id, other.id);
        expect(
          scoped.movements.every((m) => m.warehouseId == other.id),
          isTrue,
        );
        final filtered = await admin.list(
          filters: {
            'vaccineId': '${vaccine.id}',
            'expiresBefore': '2030-01-02',
          },
          search: b.batchNo,
        );
        expect(filtered.items, isEmpty);
        await admin.delete(await admin.get(updated.id));
      } finally {
        api.close();
        staffApi.close();
      }
    },
    skip: base == null
        ? 'Run backend/scripts/test-auth.ps1 -Suite batch-fe.'
        : false,
  );
}
