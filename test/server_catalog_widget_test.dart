import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warehouse/app/auth_app.dart';
import 'package:warehouse/core/network/api_client.dart';
import 'package:warehouse/core/storage/token_store.dart';
import 'package:warehouse/features/auth/data/auth_repository.dart';
import 'package:warehouse/features/auth/state/auth_controller.dart';

const v1 = 'AAAAAAAAAAE=', v2 = 'AAAAAAAAAAI=';

class FakeCatalogApi {
  FakeCatalogApi({this.role = 'Admin', bool manyManufacturers = false}) {
    if (manyManufacturers) {
      orgs[1]!['name'] = 'Nhà sản xuất 01';
      for (var i = 3; i <= 22; i++) {
        orgs[i] = {
          'id': i,
          'code': 'M${i.toString().padLeft(2, '0')}',
          'name': 'Nhà sản xuất ${i.toString().padLeft(2, '0')}',
          'country': 'VN',
          'kind': 'Manufacturer',
          'version': v1,
        };
      }
    }
  }
  final String role;
  final orgs = <int, Map<String, dynamic>>{
    1: {
      'id': 1,
      'code': 'M01',
      'name': 'Nhà sản xuất gốc',
      'country': 'VN',
      'kind': 'Manufacturer',
      'version': v1,
    },
    2: {
      'id': 2,
      'code': 'SUP',
      'name': 'Supplier riêng',
      'country': 'VN',
      'kind': 'Supplier',
      'version': v1,
    },
  };
  final vaccines = <int, Map<String, dynamic>>{
    1: {
      'id': 1,
      'code': 'VAC01',
      'name': 'Vaccine gốc',
      'manufacturerId': 1,
      'manufacturerName': 'Nhà sản xuất gốc',
      'dosesPerVial': 1,
      'vialsPerPack': 10,
      'storageMin': 2,
      'storageMax': 8,
      'version': v1,
      'storageReviewRequired': false,
    },
  };
  final requests = <http.Request>[];
  String? conflictOn;
  bool blockDelete = false, revokeLookup = false;
  int putCount = 0;
  http.Response json(Object value, [int status = 200, String? etag]) =>
      http.Response(
        jsonEncode(value),
        status,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'etag': ?etag,
        },
      );
  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    final user = {
      'id': 7,
      'username': 'user',
      'fullName': 'Người dùng',
      'role': role,
      'warehouses': <Object>[],
    };
    if (r.url.path.endsWith('auth/login')) {
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'exp':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      );
      return json({
        'accessToken': 'h.$payload.s',
        'expiresIn': 900,
        'user': user,
      });
    }
    if (r.url.path.endsWith('auth/me')) return json(user);
    final path = r.url.pathSegments;
    final resource = path[2];
    final rows = resource == 'organizations' ? orgs : vaccines;
    if (path.length == 3) {
      if (r.method == 'GET') {
        if (revokeLookup && r.url.queryParameters['kind'] == 'Manufacturer') {
          return json({'title': 'Revoked'}, 401);
        }
        var values = rows.values.toList();
        final query = r.url.queryParameters;
        if (query['search'] case final String search) {
          values = values
              .where(
                (x) => '${x['code']} ${x['name']}'.toLowerCase().contains(
                  search.toLowerCase(),
                ),
              )
              .toList();
        }
        if (query['kind'] case final String kind) {
          values = values.where((x) => x['kind'] == kind).toList();
        }
        if (query['country'] case final String country) {
          values = values.where((x) => x['country'] == country).toList();
        }
        if (query['manufacturerId'] case final String id) {
          values = values.where((x) => '${x['manufacturerId']}' == id).toList();
        }
        final sort = query['sort'] ?? 'code';
        values.sort((a, b) => (a[sort] as String).compareTo(b[sort] as String));
        final page = int.parse(query['page'] ?? '1'),
            size = int.parse(query['pageSize'] ?? '20');
        return json({
          'items': values.skip((page - 1) * size).take(size).toList(),
          'page': page,
          'pageSize': size,
          'totalItems': values.length,
          'totalPages': (values.length / size).ceil(),
        });
      }
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      rows[100] = {
        'id': 100,
        ...body,
        'version': v1,
        if (resource == 'vaccines') ...{
          'manufacturerName': orgs[body['manufacturerId']]!['name'],
          'storageReviewRequired': false,
        },
      };
      return json(rows[100]!, 201, '"$v1"');
    }
    final id = int.parse(path.last);
    if (r.method == 'GET') {
      return json(rows[id]!, 200, '"${rows[id]!['version']}"');
    }
    if (r.method == 'DELETE') {
      if (blockDelete) {
        return json({'title': 'Used', 'code': 'RESOURCE_IN_USE'}, 409);
      }
      rows.remove(id);
      return http.Response('', 204);
    }
    putCount++;
    if (conflictOn == resource) {
      conflictOn = null;
      rows[id] = {...rows[id]!, 'name': 'Tên từ người khác', 'version': v2};
      return json({'title': 'Changed'}, 412);
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final review =
        resource == 'vaccines' &&
        (rows[id]!['storageMin'] != body['storageMin'] ||
            rows[id]!['storageMax'] != body['storageMax']);
    rows[id] = {
      ...rows[id]!,
      ...body,
      'version': v2,
      if (resource == 'vaccines') ...{
        'manufacturerName': orgs[body['manufacturerId']]!['name'],
        'storageReviewRequired': review,
      },
    };
    return json(rows[id]!, 200, '"$v2"');
  }
}

Future<AuthController> open(
  WidgetTester t,
  FakeCatalogApi fake,
  String resource, {
  bool mobile = false,
}) async {
  t.view.physicalSize = Size(mobile ? 390 : 1400, 1000);
  t.view.devicePixelRatio = 1;
  final auth = AuthController(
    tokens: MemoryTokenStore(),
    repository: AuthRepository(
      ApiClient(
        baseUrl: 'https://example.test/api/v1/',
        client: MockClient(fake.handle),
      ),
    ),
  );
  await auth.restore();
  await auth.login('user', 'password');
  await t.pumpWidget(VaxStockAuthApp(auth: auth));
  await t.pumpAndSettle();
  if (mobile) {
    await t.tap(find.byIcon(Icons.menu));
    await t.pumpAndSettle();
  }
  await t.tap(find.byKey(ValueKey('server.nav.$resource')));
  await t.pumpAndSettle();
  return auth;
}

Future<void> cleanup(WidgetTester t, AuthController auth) async {
  await t.pumpWidget(const SizedBox.shrink());
  auth.dispose();
  t.view.resetPhysicalSize();
  t.view.resetDevicePixelRatio();
}

Future<void> enter(WidgetTester t, String key, String value) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await t.enterText(f, value);
  await t.pump();
}

void main() {
  testWidgets(
    'Admin creates edits and deletes an organization with exact DTO fields',
    (t) async {
      final fake = FakeCatalogApi();
      final auth = await open(t, fake, 'organizations');
      try {
        await t.tap(find.byKey(const ValueKey('organizations.add')));
        await t.pumpAndSettle();
        await enter(t, 'organizations.editor.code', 'A-NEW');
        await enter(t, 'organizations.editor.name', 'Đối tác mới');
        await enter(t, 'organizations.editor.country', 'vn');
        await t.ensureVisible(
          find.byKey(const ValueKey('organizations.editor.kind.new')),
        );
        await t.tap(
          find.byKey(const ValueKey('organizations.editor.kind.new')),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Nhà cung cấp').last);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('organizations.editor.save')));
        await t.pumpAndSettle();
        expect(fake.orgs[100]!['country'], 'VN');
        expect(find.text('Đối tác mới'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('organizations.edit.100')));
        await t.pumpAndSettle();
        await enter(t, 'organizations.editor.name', 'Đối tác cập nhật');
        await t.tap(find.byKey(const ValueKey('organizations.editor.save')));
        await t.pumpAndSettle();
        final put = fake.requests.lastWhere((r) => r.method == 'PUT');
        expect(put.headers['If-Match'], '"$v1"');
        expect((jsonDecode(put.body) as Map).keys.toSet(), {
          'code',
          'name',
          'country',
          'kind',
        });
        await t.tap(find.byKey(const ValueKey('organizations.delete.100')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('organizations.delete.confirm')));
        await t.pumpAndSettle();
        expect(find.text('Đối tác cập nhật'), findsNothing);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, auth);
      }
    },
  );
  testWidgets(
    'manufacturer picker pages beyond the first page and sends manufacturer ID',
    (t) async {
      final fake = FakeCatalogApi(manyManufacturers: true);
      final auth = await open(t, fake, 'vaccines');
      try {
        await t.tap(find.byKey(const ValueKey('vaccines.add')));
        await t.pumpAndSettle();
        await enter(t, 'vaccines.editor.code', 'NEW-VAC');
        await enter(t, 'vaccines.editor.name', 'Vaccine mới');
        await t.ensureVisible(
          find.byKey(const ValueKey('vaccines.editor.manufacturer')),
        );
        await t.tap(find.byKey(const ValueKey('vaccines.editor.manufacturer')));
        await t.pumpAndSettle();
        expect(find.text('Supplier riêng'), findsNothing);
        await t.tap(find.byKey(const ValueKey('manufacturer.next')));
        await t.pumpAndSettle();
        final tile = find.byKey(
          const ValueKey('manufacturer.select.22'),
        ); // Select from the second server page.
        expect(tile, findsOneWidget);
        await t.tap(tile);
        await t.pumpAndSettle();
        await enter(t, 'vaccines.editor.doses', '1');
        await enter(t, 'vaccines.editor.pack', '10');
        await enter(t, 'vaccines.editor.min', '-20,25');
        await enter(t, 'vaccines.editor.max', '8');
        await t.tap(find.byKey(const ValueKey('vaccines.editor.save')));
        await t.pumpAndSettle();
        expect(fake.vaccines[100]!['manufacturerId'], 22);
        expect(fake.vaccines[100]!['storageMin'], -20.25);
        expect(
          fake.requests.any(
            (r) =>
                r.url.queryParameters['kind'] == 'Manufacturer' &&
                r.url.queryParameters['page'] == '2',
          ),
          isTrue,
        );
        expect(find.text('Vaccine mới'), findsOneWidget);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, auth);
      }
    },
  );
  testWidgets(
    'temperature validation blocks invalid range and successful change shows review notice',
    (t) async {
      final fake = FakeCatalogApi();
      final auth = await open(t, fake, 'vaccines');
      try {
        await t.ensureVisible(find.byKey(const ValueKey('vaccines.edit.1')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('vaccines.edit.1')));
        await t.pumpAndSettle();
        await enter(t, 'vaccines.editor.min', '9');
        await t.tap(find.byKey(const ValueKey('vaccines.editor.save')));
        await t.pumpAndSettle();
        expect(fake.putCount, 0);
        expect(
          find.text('Nhiệt độ tối đa phải lớn hơn tối thiểu.'),
          findsOneWidget,
        );
        await enter(t, 'vaccines.editor.min', '2');
        await enter(t, 'vaccines.editor.max', '7');
        await t.tap(find.byKey(const ValueKey('vaccines.editor.save')));
        await t.pumpAndSettle();
        expect(fake.putCount, 1);
        expect(
          find.textContaining('Đã đổi điều kiện bảo quản.'),
          findsOneWidget,
        );
      } finally {
        await cleanup(t, auth);
      }
    },
  );
  testWidgets(
    'stale organization form requires reload and preserves new ETag',
    (t) async {
      final fake = FakeCatalogApi()..conflictOn = 'organizations';
      final auth = await open(t, fake, 'organizations');
      try {
        await t.tap(find.byKey(const ValueKey('organizations.edit.1')));
        await t.pumpAndSettle();
        await enter(t, 'organizations.editor.name', 'Nháp');
        await t.tap(find.byKey(const ValueKey('organizations.editor.save')));
        await t.pumpAndSettle();
        expect(
          t
              .widget<FilledButton>(
                find.byKey(const ValueKey('organizations.editor.save')),
              )
              .onPressed,
          isNull,
        );
        await t.ensureVisible(
          find.byKey(const ValueKey('organizations.editor.reload')),
        );
        await t.tap(find.byKey(const ValueKey('organizations.editor.reload')));
        await t.pumpAndSettle();
        await enter(t, 'organizations.editor.name', 'Đã đối chiếu');
        await t.tap(find.byKey(const ValueKey('organizations.editor.save')));
        await t.pumpAndSettle();
        expect(
          fake.requests.lastWhere((r) => r.method == 'PUT').headers['If-Match'],
          '"$v2"',
        );
      } finally {
        await cleanup(t, auth);
      }
    },
  );
  testWidgets(
    'mobile staff is read only and referenced vaccine cannot be deleted by Admin',
    (t) async {
      final staff = await open(
        t,
        FakeCatalogApi(role: 'WarehouseStaff'),
        'vaccines',
        mobile: true,
      );
      try {
        expect(find.text('Vaccine gốc'), findsOneWidget);
        expect(find.byKey(const ValueKey('vaccines.add')), findsNothing);
        expect(find.byKey(const ValueKey('vaccines.edit.1')), findsNothing);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, staff);
      }
      final fake = FakeCatalogApi()..blockDelete = true;
      final admin = await open(t, fake, 'vaccines');
      try {
        final button = find.byKey(const ValueKey('vaccines.delete.1'));
        await t.ensureVisible(button);
        await t.tap(button);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('vaccines.delete.confirm')));
        await t.pumpAndSettle();
        expect(
          t
              .widget<FilledButton>(
                find.byKey(const ValueKey('vaccines.delete.confirm')),
              )
              .onPressed,
          isNull,
        );
        expect(fake.vaccines.containsKey(1), isTrue);
      } finally {
        await cleanup(t, admin);
      }
    },
  );
  testWidgets(
    'revoked session removes both vaccine editor and manufacturer picker',
    (t) async {
      final fake = FakeCatalogApi()..revokeLookup = true;
      final auth = await open(t, fake, 'vaccines');
      try {
        await t.tap(find.byKey(const ValueKey('vaccines.add')));
        await t.pumpAndSettle();
        await t.ensureVisible(
          find.byKey(const ValueKey('vaccines.editor.manufacturer')),
        );
        await t.tap(find.byKey(const ValueKey('vaccines.editor.manufacturer')));
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.byKey(const ValueKey('server.login.submit')),
          findsOneWidget,
        );
      } finally {
        await cleanup(t, auth);
      }
    },
  );
}
