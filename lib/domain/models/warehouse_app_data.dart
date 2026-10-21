enum UserRole { admin, user }

enum DocumentStatus { draft, posted }

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.role,
  });

  final int id;
  final String username;
  final String password;
  final String fullName;
  final UserRole role;

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'password': password,
    'fullName': fullName,
    'role': role.name,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: _asInt(json['id']),
    username: _asString(json['username']),
    password: _asString(json['password']),
    fullName: _asString(json['fullName']),
    role: UserRole.values.firstWhere(
      (role) => role.name == json['role'],
      orElse: () => UserRole.user,
    ),
  );
}

class Warehouse {
  const Warehouse({required this.id, required this.name, this.note = ''});

  final int id;
  final String name;
  final String note;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'note': note};

  factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
    id: _asInt(json['id']),
    name: _asString(json['name']),
    note: _asString(json['note']),
  );
}

class UnitOfMeasure {
  const UnitOfMeasure({required this.id, required this.name, this.note = ''});

  final int id;
  final String name;
  final String note;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'note': note};

  factory UnitOfMeasure.fromJson(Map<String, dynamic> json) => UnitOfMeasure(
    id: _asInt(json['id']),
    name: _asString(json['name']),
    note: _asString(json['note']),
  );
}

class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.code,
    required this.name,
    this.note = '',
  });

  final int id;
  final String code;
  final String name;
  final String note;

  Map<String, Object?> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'note': note,
  };

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(
        id: _asInt(json['id']),
        code: _asString(json['code']),
        name: _asString(json['name']),
        note: _asString(json['note']),
      );
}

class Product {
  const Product({
    required this.id,
    required this.code,
    required this.name,
    required this.categoryId,
    required this.unitId,
    this.note = '',
  });

  final int id;
  final String code;
  final String name;
  final int categoryId;
  final int unitId;
  final String note;

  Map<String, Object?> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'categoryId': categoryId,
    'unitId': unitId,
    'note': note,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: _asInt(json['id']),
    code: _asString(json['code']),
    name: _asString(json['name']),
    categoryId: _asInt(json['categoryId']),
    unitId: _asInt(json['unitId']),
    note: _asString(json['note']),
  );
}

class Supplier {
  const Supplier({
    required this.id,
    required this.code,
    required this.name,
    this.note = '',
  });

  final int id;
  final String code;
  final String name;
  final String note;

  Map<String, Object?> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'note': note,
  };

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: _asInt(json['id']),
    code: _asString(json['code']),
    name: _asString(json['name']),
    note: _asString(json['note']),
  );
}

class WarehouseUserAssignment {
  const WarehouseUserAssignment({
    required this.id,
    required this.userId,
    required this.warehouseId,
  });

  final int id;
  final int userId;
  final int warehouseId;

  Map<String, Object?> toJson() => {
    'id': id,
    'userId': userId,
    'warehouseId': warehouseId,
  };

  factory WarehouseUserAssignment.fromJson(Map<String, dynamic> json) =>
      WarehouseUserAssignment(
        id: _asInt(json['id']),
        userId: _asInt(json['userId']),
        warehouseId: _asInt(json['warehouseId']),
      );
}

class ReceiptDocument {
  ReceiptDocument({
    required this.id,
    required this.documentNo,
    required this.warehouseId,
    required this.supplierId,
    required this.documentDate,
    this.status = DocumentStatus.draft,
    this.postedAt,
    this.note = '',
    DateTime? createdAt,
    this.createdBy = '',
  }) : createdAt = createdAt ?? DateTime.now();

  final int id;
  final String documentNo;
  final int warehouseId;
  final int supplierId;
  final DateTime documentDate;
  final DocumentStatus status;
  final DateTime? postedAt;
  final String note;
  final DateTime createdAt;
  final String createdBy;

  ReceiptDocument copyWith({
    int? id,
    String? documentNo,
    int? warehouseId,
    int? supplierId,
    DateTime? documentDate,
    DocumentStatus? status,
    DateTime? postedAt,
    bool clearPostedAt = false,
    String? note,
    DateTime? createdAt,
    String? createdBy,
  }) => ReceiptDocument(
    id: id ?? this.id,
    documentNo: documentNo ?? this.documentNo,
    warehouseId: warehouseId ?? this.warehouseId,
    supplierId: supplierId ?? this.supplierId,
    documentDate: documentDate ?? this.documentDate,
    status: status ?? this.status,
    postedAt: clearPostedAt ? null : postedAt ?? this.postedAt,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    createdBy: createdBy ?? this.createdBy,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'documentNo': documentNo,
    'warehouseId': warehouseId,
    'supplierId': supplierId,
    'documentDate': documentDate.toIso8601String(),
    'status': status.name,
    'postedAt': postedAt?.toIso8601String(),
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
  };

  factory ReceiptDocument.fromJson(Map<String, dynamic> json) =>
      ReceiptDocument(
        id: _asInt(json['id']),
        documentNo: _asString(json['documentNo']),
        warehouseId: _asInt(json['warehouseId']),
        supplierId: _asInt(json['supplierId']),
        documentDate: _asDate(json['documentDate']),
        status: _documentStatus(json['status']),
        postedAt: json['postedAt'] == null ? null : _asDate(json['postedAt']),
        note: _asString(json['note']),
        createdAt: _asDate(json['createdAt']),
        createdBy: _asString(json['createdBy']),
      );
}

class ReceiptDetail {
  const ReceiptDetail({
    required this.id,
    required this.receiptId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  final int id;
  final int receiptId;
  final int productId;
  final double quantity;
  final double unitPrice;

  Map<String, Object?> toJson() => {
    'id': id,
    'receiptId': receiptId,
    'productId': productId,
    'quantity': quantity,
    'unitPrice': unitPrice,
  };

  factory ReceiptDetail.fromJson(Map<String, dynamic> json) => ReceiptDetail(
    id: _asInt(json['id']),
    receiptId: _asInt(json['receiptId']),
    productId: _asInt(json['productId']),
    quantity: _asDouble(json['quantity']),
    unitPrice: _asDouble(json['unitPrice']),
  );
}

class IssueDocument {
  IssueDocument({
    required this.id,
    required this.documentNo,
    required this.warehouseId,
    required this.documentDate,
    this.status = DocumentStatus.draft,
    this.postedAt,
    this.note = '',
    DateTime? createdAt,
    this.createdBy = '',
  }) : createdAt = createdAt ?? DateTime.now();

  final int id;
  final String documentNo;
  final int warehouseId;
  final DateTime documentDate;
  final DocumentStatus status;
  final DateTime? postedAt;
  final String note;
  final DateTime createdAt;
  final String createdBy;

  IssueDocument copyWith({
    int? id,
    String? documentNo,
    int? warehouseId,
    DateTime? documentDate,
    DocumentStatus? status,
    DateTime? postedAt,
    bool clearPostedAt = false,
    String? note,
    DateTime? createdAt,
    String? createdBy,
  }) => IssueDocument(
    id: id ?? this.id,
    documentNo: documentNo ?? this.documentNo,
    warehouseId: warehouseId ?? this.warehouseId,
    documentDate: documentDate ?? this.documentDate,
    status: status ?? this.status,
    postedAt: clearPostedAt ? null : postedAt ?? this.postedAt,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    createdBy: createdBy ?? this.createdBy,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'documentNo': documentNo,
    'warehouseId': warehouseId,
    'documentDate': documentDate.toIso8601String(),
    'status': status.name,
    'postedAt': postedAt?.toIso8601String(),
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
  };

  factory IssueDocument.fromJson(Map<String, dynamic> json) => IssueDocument(
    id: _asInt(json['id']),
    documentNo: _asString(json['documentNo']),
    warehouseId: _asInt(json['warehouseId']),
    documentDate: _asDate(json['documentDate']),
    status: _documentStatus(json['status']),
    postedAt: json['postedAt'] == null ? null : _asDate(json['postedAt']),
    note: _asString(json['note']),
    createdAt: _asDate(json['createdAt']),
    createdBy: _asString(json['createdBy']),
  );
}

class IssueDetail {
  const IssueDetail({
    required this.id,
    required this.issueId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  final int id;
  final int issueId;
  final int productId;
  final double quantity;
  final double unitPrice;

  Map<String, Object?> toJson() => {
    'id': id,
    'issueId': issueId,
    'productId': productId,
    'quantity': quantity,
    'unitPrice': unitPrice,
  };

  factory IssueDetail.fromJson(Map<String, dynamic> json) => IssueDetail(
    id: _asInt(json['id']),
    issueId: _asInt(json['issueId']),
    productId: _asInt(json['productId']),
    quantity: _asDouble(json['quantity']),
    unitPrice: _asDouble(json['unitPrice']),
  );
}

class InventoryItem {
  const InventoryItem({
    required this.warehouseId,
    required this.warehouseName,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unitName,
    required this.onHand,
    required this.reserved,
    required this.available,
  });

  final int warehouseId;
  final String warehouseName;
  final int productId;
  final String productCode;
  final String productName;
  final String unitName;
  final double onHand;
  final double reserved;
  final double available;
}

class InventoryPeriodReport {
  const InventoryPeriodReport({
    required this.warehouseId,
    required this.warehouseName,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.unitName,
    required this.opening,
    required this.received,
    required this.issued,
    required this.closing,
  });

  final int warehouseId;
  final String warehouseName;
  final int productId;
  final String productCode;
  final String productName;
  final String unitName;
  final double opening;
  final double received;
  final double issued;
  final double closing;
}

class WarehouseAppData {
  WarehouseAppData({
    required List<AppUser> users,
    required List<Warehouse> warehouses,
    required List<UnitOfMeasure> units,
    required List<ProductCategory> categories,
    required List<Product> products,
    required List<Supplier> suppliers,
    required List<WarehouseUserAssignment> assignments,
    required List<ReceiptDocument> receipts,
    required List<ReceiptDetail> receiptDetails,
    required List<IssueDocument> issues,
    required List<IssueDetail> issueDetails,
    required this.nextId,
  }) : users = List.of(users),
       warehouses = List.of(warehouses),
       units = List.of(units),
       categories = List.of(categories),
       products = List.of(products),
       suppliers = List.of(suppliers),
       assignments = List.of(assignments),
       receipts = List.of(receipts),
       receiptDetails = List.of(receiptDetails),
       issues = List.of(issues),
       issueDetails = List.of(issueDetails);

  final List<AppUser> users;
  final List<Warehouse> warehouses;
  final List<UnitOfMeasure> units;
  final List<ProductCategory> categories;
  final List<Product> products;
  final List<Supplier> suppliers;
  final List<WarehouseUserAssignment> assignments;
  final List<ReceiptDocument> receipts;
  final List<ReceiptDetail> receiptDetails;
  final List<IssueDocument> issues;
  final List<IssueDetail> issueDetails;
  int nextId;

  int allocateId() => nextId++;

  Map<String, Object?> toJson() => {
    'users': users.map((item) => item.toJson()).toList(),
    'warehouses': warehouses.map((item) => item.toJson()).toList(),
    'units': units.map((item) => item.toJson()).toList(),
    'categories': categories.map((item) => item.toJson()).toList(),
    'products': products.map((item) => item.toJson()).toList(),
    'suppliers': suppliers.map((item) => item.toJson()).toList(),
    'assignments': assignments.map((item) => item.toJson()).toList(),
    'receipts': receipts.map((item) => item.toJson()).toList(),
    'receiptDetails': receiptDetails.map((item) => item.toJson()).toList(),
    'issues': issues.map((item) => item.toJson()).toList(),
    'issueDetails': issueDetails.map((item) => item.toJson()).toList(),
    'nextId': nextId,
  };

  factory WarehouseAppData.fromJson(Map<String, dynamic> json) =>
      WarehouseAppData(
        users: _decodeList(json['users'], AppUser.fromJson),
        warehouses: _decodeList(json['warehouses'], Warehouse.fromJson),
        units: _decodeList(json['units'], UnitOfMeasure.fromJson),
        categories: _decodeList(json['categories'], ProductCategory.fromJson),
        products: _decodeList(json['products'], Product.fromJson),
        suppliers: _decodeList(json['suppliers'], Supplier.fromJson),
        assignments: _decodeList(
          json['assignments'],
          WarehouseUserAssignment.fromJson,
        ),
        receipts: _decodeList(json['receipts'], ReceiptDocument.fromJson),
        receiptDetails: _decodeList(
          json['receiptDetails'],
          ReceiptDetail.fromJson,
        ),
        issues: _decodeList(json['issues'], IssueDocument.fromJson),
        issueDetails: _decodeList(json['issueDetails'], IssueDetail.fromJson),
        nextId: _asInt(json['nextId'], fallback: 100),
      );
}

List<T> _decodeList<T>(dynamic value, T Function(Map<String, dynamic>) decode) {
  if (value is! List) return <T>[];
  return value
      .map((item) => decode(Map<String, dynamic>.from(item as Map)))
      .toList(growable: true);
}

int _asInt(dynamic value, {int fallback = 0}) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

double _asDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

String _asString(dynamic value) => value?.toString() ?? '';

DateTime _asDate(dynamic value) => DateTime.parse(value.toString());

DocumentStatus _documentStatus(dynamic value) =>
    DocumentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => DocumentStatus.draft,
    );
