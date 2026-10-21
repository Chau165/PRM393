import '../../domain/models/warehouse_app_data.dart';

WarehouseAppData createDemoData() {
  final receiptDate = DateTime(2026, 9, 1, 8);
  final postedIssueDate = DateTime(2026, 9, 15, 9);
  final draftIssueDate = DateTime(2026, 9, 20, 10);

  return WarehouseAppData(
    users: const [
      AppUser(
        id: 1,
        username: 'admin',
        password: 'admin123',
        fullName: 'Quản trị viên',
        role: UserRole.admin,
      ),
      AppUser(
        id: 2,
        username: 'user_hcm',
        password: '123456',
        fullName: 'Nhân viên Hồ Chí Minh',
        role: UserRole.user,
      ),
      AppUser(
        id: 3,
        username: 'user_hn',
        password: '123456',
        fullName: 'Nhân viên Hà Nội',
        role: UserRole.user,
      ),
    ],
    warehouses: const [
      Warehouse(id: 1, name: 'Kho Hồ Chí Minh', note: 'Kho phía Nam'),
      Warehouse(id: 2, name: 'Kho Hà Nội', note: 'Kho phía Bắc'),
    ],
    units: const [
      UnitOfMeasure(id: 1, name: 'Cái'),
      UnitOfMeasure(id: 2, name: 'Thùng'),
      UnitOfMeasure(id: 3, name: 'Kg'),
    ],
    categories: const [
      ProductCategory(id: 1, code: 'LSP01', name: 'Điện tử'),
      ProductCategory(id: 2, code: 'LSP02', name: 'Thực phẩm'),
      ProductCategory(id: 3, code: 'LSP03', name: 'Gia dụng'),
    ],
    products: const [
      Product(
        id: 1,
        code: 'SP001',
        name: 'Tai nghe Bluetooth',
        categoryId: 1,
        unitId: 1,
      ),
      Product(
        id: 2,
        code: 'SP002',
        name: 'Nước suối 500ml',
        categoryId: 2,
        unitId: 2,
      ),
      Product(
        id: 3,
        code: 'SP003',
        name: 'Ấm siêu tốc',
        categoryId: 3,
        unitId: 1,
      ),
      Product(id: 4, code: 'SP004', name: 'Gạo thơm', categoryId: 2, unitId: 3),
      Product(
        id: 5,
        code: 'SP005',
        name: 'Chuột không dây',
        categoryId: 1,
        unitId: 1,
      ),
      Product(
        id: 6,
        code: 'SP006',
        name: 'Nồi cơm điện',
        categoryId: 3,
        unitId: 1,
      ),
    ],
    suppliers: const [
      Supplier(id: 1, code: 'NCC01', name: 'Công ty Ánh Dương'),
      Supplier(id: 2, code: 'NCC02', name: 'Nhà phân phối Minh Long'),
      Supplier(id: 3, code: 'NCC03', name: 'Thực phẩm An Tâm'),
    ],
    assignments: const [
      WarehouseUserAssignment(id: 1, userId: 2, warehouseId: 1),
      WarehouseUserAssignment(id: 2, userId: 3, warehouseId: 2),
    ],
    receipts: [
      ReceiptDocument(
        id: 1,
        documentNo: 'PN-2026-0001',
        warehouseId: 1,
        supplierId: 1,
        documentDate: receiptDate,
        status: DocumentStatus.posted,
        postedAt: receiptDate,
        note: 'Phiếu nhập demo đã Post',
        createdAt: receiptDate,
        createdBy: 'admin',
      ),
    ],
    receiptDetails: const [
      ReceiptDetail(
        id: 1,
        receiptId: 1,
        productId: 1,
        quantity: 100,
        unitPrice: 250000,
      ),
      ReceiptDetail(
        id: 2,
        receiptId: 1,
        productId: 2,
        quantity: 50,
        unitPrice: 60000,
      ),
      ReceiptDetail(
        id: 3,
        receiptId: 1,
        productId: 3,
        quantity: 12,
        unitPrice: 400000,
      ),
    ],
    issues: [
      IssueDocument(
        id: 1,
        documentNo: 'PX-2026-0001',
        warehouseId: 1,
        documentDate: postedIssueDate,
        status: DocumentStatus.posted,
        postedAt: postedIssueDate,
        note: 'Phiếu xuất demo đã Post',
        createdAt: postedIssueDate,
        createdBy: 'user_hcm',
      ),
      IssueDocument(
        id: 2,
        documentNo: 'PX-2026-0002',
        warehouseId: 1,
        documentDate: draftIssueDate,
        status: DocumentStatus.draft,
        note: 'Phiếu xuất demo đang giữ hàng',
        createdAt: draftIssueDate,
        createdBy: 'user_hcm',
      ),
    ],
    issueDetails: const [
      IssueDetail(
        id: 1,
        issueId: 1,
        productId: 1,
        quantity: 20,
        unitPrice: 300000,
      ),
      IssueDetail(
        id: 2,
        issueId: 2,
        productId: 1,
        quantity: 15,
        unitPrice: 300000,
      ),
    ],
    nextId: 100,
  );
}
