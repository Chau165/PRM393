import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/local/local_data_store.dart';
import '../../data/local/seed_data.dart';
import '../models/warehouse_app_data.dart';
import 'auth_service.dart';
import 'domain_exception.dart';
import 'warehouse_inventory_service.dart';
import 'warehouse_permission_service.dart';

class WarehouseAppState extends ChangeNotifier {
  WarehouseAppState._({required this.store, required this.data});

  final LocalDataStore store;
  final AuthService _auth = const AuthService();
  final WarehousePermissionService _permissions =
      const WarehousePermissionService();
  final WarehouseInventoryService _inventory =
      const WarehouseInventoryService();

  WarehouseAppData data;
  AppUser? currentUser;

  static Future<WarehouseAppState> create({
    required LocalDataStore store,
  }) async {
    final saved = await store.loadJson();
    if (saved == null || saved.trim().isEmpty) {
      final seeded = createDemoData();
      await store.saveJson(jsonEncode(seeded.toJson()));
      return WarehouseAppState._(store: store, data: seeded);
    }
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Warehouse data must be a JSON object.');
      }
      return WarehouseAppState._(
        store: store,
        data: WarehouseAppData.fromJson(decoded),
      );
    } on FormatException catch (error) {
      throw DomainException(
        'Dữ liệu lưu cục bộ không hợp lệ: ${error.message}',
      );
    }
  }

  Future<bool> login(String username, String password) async {
    final user = _auth.authenticate(data.users, username, password);
    if (user == null) return false;
    currentUser = user;
    notifyListeners();
    return true;
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  bool canAccessWarehouse(AppUser user, int warehouseId) {
    try {
      final verified = _verifiedUser(user);
      return _permissions.canAccessWarehouse(
        verified,
        warehouseId,
        data.assignments,
      );
    } on DomainException {
      return false;
    }
  }

  List<Warehouse> getAllowedWarehouses(AppUser user) {
    final verified = _verifiedUser(user);
    return _permissions.allowedWarehouses(
      verified,
      data.warehouses,
      data.assignments,
    );
  }

  List<InventoryItem> currentInventory(
    AppUser user, {
    int? warehouseId,
    String search = '',
  }) {
    final allowed = getAllowedWarehouses(user);
    if (warehouseId != null) _requireWarehouseAccess(user, warehouseId);
    return _inventory.currentInventory(
      data: data,
      warehouses: allowed,
      warehouseId: warehouseId,
      search: search,
    );
  }

  List<InventoryPeriodReport> periodInventoryReport(
    AppUser user, {
    required DateTime fromDate,
    required DateTime toDate,
    int? warehouseId,
    String search = '',
  }) {
    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final to = DateTime(toDate.year, toDate.month, toDate.day);
    if (from.isAfter(to)) {
      throw const DomainException(
        'Ngày bắt đầu phải nhỏ hơn hoặc bằng ngày kết thúc.',
      );
    }
    final allowed = getAllowedWarehouses(user);
    if (warehouseId != null) _requireWarehouseAccess(user, warehouseId);
    return _inventory.periodReport(
      data: data,
      warehouses: allowed,
      fromDate: from,
      toDate: to,
      search: search,
    );
  }

  List<ReceiptDocument> visibleReceipts(AppUser user, {int? warehouseId}) {
    if (warehouseId != null) _requireWarehouseAccess(user, warehouseId);
    final allowedIds = getAllowedWarehouses(user)
        .map((item) => item.id)
        .toSet();
    return data.receipts
        .where(
          (document) =>
              allowedIds.contains(document.warehouseId) &&
              (warehouseId == null || document.warehouseId == warehouseId),
        )
        .toList();
  }

  List<IssueDocument> visibleIssues(AppUser user, {int? warehouseId}) {
    if (warehouseId != null) _requireWarehouseAccess(user, warehouseId);
    final allowedIds = getAllowedWarehouses(user)
        .map((item) => item.id)
        .toSet();
    return data.issues
        .where(
          (document) =>
              allowedIds.contains(document.warehouseId) &&
              (warehouseId == null || document.warehouseId == warehouseId),
        )
        .toList();
  }

  ReceiptDocument receiptById(AppUser user, int id) {
    final document = _findById(data.receipts, id, 'Không tìm thấy phiếu nhập.');
    _requireWarehouseAccess(user, document.warehouseId);
    return document;
  }

  IssueDocument issueById(AppUser user, int id) {
    final document = _findById(data.issues, id, 'Không tìm thấy phiếu xuất.');
    _requireWarehouseAccess(user, document.warehouseId);
    return document;
  }

  List<ReceiptDetail> receiptDetailsFor(AppUser user, int receiptId) {
    receiptById(user, receiptId);
    return data.receiptDetails
        .where((line) => line.receiptId == receiptId)
        .toList();
  }

  List<IssueDetail> issueDetailsFor(AppUser user, int issueId) {
    issueById(user, issueId);
    return data.issueDetails.where((line) => line.issueId == issueId).toList();
  }

  Future<Warehouse> createWarehouse(
    AppUser actor, {
    required String name,
    String note = '',
  }) async {
    _requireAdmin(actor);
    _requireName(name, 'Tên kho');
    _ensureUniqueName(data.warehouses.map((item) => item.name), name, 'Kho');
    late Warehouse created;
    await _persist(() {
      created = Warehouse(
        id: data.allocateId(),
        name: name.trim(),
        note: note.trim(),
      );
      data.warehouses.add(created);
    });
    return created;
  }

  Future<void> updateWarehouse(
    AppUser actor, {
    required int id,
    required String name,
    String note = '',
  }) async {
    _requireAdmin(actor);
    final index = _indexById(data.warehouses, id, 'Không tìm thấy kho.');
    _requireName(name, 'Tên kho');
    _ensureUniqueName(
      data.warehouses.where((item) => item.id != id).map((item) => item.name),
      name,
      'Kho',
    );
    await _persist(() {
      data.warehouses[index] = Warehouse(
        id: id,
        name: name.trim(),
        note: note.trim(),
      );
    });
  }

  Future<void> deleteWarehouse(AppUser actor, int id) async {
    _requireAdmin(actor);
    _indexById(data.warehouses, id, 'Không tìm thấy kho.');
    final usedByDocument =
        data.receipts.any((doc) => doc.warehouseId == id) ||
        data.issues.any((doc) => doc.warehouseId == id);
    final usedByAssignment = data.assignments.any(
      (item) => item.warehouseId == id,
    );
    if (usedByDocument || usedByAssignment) {
      throw const DomainException(
        'Không thể xóa kho đang được phiếu hoặc phân quyền sử dụng.',
      );
    }
    await _persist(() => data.warehouses.removeWhere((item) => item.id == id));
  }

  Future<UnitOfMeasure> createUnit(
    AppUser actor, {
    required String name,
    String note = '',
  }) async {
    _requireAdmin(actor);
    _requireName(name, 'Tên đơn vị tính');
    late UnitOfMeasure created;
    await _persist(() {
      created = UnitOfMeasure(
        id: data.allocateId(),
        name: name.trim(),
        note: note.trim(),
      );
      data.units.add(created);
    });
    return created;
  }

  Future<void> updateUnit(
    AppUser actor, {
    required int id,
    required String name,
    String note = '',
  }) async {
    _requireAdmin(actor);
    final index = _indexById(data.units, id, 'Không tìm thấy đơn vị tính.');
    _requireName(name, 'Tên đơn vị tính');
    await _persist(
      () => data.units[index] = UnitOfMeasure(
        id: id,
        name: name.trim(),
        note: note.trim(),
      ),
    );
  }

  Future<void> deleteUnit(AppUser actor, int id) async {
    _requireAdmin(actor);
    _indexById(data.units, id, 'Không tìm thấy đơn vị tính.');
    if (data.products.any((product) => product.unitId == id)) {
      throw const DomainException(
        'Không thể xóa đơn vị tính đang được sản phẩm sử dụng.',
      );
    }
    await _persist(() => data.units.removeWhere((item) => item.id == id));
  }

  Future<ProductCategory> createCategory(
    AppUser actor, {
    required String code,
    required String name,
    String note = '',
  }) async {
    _requireAdmin(actor);
    _validateCodeAndName(code, name, 'Mã loại sản phẩm', 'Tên loại sản phẩm');
    _ensureUniqueCode(
      data.categories.map((item) => item.code),
      code,
      'Mã loại sản phẩm',
    );
    late ProductCategory created;
    await _persist(() {
      created = ProductCategory(
        id: data.allocateId(),
        code: code.trim(),
        name: name.trim(),
        note: note.trim(),
      );
      data.categories.add(created);
    });
    return created;
  }

  Future<void> updateCategory(
    AppUser actor, {
    required int id,
    required String code,
    required String name,
    String note = '',
  }) async {
    _requireAdmin(actor);
    final index = _indexById(
      data.categories,
      id,
      'Không tìm thấy loại sản phẩm.',
    );
    _validateCodeAndName(code, name, 'Mã loại sản phẩm', 'Tên loại sản phẩm');
    _ensureUniqueCode(
      data.categories.where((item) => item.id != id).map((item) => item.code),
      code,
      'Mã loại sản phẩm',
    );
    await _persist(() {
      data.categories[index] = ProductCategory(
        id: id,
        code: code.trim(),
        name: name.trim(),
        note: note.trim(),
      );
    });
  }

  Future<void> deleteCategory(AppUser actor, int id) async {
    _requireAdmin(actor);
    _indexById(data.categories, id, 'Không tìm thấy loại sản phẩm.');
    if (data.products.any((product) => product.categoryId == id)) {
      throw const DomainException(
        'Không thể xóa loại sản phẩm đang được sản phẩm sử dụng.',
      );
    }
    await _persist(() => data.categories.removeWhere((item) => item.id == id));
  }

  Future<Product> createProduct(
    AppUser actor, {
    required String code,
    required String name,
    required int categoryId,
    required int unitId,
    String note = '',
  }) async {
    _requireAdmin(actor);
    _validateProduct(code, name, categoryId, unitId);
    _ensureUniqueCode(
      data.products.map((item) => item.code),
      code,
      'Mã sản phẩm',
    );
    late Product created;
    await _persist(() {
      created = Product(
        id: data.allocateId(),
        code: code.trim(),
        name: name.trim(),
        categoryId: categoryId,
        unitId: unitId,
        note: note.trim(),
      );
      data.products.add(created);
    });
    return created;
  }

  Future<void> updateProduct(
    AppUser actor, {
    required int id,
    required String code,
    required String name,
    required int categoryId,
    required int unitId,
    String note = '',
  }) async {
    _requireAdmin(actor);
    final index = _indexById(data.products, id, 'Không tìm thấy sản phẩm.');
    _validateProduct(code, name, categoryId, unitId);
    _ensureUniqueCode(
      data.products.where((item) => item.id != id).map((item) => item.code),
      code,
      'Mã sản phẩm',
    );
    await _persist(() {
      data.products[index] = Product(
        id: id,
        code: code.trim(),
        name: name.trim(),
        categoryId: categoryId,
        unitId: unitId,
        note: note.trim(),
      );
    });
  }

  Future<void> deleteProduct(AppUser actor, int id) async {
    _requireAdmin(actor);
    _indexById(data.products, id, 'Không tìm thấy sản phẩm.');
    final usedInReceipt = data.receiptDetails.any(
      (line) => line.productId == id,
    );
    final usedInIssue = data.issueDetails.any((line) => line.productId == id);
    if (usedInReceipt || usedInIssue) {
      throw const DomainException(
        'Không thể xóa sản phẩm đã được sử dụng trong phiếu kho.',
      );
    }
    await _persist(() => data.products.removeWhere((item) => item.id == id));
  }

  Future<Supplier> createSupplier(
    AppUser actor, {
    required String code,
    required String name,
    String note = '',
  }) async {
    _requireAdmin(actor);
    _validateCodeAndName(code, name, 'Mã nhà cung cấp', 'Tên nhà cung cấp');
    _ensureUniqueCode(
      data.suppliers.map((item) => item.code),
      code,
      'Mã nhà cung cấp',
    );
    late Supplier created;
    await _persist(() {
      created = Supplier(
        id: data.allocateId(),
        code: code.trim(),
        name: name.trim(),
        note: note.trim(),
      );
      data.suppliers.add(created);
    });
    return created;
  }

  Future<void> updateSupplier(
    AppUser actor, {
    required int id,
    required String code,
    required String name,
    String note = '',
  }) async {
    _requireAdmin(actor);
    final index = _indexById(
      data.suppliers,
      id,
      'Không tìm thấy nhà cung cấp.',
    );
    _validateCodeAndName(code, name, 'Mã nhà cung cấp', 'Tên nhà cung cấp');
    _ensureUniqueCode(
      data.suppliers.where((item) => item.id != id).map((item) => item.code),
      code,
      'Mã nhà cung cấp',
    );
    await _persist(() {
      data.suppliers[index] = Supplier(
        id: id,
        code: code.trim(),
        name: name.trim(),
        note: note.trim(),
      );
    });
  }

  Future<void> deleteSupplier(AppUser actor, int id) async {
    _requireAdmin(actor);
    _indexById(data.suppliers, id, 'Không tìm thấy nhà cung cấp.');
    if (data.receipts.any((document) => document.supplierId == id)) {
      throw const DomainException(
        'Không thể xóa nhà cung cấp đang được phiếu nhập sử dụng.',
      );
    }
    await _persist(() => data.suppliers.removeWhere((item) => item.id == id));
  }

  Future<WarehouseUserAssignment> createWarehouseAssignment(
    AppUser actor, {
    required int userId,
    required int warehouseId,
  }) async {
    _requireAdmin(actor);
    _validateAssignment(userId, warehouseId);
    if (data.assignments.any(
      (item) => item.userId == userId && item.warehouseId == warehouseId,
    )) {
      throw const DomainException('Người dùng đã được phân quyền vào kho này.');
    }
    late WarehouseUserAssignment created;
    await _persist(() {
      created = WarehouseUserAssignment(
        id: data.allocateId(),
        userId: userId,
        warehouseId: warehouseId,
      );
      data.assignments.add(created);
    });
    return created;
  }

  Future<void> updateWarehouseAssignment(
    AppUser actor, {
    required int id,
    required int userId,
    required int warehouseId,
  }) async {
    _requireAdmin(actor);
    final index = _indexById(
      data.assignments,
      id,
      'Không tìm thấy phân quyền.',
    );
    _validateAssignment(userId, warehouseId);
    if (data.assignments.any(
      (item) =>
          item.id != id &&
          item.userId == userId &&
          item.warehouseId == warehouseId,
    )) {
      throw const DomainException('Người dùng đã được phân quyền vào kho này.');
    }
    await _persist(() {
      data.assignments[index] = WarehouseUserAssignment(
        id: id,
        userId: userId,
        warehouseId: warehouseId,
      );
    });
  }

  Future<void> deleteWarehouseAssignment(AppUser actor, int id) async {
    _requireAdmin(actor);
    _indexById(data.assignments, id, 'Không tìm thấy phân quyền.');
    await _persist(() => data.assignments.removeWhere((item) => item.id == id));
  }

  Future<ReceiptDocument> saveReceipt(
    AppUser actor,
    ReceiptDocument draft,
    List<ReceiptDetail> details,
  ) async {
    _validateDocumentNo(draft.documentNo);
    _requireWarehouseAccess(actor, draft.warehouseId);
    if (!data.suppliers.any((item) => item.id == draft.supplierId)) {
      throw const DomainException('Vui lòng chọn nhà cung cấp hợp lệ.');
    }
    final existingIndex = draft.id == 0
        ? -1
        : _indexById(data.receipts, draft.id, 'Không tìm thấy phiếu nhập.');
    final existing = existingIndex < 0 ? null : data.receipts[existingIndex];
    if (existing != null) {
      _requireWarehouseAccess(actor, existing.warehouseId);
      _requireDraft(existing.status);
    }
    _ensureUniqueDocumentNo(
      data.receipts.map((item) => item),
      draft.documentNo,
      draft.id,
      'Số phiếu nhập',
    );
    _validateReceiptDetails(details);

    late ReceiptDocument saved;
    await _persist(() {
      final id = existing?.id ?? data.allocateId();
      saved = draft.copyWith(
        id: id,
        status: DocumentStatus.draft,
        clearPostedAt: true,
        createdAt: existing?.createdAt ?? draft.createdAt,
        createdBy: existing?.createdBy ?? actor.username,
      );
      final savedDetails = details
          .map(
            (line) => ReceiptDetail(
              id: line.id == 0 ? data.allocateId() : line.id,
              receiptId: id,
              productId: line.productId,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
            ),
          )
          .toList();
      if (existingIndex >= 0) {
        data.receipts[existingIndex] = saved;
      } else {
        data.receipts.add(saved);
      }
      data.receiptDetails.removeWhere((line) => line.receiptId == id);
      data.receiptDetails.addAll(savedDetails);
    });
    return saved;
  }

  Future<void> postReceipt(AppUser actor, int id) async {
    final index = _indexById(data.receipts, id, 'Không tìm thấy phiếu nhập.');
    final document = data.receipts[index];
    _requireWarehouseAccess(actor, document.warehouseId);
    _requireDraft(document.status);
    final lines = data.receiptDetails
        .where((line) => line.receiptId == id)
        .toList();
    if (lines.isEmpty) {
      throw const DomainException(
        'Phiếu nhập phải có ít nhất một chi tiết trước khi Post.',
      );
    }
    _validateReceiptDetails(lines);
    await _persist(() {
      data.receipts[index] = document.copyWith(
        status: DocumentStatus.posted,
        postedAt: DateTime.now(),
      );
    });
  }

  Future<void> deleteReceipt(AppUser actor, int id) async {
    final document = _findById(data.receipts, id, 'Không tìm thấy phiếu nhập.');
    _requireWarehouseAccess(actor, document.warehouseId);
    _requireDraft(document.status);
    await _persist(() {
      data.receipts.removeWhere((item) => item.id == id);
      data.receiptDetails.removeWhere((item) => item.receiptId == id);
    });
  }

  Future<IssueDocument> saveIssue(
    AppUser actor,
    IssueDocument draft,
    List<IssueDetail> details,
  ) async {
    _validateDocumentNo(draft.documentNo);
    _requireWarehouseAccess(actor, draft.warehouseId);
    final existingIndex = draft.id == 0
        ? -1
        : _indexById(data.issues, draft.id, 'Không tìm thấy phiếu xuất.');
    final existing = existingIndex < 0 ? null : data.issues[existingIndex];
    if (existing != null) {
      _requireWarehouseAccess(actor, existing.warehouseId);
      _requireDraft(existing.status);
    }
    _ensureUniqueDocumentNo(
      data.issues,
      draft.documentNo,
      draft.id,
      'Số phiếu xuất',
    );
    _validateIssueDetails(details);
    _validateIssueAvailability(
      draft.warehouseId,
      details,
      excludingIssueId: draft.id == 0 ? null : draft.id,
    );

    late IssueDocument saved;
    await _persist(() {
      final id = existing?.id ?? data.allocateId();
      saved = draft.copyWith(
        id: id,
        status: DocumentStatus.draft,
        clearPostedAt: true,
        createdAt: existing?.createdAt ?? draft.createdAt,
        createdBy: existing?.createdBy ?? actor.username,
      );
      final savedDetails = details
          .map(
            (line) => IssueDetail(
              id: line.id == 0 ? data.allocateId() : line.id,
              issueId: id,
              productId: line.productId,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
            ),
          )
          .toList();
      if (existingIndex >= 0) {
        data.issues[existingIndex] = saved;
      } else {
        data.issues.add(saved);
      }
      data.issueDetails.removeWhere((line) => line.issueId == id);
      data.issueDetails.addAll(savedDetails);
    });
    return saved;
  }

  Future<void> postIssue(AppUser actor, int id) async {
    final index = _indexById(data.issues, id, 'Không tìm thấy phiếu xuất.');
    final document = data.issues[index];
    _requireWarehouseAccess(actor, document.warehouseId);
    _requireDraft(document.status);
    final details = data.issueDetails
        .where((line) => line.issueId == id)
        .toList();
    if (details.isEmpty) {
      throw const DomainException(
        'Phiếu xuất phải có ít nhất một chi tiết trước khi Post.',
      );
    }
    _validateIssueDetails(details);
    _validateIssueAvailability(
      document.warehouseId,
      details,
      excludingIssueId: id,
    );
    await _persist(() {
      data.issues[index] = document.copyWith(
        status: DocumentStatus.posted,
        postedAt: DateTime.now(),
      );
    });
  }

  Future<void> deleteIssue(AppUser actor, int id) async {
    final document = _findById(data.issues, id, 'Không tìm thấy phiếu xuất.');
    _requireWarehouseAccess(actor, document.warehouseId);
    _requireDraft(document.status);
    await _persist(() {
      data.issues.removeWhere((item) => item.id == id);
      data.issueDetails.removeWhere((item) => item.issueId == id);
    });
  }

  Future<void> resetDemoData(AppUser actor) async {
    _requireAdmin(actor);
    final previous = data;
    data = createDemoData();
    try {
      await store.saveJson(jsonEncode(data.toJson()));
      currentUser = data.users.firstWhere(
        (item) => item.username == actor.username,
      );
      notifyListeners();
    } catch (_) {
      data = previous;
      rethrow;
    }
  }

  Future<void> _persist(void Function() update) async {
    final before = jsonEncode(data.toJson());
    update();
    try {
      await store.saveJson(jsonEncode(data.toJson()));
    } catch (_) {
      data = WarehouseAppData.fromJson(
        jsonDecode(before) as Map<String, dynamic>,
      );
      rethrow;
    }
    notifyListeners();
  }

  void _validateProduct(String code, String name, int categoryId, int unitId) {
    _validateCodeAndName(code, name, 'Mã sản phẩm', 'Tên sản phẩm');
    if (!data.categories.any((item) => item.id == categoryId)) {
      throw const DomainException('Vui lòng chọn loại sản phẩm hợp lệ.');
    }
    if (!data.units.any((item) => item.id == unitId)) {
      throw const DomainException('Vui lòng chọn đơn vị tính hợp lệ.');
    }
  }

  void _validateAssignment(int userId, int warehouseId) {
    if (!data.users.any((item) => item.id == userId)) {
      throw const DomainException('Vui lòng chọn người dùng hợp lệ.');
    }
    if (!data.warehouses.any((item) => item.id == warehouseId)) {
      throw const DomainException('Vui lòng chọn kho hợp lệ.');
    }
  }

  void _validateReceiptDetails(List<ReceiptDetail> details) {
    for (final line in details) {
      if (!data.products.any((product) => product.id == line.productId)) {
        throw const DomainException(
          'Vui lòng chọn sản phẩm hợp lệ trong chi tiết phiếu nhập.',
        );
      }
      if (!line.quantity.isFinite || line.quantity <= 0) {
        throw const DomainException('Số lượng nhập phải lớn hơn 0.');
      }
      if (!line.unitPrice.isFinite || line.unitPrice < 0) {
        throw const DomainException('Đơn giá nhập không được nhỏ hơn 0.');
      }
    }
  }

  void _validateIssueDetails(List<IssueDetail> details) {
    for (final line in details) {
      if (!data.products.any((product) => product.id == line.productId)) {
        throw const DomainException(
          'Vui lòng chọn sản phẩm hợp lệ trong chi tiết phiếu xuất.',
        );
      }
      if (!line.quantity.isFinite || line.quantity <= 0) {
        throw const DomainException('Số lượng xuất phải lớn hơn 0.');
      }
      if (!line.unitPrice.isFinite || line.unitPrice < 0) {
        throw const DomainException('Đơn giá xuất không được nhỏ hơn 0.');
      }
    }
  }

  void _validateIssueAvailability(
    int warehouseId,
    List<IssueDetail> details, {
    required int? excludingIssueId,
  }) {
    final totals = <int, double>{};
    for (final line in details) {
      totals.update(
        line.productId,
        (quantity) => quantity + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }
    for (final entry in totals.entries) {
      final onHand = _inventory.onHandFor(data, warehouseId, entry.key);
      final otherReservations = _inventory.reservedFor(
        data,
        warehouseId,
        entry.key,
        excludingIssueId: excludingIssueId,
      );
      final available = (onHand - otherReservations)
          .clamp(0, double.infinity)
          .toDouble();
      if (entry.value > available) {
        throw DomainException(
          'Số lượng khả dụng không đủ. Khả dụng hiện tại: ${_formatQuantity(available)}.',
        );
      }
    }
  }

  void _validateCodeAndName(
    String code,
    String name,
    String codeLabel,
    String nameLabel,
  ) {
    _requireName(code, codeLabel);
    _requireName(name, nameLabel);
  }

  void _validateDocumentNo(String documentNo) {
    _requireName(documentNo, 'Số phiếu');
  }

  void _requireWarehouseAccess(AppUser actor, int warehouseId) {
    final verified = _verifiedUser(actor);
    if (!data.warehouses.any((item) => item.id == warehouseId)) {
      throw const DomainException('Vui lòng chọn kho hợp lệ.');
    }
    _permissions.requireAccess(verified, warehouseId, data.assignments);
  }

  void _requireAdmin(AppUser actor) =>
      _permissions.requireAdmin(_verifiedUser(actor));

  AppUser _verifiedUser(AppUser actor) {
    for (final user in data.users) {
      if (user.id == actor.id &&
          user.username.toLowerCase() == actor.username.toLowerCase() &&
          user.role == actor.role) {
        return user;
      }
    }
    throw const DomainException(
      'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
    );
  }

  void _requireDraft(DocumentStatus status) {
    if (status != DocumentStatus.draft) {
      throw const DomainException(
        'Phiếu đã Post nên không thể chỉnh sửa hoặc xóa.',
      );
    }
  }

  static void _requireName(String value, String label) {
    if (value.trim().isEmpty) {
      throw DomainException('$label không được để trống.');
    }
  }

  static void _ensureUniqueName(
    Iterable<String> names,
    String value,
    String label,
  ) {
    if (names.any(
      (name) => name.trim().toLowerCase() == value.trim().toLowerCase(),
    )) {
      throw DomainException('$label đã tồn tại.');
    }
  }

  static void _ensureUniqueCode(
    Iterable<String> codes,
    String value,
    String label,
  ) {
    if (codes.any(
      (code) => code.trim().toLowerCase() == value.trim().toLowerCase(),
    )) {
      throw DomainException('$label đã tồn tại.');
    }
  }

  static void _ensureUniqueDocumentNo<T>(
    Iterable<T> documents,
    String value,
    int currentId,
    String label,
  ) {
    for (final document in documents) {
      final (id, documentNo) = switch (document) {
        ReceiptDocument doc => (doc.id, doc.documentNo),
        IssueDocument doc => (doc.id, doc.documentNo),
        _ => (0, ''),
      };
      if (id != currentId &&
          documentNo.trim().toLowerCase() == value.trim().toLowerCase()) {
        throw DomainException('$label đã tồn tại.');
      }
    }
  }

  static int _indexById<T>(List<T> records, int id, String notFoundMessage) {
    final index = records.indexWhere(
      (item) => switch (item) {
        Warehouse value => value.id == id,
        UnitOfMeasure value => value.id == id,
        ProductCategory value => value.id == id,
        Product value => value.id == id,
        Supplier value => value.id == id,
        WarehouseUserAssignment value => value.id == id,
        ReceiptDocument value => value.id == id,
        IssueDocument value => value.id == id,
        _ => false,
      },
    );
    if (index < 0) throw DomainException(notFoundMessage);
    return index;
  }

  static T _findById<T>(List<T> records, int id, String notFoundMessage) =>
      records[_indexById(records, id, notFoundMessage)];

  static String _formatQuantity(double value) =>
      value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();
}
