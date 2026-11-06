import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'server_catalog_widget_test.dart' as catalog;

Map<String, dynamic> batch({String version = catalog.v1}) => {
  'id': 1,
  'vaccineId': 1,
  'vaccineCode': 'VAC01',
  'vaccineName': 'Vaccine gốc',
  'batchNo': 'LOT-01',
  'manufacturedAt': null,
  'expiresAt': '2027-02-28',
  'expiryStatus': 'Valid',
  'daysToExpiry': 90,
  'version': version,
};

class FakeBatchApi extends catalog.FakeCatalogApi {
  FakeBatchApi({super.role});
  Map<String, dynamic> row = batch();
  final batchRequests = <http.Request>[];
  String? createConflict;
  bool stale = false, used = false, revokeTrace = false, emptyTrace = false;
  int saves = 0;
  @override
  Future<http.Response> handle(http.Request r) async {
    if (r.url.path.endsWith('/warehouses')) {
      return json({
        'items': [
          {
            'id': 7,
            'code': 'W7',
            'name': 'Kho được phép',
            'version': catalog.v1,
          },
        ],
        'page': 1,
        'pageSize': 20,
        'totalItems': 1,
        'totalPages': 1,
      });
    }
    if (!r.url.path.contains('/batches')) return super.handle(r);
    batchRequests.add(r);
    if (r.url.path.endsWith('/trace')) {
      if (revokeTrace) return json({'title': 'Revoked'}, 401);
      final page = int.parse(r.url.queryParameters['page']!);
      return json({
        'batch': row,
        'warehouses': emptyTrace
            ? []
            : [
                {
                  'warehouseId': 7,
                  'warehouseName': 'Kho được phép',
                  'onHand': 100,
                  'reserved': 15,
                  'available': 65,
                },
              ],
        'movements': {
          'items': emptyTrace
              ? []
              : [
                  {
                    'id': page,
                    'stockSegmentId': 10,
                    'batchId': 1,
                    'vaccineId': 1,
                    'warehouseId': 7,
                    'quantityDelta': page == 1 ? 100 : -20,
                    'sourceType': page == 1 ? 'Receipt' : 'Issue',
                    'sourceId': page,
                    'sourceDetailId': page,
                    'documentNo': 'DOC-$page',
                    'effectiveDate': '2026-11-06',
                    'postedAt': '2026-11-06T01:00:00Z',
                  },
                ],
          'page': page,
          'pageSize': 20,
          'totalItems': emptyTrace ? 0 : 21,
          'totalPages': emptyTrace ? 0 : 2,
        },
      });
    }
    if (r.url.path.endsWith('/batches')) {
      if (r.method == 'GET') {
        return json({
          'items': [row],
          'page': 1,
          'pageSize': 20,
          'totalItems': 1,
          'totalPages': 1,
        });
      }
      saves++;
      if (createConflict != null) {
        return json({
          'code': createConflict,
          'title': 'Conflict',
          'existingBatchId': 1,
        }, 409);
      }
      row = {...row, ...jsonDecode(r.body) as Map<String, dynamic>};
      return json(row, 201, '"${row['version']}"');
    }
    if (r.method == 'GET') return json(row, 200, '"${row['version']}"');
    if (used) return json({'title': 'Used', 'code': 'RESOURCE_IN_USE'}, 409);
    if (stale) {
      stale = false;
      row = {...row, 'version': catalog.v2, 'expiresAt': '2027-03-01'};
      return json({'title': 'Stale'}, 412);
    }
    if (r.method == 'DELETE') return http.Response('', 204);
    saves++;
    row = {
      ...row,
      ...jsonDecode(r.body) as Map<String, dynamic>,
      'version': catalog.v2,
    };
    return json(row, 200, '"${row['version']}"');
  }
}

Future<void> action(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> fillNew(WidgetTester t) async {
  await action(t, 'batches.add');
  await action(t, 'batch.editor.vaccine');
  await action(t, 'batch.reference.1');
  await catalog.enter(t, 'batch.editor.number', 'LOT-01');
  await catalog.enter(t, 'batch.editor.expires', '2027-02-28');
}

void main() {
  testWidgets(
    'Staff can create batch with null manufacture date but cannot edit or delete',
    (t) async {
      final fake = FakeBatchApi(role: 'WarehouseStaff');
      final auth = await catalog.open(t, fake, 'batches', mobile: true);
      try {
        expect(find.byKey(const ValueKey('batches.edit.1')), findsNothing);
        expect(find.byKey(const ValueKey('batches.delete.1')), findsNothing);
        await fillNew(t);
        await action(t, 'batch.editor.save');
        final request = fake.batchRequests.singleWhere(
          (r) => r.method == 'POST',
        );
        expect(jsonDecode(request.body), {
          'vaccineId': 1,
          'batchNo': 'LOT-01',
          'manufacturedAt': null,
          'expiresAt': '2027-02-28',
        });
      } finally {
        await catalog.cleanup(t, auth);
      }
    },
  );
  testWidgets(
    'DateOnly validation rejects impossible dates and manufacture after expiry',
    (t) async {
      final fake = FakeBatchApi();
      final auth = await catalog.open(t, fake, 'batches');
      try {
        await fillNew(t);
        await catalog.enter(t, 'batch.editor.expires', '2027-02-30');
        await action(t, 'batch.editor.save');
        expect(fake.saves, 0);
        await catalog.enter(t, 'batch.editor.expires', '2027-02-28');
        await catalog.enter(t, 'batch.editor.manufactured', '2027-03-01');
        await action(t, 'batch.editor.save');
        expect(fake.saves, 0);
        expect(
          find.text('Hạn dùng phải từ ngày sản xuất trở đi.'),
          findsOneWidget,
        );
      } finally {
        await catalog.cleanup(t, auth);
      }
    },
  );
  testWidgets(
    'Stale edit requires reload and PUT only contains dates with fresh ETag',
    (t) async {
      final fake = FakeBatchApi()..stale = true;
      final auth = await catalog.open(t, fake, 'batches');
      try {
        await action(t, 'batches.edit.1');
        await action(t, 'batch.editor.save');
        expect(
          t
              .widget<FilledButton>(
                find.byKey(const ValueKey('batch.editor.save')),
              )
              .onPressed,
          isNull,
        );
        await action(t, 'batch.editor.reload');
        await catalog.enter(t, 'batch.editor.expires', '2027-03-02');
        await action(t, 'batch.editor.save');
        final request = fake.batchRequests.lastWhere((r) => r.method == 'PUT');
        expect(request.headers['If-Match'], '"${catalog.v2}"');
        expect(jsonDecode(request.body), {
          'manufacturedAt': null,
          'expiresAt': '2027-03-02',
        });
      } finally {
        await catalog.cleanup(t, auth);
      }
    },
  );
  testWidgets('Used batch delete is blocked without repeat deletion', (
    t,
  ) async {
    final fake = FakeBatchApi()..used = true;
    final auth = await catalog.open(t, fake, 'batches');
    try {
      await action(t, 'batches.delete.1');
      await action(t, 'batch.editor.save');
      expect(find.textContaining('kể cả nháp'), findsWidgets);
      expect(
        t
            .widget<FilledButton>(
              find.byKey(const ValueKey('batch.editor.save')),
            )
            .onPressed,
        isNull,
      );
    } finally {
      await catalog.cleanup(t, auth);
    }
  });
  testWidgets(
    'Conflicting duplicate opens existing trace instead of overwriting',
    (t) async {
      final fake = FakeBatchApi()..createConflict = 'BATCH_METADATA_CONFLICT';
      final auth = await catalog.open(t, fake, 'batches');
      try {
        await fillNew(t);
        await action(t, 'batch.editor.save');
        expect(find.textContaining('Không tự ghi đè'), findsOneWidget);
        await action(t, 'batch.editor.existing');
        expect(find.text('Truy xuất lô'), findsOneWidget);
        expect(fake.batchRequests.where((r) => r.method == 'PUT'), isEmpty);
      } finally {
        await catalog.cleanup(t, auth);
      }
    },
  );
  testWidgets(
    'Trace pages movements without changing server totals and resets page on warehouse filter',
    (t) async {
      final fake = FakeBatchApi();
      final auth = await catalog.open(t, fake, 'batches', mobile: true);
      try {
        await action(t, 'batches.trace.1');
        expect(find.textContaining('Khả dụng: 65'), findsOneWidget);
        await action(t, 'batch.trace.next');
        expect(find.textContaining('DOC-2'), findsOneWidget);
        expect(find.textContaining('Khả dụng: 65'), findsOneWidget);
        await action(t, 'batch.trace.warehouse');
        await action(t, 'batch.reference.7');
        final trace = fake.batchRequests.last;
        expect(trace.url.queryParameters['warehouseId'], '7');
        expect(trace.url.queryParameters['page'], '1');
        await action(t, 'batch.trace.clear');
        expect(
          fake.batchRequests.last.url.queryParameters.containsKey(
            'warehouseId',
          ),
          isFalse,
        );
      } finally {
        await catalog.cleanup(t, auth);
      }
    },
  );
  testWidgets(
    'Empty trace shows no fabricated stock and revoked trace removes session',
    (t) async {
      final fake = FakeBatchApi()..emptyTrace = true;
      final auth = await catalog.open(t, fake, 'batches');
      try {
        await action(t, 'batches.trace.1');
        expect(
          find.text('Chưa có tồn tại kho trong phạm vi đang xem.'),
          findsOneWidget,
        );
        expect(
          find.text('Chưa có biến động trong phạm vi đang xem.'),
          findsOneWidget,
        );
        fake.revokeTrace = true;
        await t.tap(find.byTooltip('Tải lại'));
        await t.pumpAndSettle();
        expect(find.text('Truy xuất lô'), findsNothing);
        expect(
          find.byKey(const ValueKey('server.login.submit')),
          findsOneWidget,
        );
      } finally {
        await catalog.cleanup(t, auth);
      }
    },
  );
}
