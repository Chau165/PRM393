import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warehouse/core/network/api_client.dart';
import 'package:warehouse/features/catalog/catalog_dialogs.dart';
import 'package:warehouse/features/catalog/data/catalog_repository.dart';
import 'package:warehouse/features/catalog/state/catalog_controller.dart';

Map<String, dynamic> organization(int id, String name) => {
  'id': id,
  'code': 'M$id',
  'name': name,
  'country': 'VN',
  'kind': 'Manufacturer',
  'version': 'AAAAAAAAAAE=',
};
http.Response json(Object value, {String? etag}) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json', 'etag': ?etag},
);
Object page(List<Object> rows) => {
  'items': rows,
  'page': 1,
  'pageSize': 20,
  'totalItems': rows.length,
  'totalPages': rows.isEmpty ? 0 : 1,
};

void main() {
  test('catalog repository sends kind/country filters and uses ETag only in headers', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((r) async {
        if (r.method == 'GET' && r.url.path.endsWith('organizations')) {
          expect(r.url.queryParameters['kind'], 'Manufacturer');
          expect(r.url.queryParameters['country'], 'VN');
          expect(r.url.queryParameters['search'], 'A & B');
          return json(page([organization(1, 'A & B')]));
        }
        if (r.method == 'GET') {
          return json(organization(1, 'A'), etag: '"AAAAAAAAAAE="');
        }
        expect(r.headers['If-Match'], '"AAAAAAAAAAE="');
        expect((jsonDecode(r.body) as Map).keys.toSet(), {
          'code',
          'name',
          'country',
          'kind',
        });
        return json(organization(1, 'Updated'), etag: '"AAAAAAAAAAI="');
      }),
    );
    addTearDown(api.close);
    final repo = CatalogRepository(api, CatalogResource.organizations);
    await repo.list(
      search: 'A & B',
      filters: {'kind': 'Manufacturer', 'country': 'VN'},
    );
    final detail = await repo.get(1);
    await repo.update(detail, {
      'code': 'M1',
      'name': 'Updated',
      'country': 'VN',
      'kind': 'Manufacturer',
    });
  });
  test(
    'catalog controller ignores old search responses and preserves filters',
    () async {
      final old = Completer<http.Response>(),
          latest = Completer<http.Response>();
      final api = ApiClient(
        baseUrl: 'https://example.test/',
        client: MockClient((r) {
          expect(r.url.queryParameters['kind'], 'Manufacturer');
          return r.url.queryParameters['search'] == 'old'
              ? old.future
              : latest.future;
        }),
      );
      final c = CatalogController(
        CatalogRepository(api, CatalogResource.organizations),
      );
      addTearDown(() {
        c.dispose();
        api.close();
      });
      final a = c.load(search: 'old', filters: {'kind': 'Manufacturer'});
      final b = c.load(search: 'latest');
      latest.complete(json(page([organization(2, 'Latest')])));
      await b;
      old.complete(json(page([organization(1, 'Old')])));
      await a;
      expect(c.items.single.name, 'Latest');
      expect(c.filters, {'kind': 'Manufacturer'});
    },
  );
  test('temperature parser accepts comma/negative values and rejects rounding or invalid precision', () {
    expect(parseStorageTemperature('-20,25'), -20.25);
    expect(parseStorageTemperature('0'), 0);
    expect(parseStorageTemperature('2.55'), 2.55);
    expect(parseStorageTemperature('2.555'), isNull);
    expect(parseStorageTemperature('NaN'), isNull);
    expect(parseStorageTemperature('1e2'), isNull);
    expect(parseStorageTemperature('9999999999999999.99'), isNull);
  });
}
