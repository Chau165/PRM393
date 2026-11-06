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

const _user = {
  'id': 7,
  'username': 'staff.hcm',
  'fullName': 'Nhân viên HCM',
  'role': 'WarehouseStaff',
  'warehouses': [
    {'id': 1, 'code': 'HCM', 'name': 'Kho HCM'},
  ],
};
String _token() =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})))}.signature';
http.Response _json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
AuthController _controller(
  MemoryTokenStore store,
  Future<http.Response> Function(http.Request) handler,
) => AuthController(
  tokens: store,
  repository: AuthRepository(
    ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient(handler),
    ),
  ),
);

void main() {
  test('restore rechecks the server and clears revoked credentials', () async {
    final store = MemoryTokenStore();
    await store.write(_token());
    final auth = _controller(
      store,
      (r) async => _json({'title': 'Revoked'}, 401),
    );
    addTearDown(auth.dispose);
    await auth.restore();
    expect(auth.status, SessionStatus.signedOut);
    expect(await store.read(), isNull);
    expect(auth.user, isNull);
  });

  test(
    'network/server failure during restore does not masquerade as bad password',
    () async {
      final store = MemoryTokenStore();
      final token = _token();
      await store.write(token);
      final auth = _controller(
        store,
        (r) async => _json({'title': 'Unavailable'}, 503),
      );
      addTearDown(auth.dispose);
      await auth.restore();
      expect(auth.status, SessionStatus.restoreFailed);
      expect(await store.read(), token);
    },
  );

  test('403 keeps the authenticated session; logout failure only clears local session', () async {
    final store = MemoryTokenStore();
    var forbidden = false;
    final auth = _controller(store, (r) async {
      if (r.url.path.endsWith('login')) {
        return _json({
          'accessToken': _token(),
          'expiresIn': 900,
          'user': _user,
        });
      }
      if (r.url.path.endsWith('logout')) {
        return _json({'title': 'Unavailable'}, 503);
      }
      return forbidden ? _json({'title': 'Forbidden'}, 403) : _json(_user);
    });
    addTearDown(auth.dispose);
    await auth.restore();
    await auth.login('staff.hcm', 'password');
    forbidden = true;
    await auth.refreshUser();
    expect(auth.status, SessionStatus.signedIn);
    expect(await store.read(), isNotNull);
    await auth.logout();
    expect(auth.status, SessionStatus.signedOut);
    expect(await store.read(), isNull);
    expect(auth.notice, contains('chưa xác nhận'));
  });

  test(
    'successful password change clears credentials and requires login',
    () async {
      final store = MemoryTokenStore();
      final auth = _controller(store, (r) async {
        if (r.url.path.endsWith('login')) {
          return _json({
            'accessToken': _token(),
            'expiresIn': 900,
            'user': _user,
          });
        }
        expect(r.headers['Authorization'], startsWith('Bearer '));
        expect(jsonDecode(r.body)['currentPassword'], 'current-password');
        return _json({'reauthenticationRequired': true});
      });
      addTearDown(auth.dispose);
      await auth.restore();
      await auth.login('staff.hcm', 'current-password');
      expect(
        await auth.changePassword('current-password', 'new-password-long'),
        isTrue,
      );
      expect(auth.status, SessionStatus.signedOut);
      expect(await store.read(), isNull);
    },
  );

  test('a late 401 for an old token does not clear a newer token', () async {
    late final ApiClient api;
    api = ApiClient(
      baseUrl: 'https://example.test/',
      client: MockClient((r) async {
        api.token = 'new';
        return _json({'title': 'Expired'}, 401);
      }),
    );
    // Callback users receive the rejected token, not the mutable current token.
    String? rejected;
    api.onUnauthorized = (token) => rejected = token;
    api.token = 'old';
    await expectLater(api.request('GET', 'me'), throwsA(isA<ApiException>()));
    expect(rejected, 'old');
    expect(api.token, 'new');
    api.close();
  });

  testWidgets(
    'server login displays role/warehouses and does not accept local demo credentials',
    (tester) async {
      final store = MemoryTokenStore();
      var calls = 0;
      final auth = _controller(store, (r) async {
        calls++;
        expect(r.url.path, '/api/v1/auth/login');
        final body = jsonDecode(r.body);
        if (body['password'] == 'wrong') {
          return _json({'title': 'Thông tin đăng nhập không hợp lệ.'}, 401);
        }
        return _json({
          'accessToken': _token(),
          'expiresIn': 900,
          'user': _user,
        });
      });
      await auth.restore();
      await tester.pumpWidget(VaxStockAuthApp(auth: auth));
      await tester.enterText(
        find.byKey(const ValueKey('server.login.username')),
        'staff.hcm',
      );
      await tester.enterText(
        find.byKey(const ValueKey('server.login.password')),
        'wrong',
      );
      await tester.tap(find.byKey(const ValueKey('server.login.submit')));
      await tester.pumpAndSettle();
      expect(find.text('Thông tin đăng nhập không hợp lệ.'), findsOneWidget);
      expect(find.text('Kho được truy cập'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('server.login.password')),
        'correct-password',
      );
      await tester.tap(find.byKey(const ValueKey('server.login.submit')));
      await tester.pumpAndSettle();
      expect(find.text('Kho HCM'), findsOneWidget);
      expect(find.text('staff.hcm · Nhân viên kho'), findsOneWidget);
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
}
