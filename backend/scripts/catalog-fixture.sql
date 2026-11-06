SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET XACT_ABORT ON;
IF DB_NAME() NOT LIKE 'VaxStockAuthTest[_]%' THROW 51300, 'Use isolated catalog test database.', 1;
BEGIN TRANSACTION;
DECLARE @admin int=(SELECT Id FROM dbo.AppUserRecords WHERE Username='admin');
INSERT dbo.WarehouseRecords(Code,Name) VALUES('FIX-USED-WH','Referenced warehouse');
DECLARE @warehouse int=SCOPE_IDENTITY();
INSERT dbo.OrganizationRecords(Code,Name,Country,Kind) VALUES('FIX-MAN','Fixture manufacturer','VN','Manufacturer');
DECLARE @manufacturer int=SCOPE_IDENTITY();
INSERT dbo.OrganizationRecords(Code,Name,Country,Kind) VALUES('FIX-SUP','Fixture supplier','VN','Supplier');
DECLARE @supplier int=SCOPE_IDENTITY();
INSERT dbo.OrganizationRecords(Code,Name,Country,Kind) VALUES('FIX-REC','Fixture recipient','VN','Recipient');
DECLARE @recipient int=SCOPE_IDENTITY();
INSERT dbo.VaccineRecords(Code,Name,ManufacturerId,DosesPerVial,VialsPerPack,StorageMin,StorageMax)
    VALUES('FIX-VAC-USED','Fixture used vaccine',@manufacturer,1,10,2,8);
DECLARE @vaccine int=SCOPE_IDENTITY();
INSERT dbo.VaccineBatchRecords(VaccineId,BatchNo,ManufacturedAt,ExpiresAt) VALUES(@vaccine,'FIX-LOT','2026-01-01','2030-01-01');
DECLARE @batch int=SCOPE_IDENTITY();
INSERT dbo.ReceiptRecords(DocumentNo,WarehouseId,SupplierId,DocumentDate,Status,CreatedById)
    VALUES('FIX-RECEIPT',@warehouse,@supplier,'2026-11-06','Draft',@admin);
DECLARE @receipt int=SCOPE_IDENTITY();
INSERT dbo.ReceiptDetailRecords(ReceiptId,BatchId,Quantity,UnitPrice) VALUES(@receipt,@batch,10,1);
INSERT dbo.IssueRecords(DocumentNo,WarehouseId,RecipientId,DocumentDate,Status,CreatedById)
    VALUES('FIX-ISSUE',@warehouse,@recipient,'2026-11-06','Draft',@admin);
COMMIT;
