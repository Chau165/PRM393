SET NOCOUNT ON;
IF DB_NAME() NOT LIKE 'VaxStockAuthTest[_]%' THROW 51410, 'Use isolated batch test database.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.AuditLogRecords WHERE Action='CreateBatch') THROW 51411, 'Missing batch creation audit.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.AuditLogRecords WHERE Action='UpdateBatch') THROW 51412, 'Missing batch edit audit.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.AuditLogRecords WHERE Action='DeleteBatch') THROW 51413, 'Missing batch deletion audit.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.VaccineBatchRecords WHERE BatchNo='TRACE-LOT') THROW 51414, 'Used batch was deleted.', 1;
IF EXISTS (SELECT 1 FROM dbo.AuditLogRecords WHERE Action='UpdateBatch' AND EntityId=(SELECT TOP(1) Id FROM dbo.VaccineBatchRecords WHERE BatchNo='TRACE-LOT' ORDER BY Id))
    THROW 51415, 'Blocked metadata edit unexpectedly committed.', 1;
SELECT 'PASS: batch audit and referenced metadata preserved.' AS Result;
