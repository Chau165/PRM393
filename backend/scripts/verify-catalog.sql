SET NOCOUNT ON;
IF DB_NAME() NOT LIKE 'VaxStockAuthTest[_]%' THROW 51310, 'Use isolated test database.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.AuditLogRecords WHERE Action='UpdateVaccine' AND JSON_VALUE(Details,'$.storageReviewRequired')='true')
    THROW 51311, 'Storage condition update was not audited.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.AuditLogRecords WHERE Action='DeleteVaccine') THROW 51312, 'Missing deletion audit.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.AuditLogRecords WHERE Action='CreateOrganization') THROW 51313, 'Missing organization audit.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.WarehouseRecords WHERE Code='FIX-USED-WH') THROW 51314, 'Referenced warehouse was deleted.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.VaccineRecords WHERE Code='FIX-VAC-USED' AND DosesPerVial=1) THROW 51315, 'Referenced vaccine packaging changed.', 1;
SELECT 'PASS: catalog audit, storage review and referenced data preserved.' AS Result;
