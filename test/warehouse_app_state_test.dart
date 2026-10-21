import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/data/local/local_data_store.dart';
import 'package:warehouse/domain/models/warehouse_app_data.dart';
import 'package:warehouse/domain/services/domain_exception.dart';
import 'package:warehouse/domain/services/warehouse_app_state.dart';

class FakeLocalDataStore implements LocalDataStore {
  String? json;
  bool failNextWrite = false;

  @override
  Future<String?> loadJson() async => json;

  @override
  Future<void> saveJson(String value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('simulated persistence failure');
    }
    json = value;
  }
}

void main() {
  late FakeLocalDataStore store;
  late WarehouseAppState state;
  late AppUser admin;
  late AppUser hcmUser;
  late Warehouse hcm;
  late Warehouse hanoi;
  late Product product;

  setUp(() async {
    store = FakeLocalDataStore();
    state = await WarehouseAppState.create(store: store);
    admin = state.data.users.firstWhere((user) => user.username == 'admin');
    hcmUser = state.data.users.firstWhere(
      (user) => user.username == 'user_hcm',
    );
    hcm = state.data.warehouses.firstWhere(
      (warehouse) => warehouse.name.contains('Hồ Chí Minh'),
    );
    hanoi = state.data.warehouses.firstWhere(
      (warehouse) => warehouse.name.contains('Hà Nội'),
    );
    product = state.data.products.firstWhere((item) => item.code == 'SP001');
  });

  group('demo data and authentication', () {
    test('seeds local data and restores it from JSON', () async {
      expect(await state.login('admin', 'admin123'), isTrue);
      expect(state.currentUser?.role, UserRole.admin);
      expect(await state.login('admin', 'wrong'), isFalse);

      final reopened = await WarehouseAppState.create(store: store);
      expect(reopened.data.products, hasLength(6));
      expect(
        reopened.data.receipts
            .singleWhere((doc) => doc.status == DocumentStatus.posted)
            .documentDate,
        DateTime(2026, 9, 1, 8),
      );
      expect(
        reopened.data.receipts
            .singleWhere((doc) => doc.status == DocumentStatus.posted)
            .postedAt,
        isNotNull,
      );
    });

    test('rolls back in-memory changes when persistence fails', () async {
      final initialCount = state.data.warehouses.length;
      store.failNextWrite = true;

      await expectLater(
        state.createWarehouse(admin, name: 'Kho kiểm tra'),
        throwsA(isA<StateError>()),
      );

      expect(state.data.warehouses, hasLength(initialCount));
    });

    test('admin can reset the demo dataset and persist the reset', () async {
      await state.createWarehouse(admin, name: 'Kho tạm');
      await state.resetDemoData(admin);

      expect(state.data.warehouses, hasLength(2));
      expect(state.currentUser?.username, 'admin');
      final reopened = await WarehouseAppState.create(store: store);
      expect(reopened.data.warehouses, hasLength(2));
    });

    test(
      'only admins can reset, and a failed reset restores the prior data',
      () async {
        final previous = state.data;
        await expectLater(
          state.resetDemoData(hcmUser),
          throwsA(isA<DomainException>()),
        );

        store.failNextWrite = true;
        await expectLater(
          state.resetDemoData(admin),
          throwsA(isA<StateError>()),
        );
        expect(identical(state.data, previous), isTrue);
      },
    );
  });

  group('warehouse authorization', () {
    test(
      'limits user inventory to assigned warehouses and rejects direct access',
      () async {
        final visible = state.currentInventory(hcmUser);
        expect(visible, isNotEmpty);
        expect(visible.every((row) => row.warehouseId == hcm.id), isTrue);

        expect(
          () => state.currentInventory(hcmUser, warehouseId: hanoi.id),
          throwsA(isA<DomainException>()),
        );
      },
    );

    test(
      'rejects an unauthorized issue even when called outside the UI',
      () async {
        final issue = IssueDocument(
          id: 0,
          documentNo: 'PX-OUT-OF-SCOPE',
          warehouseId: hanoi.id,
          documentDate: DateTime(2026, 9, 22),
        );

        await expectLater(
          state.saveIssue(hcmUser, issue, [
            IssueDetail(
              id: 0,
              issueId: 0,
              productId: product.id,
              quantity: 1,
              unitPrice: 0,
            ),
          ]),
          throwsA(isA<DomainException>()),
        );
      },
    );

    test(
      'checks warehouse access before revealing a document status',
      () async {
        final hanoiUser = state.data.users.firstWhere(
          (user) => user.username == 'user_hn',
        );
        final postedReceipt = state.data.receipts.firstWhere(
          (document) => document.status == DocumentStatus.posted,
        );

        await expectLater(
          state.deleteReceipt(hanoiUser, postedReceipt.id),
          throwsA(
            isA<DomainException>().having(
              (error) => error.message,
              'message',
              'Bạn không có quyền truy cập kho này.',
            ),
          ),
        );
      },
    );

    test('admin can read inventory from every warehouse', () {
      final warehouseIds = state
          .currentInventory(admin)
          .map((row) => row.warehouseId)
          .toSet();
      expect(
        warehouseIds,
        containsAll(state.data.warehouses.map((warehouse) => warehouse.id)),
      );
    });
  });

  group('derived inventory and issue reservations', () {
    test('derives On Hand, Reserved, and Available from documents', () {
      final item = state
          .currentInventory(hcmUser, warehouseId: hcm.id)
          .singleWhere((row) => row.productId == product.id);

      expect(item.onHand, 80);
      expect(item.reserved, 15);
      expect(item.available, 65);
    });

    test(
      'rejects over-reservation and excludes the edited issue reservation',
      () async {
        final tooLarge = IssueDocument(
          id: 0,
          documentNo: 'PX-TOO-LARGE',
          warehouseId: hcm.id,
          documentDate: DateTime(2026, 9, 22),
        );
        await expectLater(
          state.saveIssue(hcmUser, tooLarge, [
            IssueDetail(
              id: 0,
              issueId: 0,
              productId: product.id,
              quantity: 66,
              unitPrice: 0,
            ),
          ]),
          throwsA(
            isA<DomainException>().having(
              (error) => error.message,
              'message',
              contains('Số lượng khả dụng không đủ. Khả dụng hiện tại: 65'),
            ),
          ),
        );

        final issue = await state.saveIssue(
          hcmUser,
          IssueDocument(
            id: 0,
            documentNo: 'PX-EDIT-RESERVATION',
            warehouseId: hcm.id,
            documentDate: DateTime(2026, 9, 22),
          ),
          [
            IssueDetail(
              id: 0,
              issueId: 0,
              productId: product.id,
              quantity: 60,
              unitPrice: 0,
            ),
          ],
        );
        await state.saveIssue(hcmUser, issue.copyWith(note: 'đã sửa'), [
          IssueDetail(
            id: 0,
            issueId: issue.id,
            productId: product.id,
            quantity: 65,
            unitPrice: 0,
          ),
        ]);

        final item = state
            .currentInventory(hcmUser, warehouseId: hcm.id)
            .singleWhere((row) => row.productId == product.id);
        expect(item.reserved, 80);
        expect(item.available, 0);
      },
    );

    test('posting an issue decreases On Hand and releases its reservation permanently', () async {
      final issue = await state.saveIssue(
        hcmUser,
        IssueDocument(
          id: 0,
          documentNo: 'PX-POST-TEST',
          warehouseId: hcm.id,
          documentDate: DateTime(2026, 9, 22),
        ),
        [
          IssueDetail(
            id: 0,
            issueId: 0,
            productId: product.id,
            quantity: 60,
            unitPrice: 0,
          ),
        ],
      );
      await state.postIssue(hcmUser, issue.id);

      var item = state
          .currentInventory(hcmUser, warehouseId: hcm.id)
          .singleWhere((row) => row.productId == product.id);
      expect(item.onHand, 20);
      expect(item.reserved, 15);
      expect(item.available, 5);

      await expectLater(
        state.deleteIssue(hcmUser, issue.id),
        throwsA(isA<DomainException>()),
      );
      await expectLater(
        state.saveIssue(hcmUser, issue.copyWith(note: 'không được sửa'), [
          IssueDetail(
            id: 0,
            issueId: issue.id,
            productId: product.id,
            quantity: 1,
            unitPrice: 0,
          ),
        ]),
        throwsA(isA<DomainException>()),
      );
    });
  });

  group('receipt lifecycle and master data integrity', () {
    test('draft receipts do not move stock; posting does, and posted receipts are locked', () async {
      final before = state
          .currentInventory(hcmUser, warehouseId: hcm.id)
          .singleWhere((row) => row.productId == product.id)
          .onHand;
      final receipt = await state.saveReceipt(
        hcmUser,
        ReceiptDocument(
          id: 0,
          documentNo: 'PN-POST-TEST',
          warehouseId: hcm.id,
          supplierId: state.data.suppliers.first.id,
          documentDate: DateTime(2026, 9, 23),
        ),
        [
          ReceiptDetail(
            id: 0,
            receiptId: 0,
            productId: product.id,
            quantity: 5,
            unitPrice: 10,
          ),
        ],
      );
      expect(
        state
            .currentInventory(hcmUser, warehouseId: hcm.id)
            .singleWhere((row) => row.productId == product.id)
            .onHand,
        before,
      );

      await state.postReceipt(hcmUser, receipt.id);
      expect(
        state
            .currentInventory(hcmUser, warehouseId: hcm.id)
            .singleWhere((row) => row.productId == product.id)
            .onHand,
        before + 5,
      );
      await expectLater(
        state.deleteReceipt(hcmUser, receipt.id),
        throwsA(isA<DomainException>()),
      );
    });

    test(
      'validates master data and prevents deleting referenced records',
      () async {
        await expectLater(
          state.createWarehouse(admin, name: '  '),
          throwsA(isA<DomainException>()),
        );
        await expectLater(
          state.createProduct(
            admin,
            code: product.code,
            name: 'Trùng mã',
            categoryId: product.categoryId,
            unitId: product.unitId,
          ),
          throwsA(isA<DomainException>()),
        );
        await expectLater(
          state.deleteUnit(admin, product.unitId),
          throwsA(isA<DomainException>()),
        );
        await expectLater(
          state.deleteProduct(admin, product.id),
          throwsA(isA<DomainException>()),
        );
        await expectLater(
          state.deleteSupplier(admin, state.data.receipts.first.supplierId),
          throwsA(isA<DomainException>()),
        );
        await expectLater(
          state.deleteWarehouse(admin, hcm.id),
          throwsA(isA<DomainException>()),
        );
      },
    );

    test('enforces unique user and warehouse assignments', () async {
      await expectLater(
        state.createWarehouseAssignment(
          admin,
          userId: hcmUser.id,
          warehouseId: hcm.id,
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test(
      'updates and deletes unreferenced master records and assignments',
      () async {
        final warehouse = await state.createWarehouse(admin, name: 'Kho tạm');
        await state.updateWarehouse(
          admin,
          id: warehouse.id,
          name: 'Kho đã sửa',
          note: 'ghi chú',
        );
        expect(
          state.data.warehouses
              .singleWhere((item) => item.id == warehouse.id)
              .name,
          'Kho đã sửa',
        );
        await state.deleteWarehouse(admin, warehouse.id);

        final unit = await state.createUnit(admin, name: 'Bộ tạm');
        await state.updateUnit(admin, id: unit.id, name: 'Bộ đã sửa');
        await state.deleteUnit(admin, unit.id);

        final category = await state.createCategory(
          admin,
          code: 'CAT-TEMP',
          name: 'Nhóm tạm',
        );
        await state.updateCategory(
          admin,
          id: category.id,
          code: 'CAT-EDIT',
          name: 'Nhóm đã sửa',
        );
        await state.deleteCategory(admin, category.id);

        final disposableCategory = await state.createCategory(
          admin,
          code: 'CAT-PRODUCT',
          name: 'Nhóm cho sản phẩm tạm',
        );
        final disposableUnit = await state.createUnit(
          admin,
          name: 'Đơn vị cho sản phẩm tạm',
        );
        final disposableProduct = await state.createProduct(
          admin,
          code: 'SP-TEMP',
          name: 'Sản phẩm tạm',
          categoryId: disposableCategory.id,
          unitId: disposableUnit.id,
        );
        await state.updateProduct(
          admin,
          id: disposableProduct.id,
          code: 'SP-EDIT',
          name: 'Sản phẩm đã sửa',
          categoryId: disposableCategory.id,
          unitId: disposableUnit.id,
        );
        await state.deleteProduct(admin, disposableProduct.id);
        await state.deleteCategory(admin, disposableCategory.id);
        await state.deleteUnit(admin, disposableUnit.id);

        final supplier = await state.createSupplier(
          admin,
          code: 'NCC-TEMP',
          name: 'Nhà cung cấp tạm',
        );
        await state.updateSupplier(
          admin,
          id: supplier.id,
          code: 'NCC-EDIT',
          name: 'Nhà cung cấp đã sửa',
        );
        await state.deleteSupplier(admin, supplier.id);

        final assignment = await state.createWarehouseAssignment(
          admin,
          userId: hcmUser.id,
          warehouseId: hanoi.id,
        );
        final hanoiUser = state.data.users.firstWhere(
          (user) => user.username == 'user_hn',
        );
        await state.updateWarehouseAssignment(
          admin,
          id: assignment.id,
          userId: hanoiUser.id,
          warehouseId: hcm.id,
        );
        await state.deleteWarehouseAssignment(admin, assignment.id);
        expect(
          state.data.assignments.any((item) => item.id == assignment.id),
          isFalse,
        );
      },
    );
  });

  group('period report', () {
    test('uses posted movements in the inclusive date range and ignores Draft documents', () {
      final rows = state.periodInventoryReport(
        hcmUser,
        fromDate: DateTime(2026, 9, 15),
        toDate: DateTime(2026, 9, 30),
        warehouseId: hcm.id,
        search: 'SP001',
      );
      final row = rows.single;

      expect(row.opening, 100);
      expect(row.received, 0);
      expect(row.issued, 20);
      expect(row.closing, 80);
    });

    test('rejects invalid date ranges and unauthorized warehouse filters', () {
      expect(
        () => state.periodInventoryReport(
          hcmUser,
          fromDate: DateTime(2026, 10, 2),
          toDate: DateTime(2026, 10, 1),
        ),
        throwsA(isA<DomainException>()),
      );
      expect(
        () => state.periodInventoryReport(
          hcmUser,
          fromDate: DateTime(2026, 9, 1),
          toDate: DateTime(2026, 9, 30),
          warehouseId: hanoi.id,
        ),
        throwsA(isA<DomainException>()),
      );
    });
  });
}
