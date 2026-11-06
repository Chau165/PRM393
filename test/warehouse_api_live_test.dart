import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:warehouse/core/network/api_client.dart';
import 'package:warehouse/features/auth/data/auth_repository.dart';
import 'package:warehouse/features/warehouses/data/warehouse_repository.dart';

void main() {
  final base = Platform.environment['WAREHOUSE_LIVE_API_URL'];
  test(
    'Flutter repositories perform warehouse CRUD against real ASP.NET/SQL',
    () async {
      final password = Platform.environment['Seed__Password']!;
      final api = ApiClient(baseUrl: base!);
      final staffApi = ApiClient(baseUrl: base);
      final repository = WarehouseRepository(api);
      ServerWarehouse? created;
      try {
        final admin = await AuthRepository(api).login('admin', password);
        api.token = admin.token;
        final staff = await AuthRepository(staffApi)
            .login('staff.hcm', password);
        staffApi.token = staff.token;
        final staffRepository = WarehouseRepository(staffApi);
        final code = 'FE-${DateTime.now().microsecondsSinceEpoch}';
        created = await repository.create(code, 'Kho kiểm thử FE');
        expect(created.etag, '"${created.version}"');
        final found = await repository.list(search: code);
        expect(found.totalItems, 1);
        final detail = await repository.get(created.id);
        // A browser must be able to read ETag and preflight If-Match writes.
        final cors = await http.get(
          Uri.parse('${base}warehouses/${created.id}'),
          headers: {
            'Origin': 'http://localhost:5173',
            'Authorization': 'Bearer ${admin.token}',
          },
        );
        expect(
          cors.headers['access-control-allow-origin'],
          'http://localhost:5173',
        );
        expect(
          cors.headers['access-control-expose-headers']?.toLowerCase(),
          contains('etag'),
        );
        final preflight =
            http.Request(
                'OPTIONS',
                Uri.parse('${base}warehouses/${created.id}'),
              )
              ..headers.addAll({
                'Origin': 'http://localhost:5173',
                'Access-Control-Request-Method': 'PUT',
                'Access-Control-Request-Headers':
                    'authorization,content-type,if-match',
              });
        final preflightClient = http.Client();
        try {
          final response = await http.Response.fromStream(
            await preflightClient.send(preflight),
          );
          expect(response.statusCode, 204);
          expect(
            response.headers['access-control-allow-headers']?.toLowerCase(),
            contains('if-match'),
          );
        } finally {
          preflightClient.close();
        }
        final updated = await repository.update(
          detail,
          code,
          'Kho đã cập nhật',
        );
        expect(updated.name, 'Kho đã cập nhật');
        expect(updated.etag, isNot(detail.etag));
        created = updated;
        await expectLater(
          repository.update(detail, code, 'Stale'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 412),
          ),
        );
        await expectLater(
          staffRepository.create('FORBIDDEN-FE', 'Forbidden'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 403),
          ),
        );
        await expectLater(
          staffRepository.get(created.id),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 404),
          ),
        );
        final assigned = await repository.get(staff.user.warehouses.single.id);
        await expectLater(
          repository.delete(assigned),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'RESOURCE_IN_USE',
            ),
          ),
        );
        final id = created.id;
        await repository.delete(created);
        created = null;
        await expectLater(
          repository.get(id),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 404),
          ),
        );
      } finally {
        if (created != null) {
          try {
            await repository.delete(await repository.get(created.id));
          } catch (_) {
            /* Test DB is disposed by harness. */
          }
        }
        api.close();
        staffApi.close();
      }
    },
    skip: base == null
        ? 'Run backend/scripts/test-auth.ps1 -Suite warehouse-fe.'
        : false,
  );
}
