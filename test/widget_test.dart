import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/app/app.dart';
import 'package:warehouse/data/local/local_data_store.dart';
import 'package:warehouse/domain/services/warehouse_app_state.dart';

class WidgetTestDataStore implements LocalDataStore {
  String? json;

  @override
  Future<String?> loadJson() async => json;

  @override
  Future<void> saveJson(String value) async {
    json = value;
  }
}

void main() {
  testWidgets('admin can sign in and open responsive navigation on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = await WarehouseAppState.create(store: WidgetTestDataStore());
    await tester.pumpWidget(WarehouseApp(state: state));

    expect(find.text('Warehouse Management Demo'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('login.username')),
      'admin',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login.password')),
      'admin123',
    );
    await tester.tap(find.byKey(const ValueKey('login.submit')));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Kho Hồ Chí Minh'), findsWidgets);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Phiếu nhập'), findsOneWidget);
    final drawerList = find
        .descendant(of: find.byType(Drawer), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.text('Phân quyền kho - user'),
      250,
      scrollable: drawerList,
    );
    expect(find.text('Phân quyền kho - user'), findsOneWidget);
  });

  testWidgets('invalid login stays on the login screen', (tester) async {
    final state = await WarehouseAppState.create(store: WidgetTestDataStore());
    await tester.pumpWidget(WarehouseApp(state: state));

    await tester.enterText(
      find.byKey(const ValueKey('login.username')),
      'admin',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login.password')),
      'wrong',
    );
    await tester.tap(find.byKey(const ValueKey('login.submit')));
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập'), findsWidgets);
    expect(
      find.text('Tên đăng nhập hoặc mật khẩu không đúng.'),
      findsOneWidget,
    );
  });
}
