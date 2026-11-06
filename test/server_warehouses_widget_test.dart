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

class FakeWarehouseApi {
  FakeWarehouseApi({this.role = 'Admin'});
  final String role;
  final rows = <int, Map<String, dynamic>>{
    1: {'id': 1, 'code': 'HCM', 'name': 'Kho HCM', 'version': v1},
  };
  int putCount = 0, deleteCount = 0, postCount = 0;
  bool conflictNext = false, blockDelete = false, revokeOnSave = false;
  final versions = <String?>[];
  http.Response json(Object data, [int status = 200, String? etag]) =>
      http.Response(
        jsonEncode(data),
        status,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'etag': ?etag,
        },
      );
  Future<http.Response> handle(http.Request r) async {
    final user = {
      'id': 7,
      'username': 'user',
      'fullName': 'Người dùng',
      'role': role,
      'warehouses': rows.values
          .map((w) => {'id': w['id'], 'code': w['code'], 'name': w['name']})
          .toList(),
    };
    if (r.url.path.endsWith('/auth/login')) {
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
    if (r.url.path.endsWith('/auth/me')) return json(user);
    if (r.url.path.endsWith('/auth/logout')) return json({'loggedOut': true});
    expect(r.headers['Authorization'], startsWith('Bearer '));
    if (r.url.path.endsWith('/warehouses')) {
      if (r.method == 'GET') {
        return json({
          'items': rows.values.toList(),
          'page': 1,
          'pageSize': 20,
          'totalItems': rows.length,
          'totalPages': rows.isEmpty ? 0 : 1,
        });
      }
      postCount++;
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      rows[2] = {'id': 2, ...body, 'version': v1};
      return json(rows[2]!, 201, '"$v1"');
    }
    final id = int.parse(r.url.pathSegments.last);
    if (r.method == 'GET') {
      return json(rows[id]!, 200, '"${rows[id]!['version']}"');
    }
    versions.add(r.headers['If-Match']);
    if (r.method == 'PUT') {
      putCount++;
      if (revokeOnSave) return json({'title': 'Phiên đã kết thúc.'}, 401);
      if (conflictNext) {
        conflictNext = false;
        rows[id] = {...rows[id]!, 'name': 'Tên từ người khác', 'version': v2};
        return json({'title': 'Changed', 'code': 'CONCURRENCY_CONFLICT'}, 412);
      }
      rows[id] = {
        ...rows[id]!,
        ...jsonDecode(r.body) as Map<String, dynamic>,
        'version': v2,
      };
      return json(rows[id]!, 200, '"$v2"');
    }
    deleteCount++;
    if (blockDelete) {
      return json({'title': 'In use', 'code': 'RESOURCE_IN_USE'}, 409);
    }
    rows.remove(id);
    return http.Response('', 204);
  }
}

Future<AuthController> open(
  WidgetTester tester,
  FakeWarehouseApi fake, {
  bool mobile = false,
}) async {
  tester.view.physicalSize = Size(mobile ? 390 : 1200, 1000);
  tester.view.devicePixelRatio = 1;
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
  await tester.pumpWidget(VaxStockAuthApp(auth: auth));
  await tester.pumpAndSettle();
  if (mobile) {
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const ValueKey('server.nav.warehouses')));
  await tester.pumpAndSettle();
  return auth;
}

Future<void> cleanup(WidgetTester tester, AuthController auth) async {
  await tester.pumpWidget(const SizedBox.shrink());
  auth.dispose();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  testWidgets(
    'Admin creates edits and deletes warehouses through the server shell',
    (tester) async {
      final fake = FakeWarehouseApi();
      final auth = await open(tester, fake);
      try {
        await tester.tap(find.byKey(const ValueKey('warehouses.add')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('warehouses.editor.code')),
          ' NEW ',
        );
        await tester.enterText(
          find.byKey(const ValueKey('warehouses.editor.name')),
          ' Kho mới ',
        );
        await tester.tap(find.byKey(const ValueKey('warehouses.editor.save')));
        await tester.pumpAndSettle();
        expect(fake.postCount, 1);
        expect(find.text('Kho mới'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('warehouses.edit.2')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('warehouses.editor.name')),
          'Kho cập nhật',
        );
        await tester.tap(find.byKey(const ValueKey('warehouses.editor.save')));
        await tester.pumpAndSettle();
        expect(find.text('Kho cập nhật'), findsOneWidget);
        expect(fake.versions.last, '"$v1"');
        await tester.tap(find.byKey(const ValueKey('warehouses.delete.2')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('warehouses.delete.confirm')),
        );
        await tester.pumpAndSettle();
        expect(fake.deleteCount, 1);
        expect(fake.versions.last, '"$v2"');
        expect(find.text('Kho cập nhật'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await cleanup(tester, auth);
      }
    },
  );

  testWidgets(
    'mobile staff navigation is read only and logout clears the shell',
    (tester) async {
      final auth = await open(
        tester,
        FakeWarehouseApi(role: 'WarehouseStaff'),
        mobile: true,
      );
      try {
        expect(find.text('Kho HCM'), findsOneWidget);
        expect(find.byKey(const ValueKey('warehouses.add')), findsNothing);
        expect(find.byKey(const ValueKey('warehouses.edit.1')), findsNothing);
        expect(find.byKey(const ValueKey('warehouses.delete.1')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('warehouses.view.1')));
        await tester.pumpAndSettle();
        expect(find.text('Thông tin kho'), findsOneWidget);
        await tester.tap(find.text('Đóng'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('server.logout')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('server.login.submit')),
          findsOneWidget,
        );
        expect(find.text('Kho HCM'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await cleanup(tester, auth);
      }
    },
  );

  testWidgets('412 requires explicit reload before saving with the new ETag', (
    tester,
  ) async {
    final fake = FakeWarehouseApi()..conflictNext = true;
    final auth = await open(tester, fake);
    try {
      await tester.tap(find.byKey(const ValueKey('warehouses.edit.1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('warehouses.editor.name')),
        'Bản nháp',
      );
      await tester.tap(find.byKey(const ValueKey('warehouses.editor.save')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('warehouses.editor.save')),
            )
            .onPressed,
        isNull,
      );
      expect(fake.putCount, 1);
      await tester.tap(find.byKey(const ValueKey('warehouses.editor.reload')));
      await tester.pumpAndSettle();
      expect(find.text('Tên từ người khác'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('warehouses.editor.name')),
        'Bản đã đối chiếu',
      );
      await tester.tap(find.byKey(const ValueKey('warehouses.editor.save')));
      await tester.pumpAndSettle();
      expect(fake.putCount, 2);
      expect(fake.versions, ['"$v1"', '"$v2"']);
      expect(find.text('Bản đã đối chiếu'), findsOneWidget);
    } finally {
      await cleanup(tester, auth);
    }
  });

  testWidgets('409 keeps referenced warehouse and prevents repeated delete', (
    tester,
  ) async {
    final fake = FakeWarehouseApi()..blockDelete = true;
    final auth = await open(tester, fake);
    try {
      await tester.tap(find.byKey(const ValueKey('warehouses.delete.1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('warehouses.delete.confirm')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('warehouses.delete.confirm')),
            )
            .onPressed,
        isNull,
      );
      expect(fake.deleteCount, 1);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Kho HCM'), findsOneWidget);
    } finally {
      await cleanup(tester, auth);
    }
  });

  testWidgets('401 during an editor removes the dialog and returns to login', (
    tester,
  ) async {
    final fake = FakeWarehouseApi()..revokeOnSave = true;
    final auth = await open(tester, fake);
    try {
      await tester.tap(find.byKey(const ValueKey('warehouses.edit.1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('warehouses.editor.name')),
        'Change',
      );
      await tester.tap(find.byKey(const ValueKey('warehouses.editor.save')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const ValueKey('server.login.submit')), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await cleanup(tester, auth);
    }
  });
}
