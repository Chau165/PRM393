import 'dart:math' as math;

import '../models/warehouse_app_data.dart';
import '../../shared/first_or_null.dart';

class WarehouseInventoryService {
  const WarehouseInventoryService();

  List<InventoryItem> currentInventory({
    required WarehouseAppData data,
    required List<Warehouse> warehouses,
    int? warehouseId,
    String search = '',
  }) {
    final query = search.trim().toLowerCase();
    final selectedWarehouses = warehouseId == null
        ? warehouses
        : warehouses.where((warehouse) => warehouse.id == warehouseId).toList();
    final rows = <InventoryItem>[];

    for (final warehouse in selectedWarehouses) {
      for (final product in data.products) {
        if (query.isNotEmpty &&
            !product.code.toLowerCase().contains(query) &&
            !product.name.toLowerCase().contains(query)) {
          continue;
        }
        final onHand = onHandFor(data, warehouse.id, product.id);
        final reserved = reservedFor(data, warehouse.id, product.id);
        final unit = firstOrNull(
          data.units.where((item) => item.id == product.unitId),
        );
        rows.add(
          InventoryItem(
            warehouseId: warehouse.id,
            warehouseName: warehouse.name,
            productId: product.id,
            productCode: product.code,
            productName: product.name,
            unitName: unit?.name ?? '',
            onHand: onHand,
            reserved: reserved,
            available: math.max(0, onHand - reserved).toDouble(),
          ),
        );
      }
    }
    return rows;
  }

  double onHandFor(WarehouseAppData data, int warehouseId, int productId) {
    final postedReceiptIds = data.receipts
        .where(
          (doc) =>
              doc.warehouseId == warehouseId &&
              doc.status == DocumentStatus.posted,
        )
        .map((doc) => doc.id)
        .toSet();
    final postedIssueIds = data.issues
        .where(
          (doc) =>
              doc.warehouseId == warehouseId &&
              doc.status == DocumentStatus.posted,
        )
        .map((doc) => doc.id)
        .toSet();
    final received = data.receiptDetails
        .where(
          (line) =>
              postedReceiptIds.contains(line.receiptId) &&
              line.productId == productId,
        )
        .fold<double>(0, (sum, line) => sum + line.quantity);
    final issued = data.issueDetails
        .where(
          (line) =>
              postedIssueIds.contains(line.issueId) &&
              line.productId == productId,
        )
        .fold<double>(0, (sum, line) => sum + line.quantity);
    return received - issued;
  }

  double reservedFor(
    WarehouseAppData data,
    int warehouseId,
    int productId, {
    int? excludingIssueId,
  }) {
    final draftIssueIds = data.issues
        .where(
          (doc) =>
              doc.warehouseId == warehouseId &&
              doc.status == DocumentStatus.draft &&
              doc.id != excludingIssueId,
        )
        .map((doc) => doc.id)
        .toSet();
    return data.issueDetails
        .where(
          (line) =>
              draftIssueIds.contains(line.issueId) &&
              line.productId == productId,
        )
        .fold<double>(0, (sum, line) => sum + line.quantity);
  }

  List<InventoryPeriodReport> periodReport({
    required WarehouseAppData data,
    required List<Warehouse> warehouses,
    required DateTime fromDate,
    required DateTime toDate,
    String search = '',
  }) {
    final start = _dateOnly(fromDate);
    final end = _dateOnly(toDate);
    final query = search.trim().toLowerCase();
    final rows = <InventoryPeriodReport>[];

    for (final warehouse in warehouses) {
      for (final product in data.products) {
        if (query.isNotEmpty &&
            !product.code.toLowerCase().contains(query) &&
            !product.name.toLowerCase().contains(query)) {
          continue;
        }
        var opening = 0.0;
        var received = 0.0;
        var issued = 0.0;

        for (final document in data.receipts.where(
          (doc) =>
              doc.warehouseId == warehouse.id &&
              doc.status == DocumentStatus.posted,
        )) {
          final quantity = _receiptQuantity(data, document.id, product.id);
          final date = _dateOnly(document.documentDate);
          if (date.isBefore(start)) {
            opening += quantity;
          } else if (!date.isAfter(end)) {
            received += quantity;
          }
        }
        for (final document in data.issues.where(
          (doc) =>
              doc.warehouseId == warehouse.id &&
              doc.status == DocumentStatus.posted,
        )) {
          final quantity = _issueQuantity(data, document.id, product.id);
          final date = _dateOnly(document.documentDate);
          if (date.isBefore(start)) {
            opening -= quantity;
          } else if (!date.isAfter(end)) {
            issued += quantity;
          }
        }

        rows.add(
          InventoryPeriodReport(
            warehouseId: warehouse.id,
            warehouseName: warehouse.name,
            productId: product.id,
            productCode: product.code,
            productName: product.name,
            unitName:
                firstOrNull(
                  data.units.where((item) => item.id == product.unitId),
                )?.name ??
                '',
            opening: opening,
            received: received,
            issued: issued,
            closing: opening + received - issued,
          ),
        );
      }
    }
    return rows;
  }

  double _receiptQuantity(
    WarehouseAppData data,
    int receiptId,
    int productId,
  ) => data.receiptDetails
      .where(
        (line) => line.receiptId == receiptId && line.productId == productId,
      )
      .fold<double>(0, (sum, line) => sum + line.quantity);

  double _issueQuantity(WarehouseAppData data, int issueId, int productId) =>
      data.issueDetails
          .where(
            (line) => line.issueId == issueId && line.productId == productId,
          )
          .fold<double>(0, (sum, line) => sum + line.quantity);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
