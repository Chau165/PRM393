import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/data/local/local_data_store.dart';
import 'package:warehouse/domain/models/warehouse_app_data.dart';
import 'package:warehouse/domain/services/warehouse_app_state.dart';
import 'package:warehouse/features/documents/document_list_page.dart';
import 'package:warehouse/features/inventory/inventory_page.dart';
import 'package:warehouse/features/master_data/master_data_page.dart';
import 'package:warehouse/features/reports/report_page.dart';
import 'package:warehouse/features/warehouse_permissions/warehouse_permissions_page.dart';

class FeatureTestDataStore implements LocalDataStore {
  String? json;

  @override
  Future<String?> loadJson() async => json;

  @override
  Future<void> saveJson(String value) async => json = value;
}

Future<WarehouseAppState> createState() =>
    WarehouseAppState.create(store: FeatureTestDataStore());

Widget featureHost(WarehouseAppState state, Widget Function() pageBuilder) =>
    MaterialApp(
      home: AnimatedBuilder(
        animation: state,
        builder: (context, _) => Scaffold(body: pageBuilder()),
      ),
    );

void useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'inventory filters in compact layout and renders a desktop table',
    (tester) async {
      useSize(tester, const Size(390, 844));
      final state = await createState();
      final admin = state.data.users.firstWhere(
        (user) => user.role == UserRole.admin,
      );
      await tester.pumpWidget(
        featureHost(state, () => InventoryPage(state: state, user: admin)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tồn kho hiện tại'), findsOneWidget);
      expect(find.textContaining('SP001'), findsWidgets);
      await tester.enterText(find.byType(TextField), 'khong-co-ma-nay');
      await tester.pumpAndSettle();
      expect(find.text('Không có dữ liệu tồn kho'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      useSize(tester, const Size(1280, 900));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Đang giữ'), findsOneWidget);
    },
  );

  testWidgets('report displays posted movements and responsive summaries', (
    tester,
  ) async {
    useSize(tester, const Size(390, 844));
    final state = await createState();
    final admin = state.data.users.firstWhere(
      (user) => user.role == UserRole.admin,
    );
    final today = DateTime.now();
    final movementDate = DateTime(today.year, today.month, today.day);
    final receiptIndex = state.data.receipts.indexWhere(
      (document) => document.status == DocumentStatus.posted,
    );
    state.data.receipts[receiptIndex] = state.data.receipts[receiptIndex]
        .copyWith(documentDate: movementDate);
    final issueIndex = state.data.issues.indexWhere(
      (document) => document.status == DocumentStatus.posted,
    );
    state.data.issues[issueIndex] = state.data.issues[issueIndex].copyWith(
      documentDate: movementDate,
    );

    await tester.pumpWidget(
      featureHost(state, () => ReportPage(state: state, user: admin)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo Xuất - Nhập - Tồn'), findsOneWidget);
    expect(find.textContaining('SP001'), findsWidgets);
    expect(find.text('Tổng nhập: 162'), findsOneWidget);
    expect(find.text('Tổng xuất: 20'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);

    useSize(tester, const Size(1280, 900));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('receipt editor saves details and the list posts the draft', (
    tester,
  ) async {
    useSize(tester, const Size(1280, 900));
    final state = await createState();
    final admin = state.data.users.firstWhere(
      (user) => user.role == UserRole.admin,
    );
    await tester.pumpWidget(
      featureHost(
        state,
        () => DocumentListPage(state: state, user: admin, isReceipt: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tạo phiếu'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog).last,
            matching: find.byType(TextFormField),
          )
          .first,
      'PN-UI-TEST',
    );
    await tester.tap(find.text('Thêm sản phẩm'));
    await tester.pumpAndSettle();
    final lineFields = find.descendant(
      of: find.byType(AlertDialog).last,
      matching: find.byType(TextFormField),
    );
    await tester.enterText(lineFields.at(0), '5');
    await tester.enterText(lineFields.at(1), '12.5');
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu nháp'));
    await tester.pumpAndSettle();

    final created = state.data.receipts.singleWhere(
      (document) => document.documentNo == 'PN-UI-TEST',
    );
    expect(created.status, DocumentStatus.draft);
    expect(
      state.data.receiptDetails
          .singleWhere((line) => line.receiptId == created.id)
          .quantity,
      5,
    );

    await tester.tap(find.byTooltip('Post phiếu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post phiếu'));
    await tester.pumpAndSettle();
    expect(
      state.data.receipts.singleWhere((doc) => doc.id == created.id).status,
      DocumentStatus.posted,
    );
  });

  testWidgets('master data forms create each supported record type', (
    tester,
  ) async {
    useSize(tester, const Size(1280, 900));
    final state = await createState();
    final admin = state.data.users.firstWhere(
      (user) => user.role == UserRole.admin,
    );
    final cases = <(MasterDataKind, String)>[
      (MasterDataKind.warehouse, 'Kho giao diện'),
      (MasterDataKind.unit, 'Thùng giao diện'),
      (MasterDataKind.category, 'Nhóm giao diện'),
      (MasterDataKind.product, 'Sản phẩm giao diện'),
      (MasterDataKind.supplier, 'Nhà cung cấp giao diện'),
    ];

    for (final (kind, name) in cases) {
      await tester.pumpWidget(
        featureHost(
          state,
          () => MasterDataPage(
            key: ValueKey(kind),
            state: state,
            user: admin,
            kind: kind,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm mới'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      switch (kind) {
        case MasterDataKind.warehouse:
        case MasterDataKind.unit:
          await tester.enterText(fields.first, name);
        case MasterDataKind.category:
        case MasterDataKind.supplier:
        case MasterDataKind.product:
          await tester.enterText(fields.first, 'UI-${kind.name}');
          await tester.enterText(fields.at(1), name);
      }
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
    }

    expect(
      state.data.warehouses.any((item) => item.name == 'Kho giao diện'),
      isTrue,
    );
    expect(
      state.data.units.any((item) => item.name == 'Thùng giao diện'),
      isTrue,
    );
    expect(
      state.data.categories.any((item) => item.name == 'Nhóm giao diện'),
      isTrue,
    );
    expect(
      state.data.products.any((item) => item.name == 'Sản phẩm giao diện'),
      isTrue,
    );
    expect(
      state.data.suppliers.any((item) => item.name == 'Nhà cung cấp giao diện'),
      isTrue,
    );
  });

  testWidgets('permission screen assigns a user to another warehouse', (
    tester,
  ) async {
    useSize(tester, const Size(390, 844));
    final state = await createState();
    final admin = state.data.users.firstWhere(
      (user) => user.role == UserRole.admin,
    );
    final user = state.data.users.firstWhere(
      (item) => item.username == 'user_hcm',
    );
    final warehouse = state.data.warehouses.firstWhere(
      (item) => item.name.contains('Hà Nội'),
    );
    await tester.pumpWidget(
      featureHost(
        state,
        () => WarehousePermissionsPage(state: state, user: admin),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Phân quyền Kho - User'), findsOneWidget);
    await tester.tap(find.text('Thêm phân quyền'));
    await tester.pumpAndSettle();
    final dropdowns = find.byType(DropdownButtonFormField<int>);
    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('${user.fullName} (${user.username})').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(warehouse.name).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(
      state.data.assignments.any(
        (item) => item.userId == user.id && item.warehouseId == warehouse.id,
      ),
      isTrue,
    );
  });
}
