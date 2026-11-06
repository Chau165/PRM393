import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse/core/network/api_client.dart';
import 'package:warehouse/features/auth/data/auth_repository.dart';
import 'package:warehouse/features/catalog/data/catalog_repository.dart';

void main() {
  final base = Platform.environment['WAREHOUSE_LIVE_API_URL'];
  test(
    'Catalog Flutter repositories work against ASP.NET and SQL',
    () async {
      final api = ApiClient(baseUrl: base!);
      final staffApi = ApiClient(baseUrl: base);
      try {
        final password = Platform.environment['Seed__Password']!;
        api.token = (await AuthRepository(api).login('admin', password)).token;
        staffApi.token = (await AuthRepository(
          staffApi,
        ).login('staff.hcm', password)).token;
        final orgs = CatalogRepository(api, CatalogResource.organizations);
        final vaccines = CatalogRepository(api, CatalogResource.vaccines);
        final suffix = DateTime.now().microsecondsSinceEpoch;
        Map<String, Object?> org(String kind) => {
          'code': '$kind-$suffix',
          'name': kind,
          'country': 'VN',
          'kind': kind,
        };
        final manufacturer = await orgs.create(org('Manufacturer'));
        final supplier = await orgs.create(org('Supplier'));
        final body = <String, Object?>{
          'code': 'VAC-$suffix',
          'name': 'Live vaccine',
          'manufacturerId': manufacturer.id,
          'dosesPerVial': 1,
          'vialsPerPack': 10,
          'storageMin': -20.25,
          'storageMax': 8,
        };
        final vaccine = await vaccines.create(body);
        expect(vaccine.etag, '"${vaccine.version}"');
        expect(
          (await vaccines.list(
            filters: {'manufacturerId': '${manufacturer.id}'},
          )).items.single.id,
          vaccine.id,
        );
        expect(
          (await orgs.list(
            search: '$suffix',
            filters: {'kind': 'Manufacturer', 'country': 'VN'},
          )).items.single.id,
          manufacturer.id,
        );
        final updated = await vaccines.update(await vaccines.get(vaccine.id), {
          ...body,
          'storageMax': 7,
        });
        expect(updated.storageReviewRequired, isTrue);
        Future<void> fails(Future<Object?> operation, int status) =>
            expectLater(
              operation,
              throwsA(
                isA<ApiException>().having(
                  (e) => e.statusCode,
                  'status',
                  status,
                ),
              ),
            );
        await fails(vaccines.update(vaccine, body), 412);
        await fails(orgs.delete(manufacturer), 409);
        await fails(
          vaccines.create({
            ...body,
            'code': 'INVALID-$suffix',
            'manufacturerId': supplier.id,
          }),
          400,
        );
        await fails(
          CatalogRepository(staffApi, CatalogResource.vaccines).create(body),
          403,
        );
        await vaccines.delete(await vaccines.get(updated.id));
        await orgs.delete(await orgs.get(manufacturer.id));
        await orgs.delete(await orgs.get(supplier.id));
      } finally {
        // Harness drops its isolated test database even when an assertion fails.
        api.close();
        staffApi.close();
      }
    },
    skip: base == null
        ? 'Run backend/scripts/test-auth.ps1 -Suite catalog-fe.'
        : false,
  );
}
