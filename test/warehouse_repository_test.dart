import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warehouse/core/network/api_client.dart';
import 'package:warehouse/features/warehouses/data/warehouse_repository.dart';
import 'package:warehouse/features/warehouses/state/warehouse_controller.dart';

const version = 'AAAAAAAAAAE=';
Map<String, Object> row(int id, String name) => {
  'id': id,
  'code': 'K$id',
  'name': name,
  'version': version,
};
http.Response json(Object data, {String? etag, int status = 200}) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'etag': ?etag,
      },
    );
Map<String, Object> page(
  List<Object> rows, {
  int current = 1,
  int totalPages = 1,
  int totalItems = 1,
}) => {
  'items': rows,
  'page': current,
  'pageSize': 20,
  'totalItems': totalItems,
  'totalPages': totalPages,
};

void main() {
  test('repository preserves ETag, encodes filters, sends only allowed fields and handles 204', () async {
    final methods = <String>[];
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((r) async {
        methods.add(r.method);
        expect(r.headers['Authorization'], 'Bearer session');
        if (r.method == 'GET' && r.url.path.endsWith('/warehouses')) {
          expect(r.url.queryParameters['search'], 'Kho & HCM');
          expect(r.url.queryParameters['page'], '2');
          return json(page([row(1, 'Kho')], current: 2));
        }
        if (r.method == 'GET') return json(row(1, 'Kho'), etag: '"$version"');
        expect(r.headers['If-Match'], '"$version"');
        if (r.method == 'PUT') {
          expect(jsonDecode(r.body), {'code': 'NEW', 'name': 'Tên mới'});
          return json(row(1, 'Tên mới'), etag: '"$version"');
        }
        return http.Response('', 204);
      }),
    );
    api.token = 'session';
    addTearDown(api.close);
    final repository = WarehouseRepository(api);
    await repository.list(page: 2, search: 'Kho & HCM');
    final detail = await repository.get(1);
    await repository.update(detail, ' NEW ', ' Tên mới ');
    await repository.delete(detail);
    expect(methods, ['GET', 'GET', 'PUT', 'DELETE']);
  });

  test('controller ignores a slow previous search response', () async {
    final old = Completer<http.Response>(), latest = Completer<http.Response>();
    final api = ApiClient(
      baseUrl: 'https://example.test/',
      client: MockClient(
        (r) => r.url.queryParameters['search'] == 'old'
            ? old.future
            : latest.future,
      ),
    );
    final controller = WarehouseController(WarehouseRepository(api));
    addTearDown(() {
      controller.dispose();
      api.close();
    });
    final first = controller.load(search: 'old');
    final second = controller.load(search: 'latest');
    latest.complete(json(page([row(2, 'Latest')])));
    await second;
    old.complete(json(page([row(1, 'Old')])));
    await first;
    expect(controller.items.single.name, 'Latest');
    expect(controller.search, 'latest');
    expect(controller.loading, isFalse);
  });

  test(
    'controller falls back to last page after deleting the only last-page row',
    () async {
      final visited = <String>[];
      final api = ApiClient(
        baseUrl: 'https://example.test/',
        client: MockClient((r) async {
          final p = r.url.queryParameters['page']!;
          visited.add(p);
          return json(
            page(p == '2' ? [] : [row(1, 'Remaining')], current: int.parse(p)),
          );
        }),
      );
      final controller = WarehouseController(WarehouseRepository(api));
      addTearDown(() {
        controller.dispose();
        api.close();
      });
      await controller.load(page: 2);
      expect(visited, ['2', '1']);
      expect(controller.page, 1);
      expect(controller.items.single.name, 'Remaining');
    },
  );
}
