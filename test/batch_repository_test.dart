import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warehouse/core/network/api_client.dart';
import 'package:warehouse/features/batches/batch_controller.dart';
import 'package:warehouse/features/batches/batch_repository.dart';

import 'server_batches_widget_test.dart' show batch;

void main() {
  test('Batch dates stay DateOnly and invalid calendar dates are rejected', () {
    expect(validBatchDate('2028-02-29'), '2028-02-29');
    for (final s in [
      '2027-02-29',
      '2027-02-30',
      '0000-01-01',
      '2026-13-01',
      '2026-1-01',
      '2026-01-01T00:00:00Z',
    ]) {
      expect(validBatchDate(s), isNull);
    }
  });
  test('Batch conflict preserves existing ID from problem details', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({'code': 'BATCH_METADATA_CONFLICT', 'existingBatchId': 9}),
          409,
        ),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      BatchRepository(api)
          .create(vaccineId: 1, batchNo: 'A', expiresAt: '2027-02-28'),
      throwsA(
        isA<ApiException>().having((e) => e.existingBatchId, 'existingId', 9),
      ),
    );
  });
  test('Latest batch search wins, filters encoded and preserved', () async {
    final first = Completer<http.Response>(),
        second = Completer<http.Response>();
    var calls = 0;
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((r) {
        expect(r.url.queryParameters['expiresBefore'], '2027-03-01');
        expect(r.url.queryParameters['expiryStatus'], 'NearExpiry');
        calls++;
        return calls == 1 ? first.future : second.future;
      }),
    );
    addTearDown(api.close);
    final c = BatchController(BatchRepository(api));
    addTearDown(c.dispose);
    final a = c.load(
      search: 'A & B',
      filters: {'expiresBefore': '2027-03-01', 'expiryStatus': 'NearExpiry'},
    );
    final b = c.load(search: 'new');
    http.Response result(String name) => http.Response(
      jsonEncode({
        'items': [
          {...batch(), 'batchNo': name},
        ],
        'page': 1,
        'totalPages': 1,
        'totalItems': 1,
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    second.complete(result('new'));
    await b;
    first.complete(result('old'));
    await a;
    expect(c.data!.items.single.batchNo, 'new');
    expect(c.search, 'new');
  });
}
