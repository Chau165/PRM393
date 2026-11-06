SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET XACT_ABORT ON;
IF DB_NAME() NOT LIKE 'VaxStockAuthTest[_]%' THROW 51400, 'Use isolated batch test database.', 1;
BEGIN TRANSACTION;
DECLARE @admin int=(SELECT Id FROM dbo.AppUserRecords WHERE Username='admin');
DECLARE @hcm int=(SELECT Id FROM dbo.WarehouseRecords WHERE Code='AUTH-HCM');
DECLARE @hn int=(SELECT Id FROM dbo.WarehouseRecords WHERE Code='AUTH-HN');
DECLARE @today date=CONVERT(date,DATEADD(hour,7,SYSUTCDATETIME()));
DECLARE @now datetimeoffset=SYSDATETIMEOFFSET();
INSERT dbo.OrganizationRecords(Code,Name,Country,Kind) VALUES('TRACE-MAN','Trace manufacturer','VN','Manufacturer');
DECLARE @manufacturer int=SCOPE_IDENTITY();
INSERT dbo.OrganizationRecords(Code,Name,Country,Kind) VALUES('TRACE-SUP','Trace supplier','VN','Supplier');
DECLARE @supplier int=SCOPE_IDENTITY();
INSERT dbo.OrganizationRecords(Code,Name,Country,Kind) VALUES('TRACE-REC','Trace recipient','VN','Recipient');
DECLARE @recipient int=SCOPE_IDENTITY();
INSERT dbo.VaccineRecords(Code,Name,ManufacturerId,DosesPerVial,VialsPerPack,StorageMin,StorageMax)
    VALUES('TRACE-VAC','Trace vaccine',@manufacturer,1,10,2,8);
DECLARE @vaccine int=SCOPE_IDENTITY();
INSERT dbo.VaccineBatchRecords(VaccineId,BatchNo,ExpiresAt) VALUES(@vaccine,'TRACE-LOT',DATEADD(day,90,@today));
DECLARE @batch int=SCOPE_IDENTITY();
INSERT dbo.VaccineBatchRecords(VaccineId,BatchNo,ExpiresAt) VALUES(@vaccine,'EXPIRED-TRACE',@today);
DECLARE @expired int=SCOPE_IDENTITY();
INSERT dbo.ReceiptRecords(DocumentNo,WarehouseId,SupplierId,DocumentDate,Status,CreatedById,PostedAt)
    VALUES('IN-HCM',@hcm,@supplier,@today,'Posted',@admin,@now);
DECLARE @receipt int=SCOPE_IDENTITY();
INSERT dbo.ReceiptDetailRecords(ReceiptId,BatchId,Quantity,UnitPrice) VALUES(@receipt,@batch,100,1);
DECLARE @detail int=SCOPE_IDENTITY();
INSERT dbo.StockSegmentRecords(ReceiptDetailId,WarehouseId,QualityStatus) VALUES(@detail,@hcm,'Released');
DECLARE @segment int=SCOPE_IDENTITY();
INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,ReceiptDetailId,EffectiveDate,PostedAt) VALUES(@segment,100,@detail,@today,@now);
INSERT dbo.ReceiptDetailRecords(ReceiptId,BatchId,Quantity,UnitPrice) VALUES(@receipt,@batch,50,1);
SET @detail=SCOPE_IDENTITY();
INSERT dbo.StockSegmentRecords(ReceiptDetailId,WarehouseId,QualityStatus) VALUES(@detail,@hcm,'Quarantined');
DECLARE @quarantined int=SCOPE_IDENTITY();
INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,ReceiptDetailId,EffectiveDate,PostedAt) VALUES(@quarantined,50,@detail,@today,@now);
INSERT dbo.ReceiptDetailRecords(ReceiptId,BatchId,Quantity,UnitPrice) VALUES(@receipt,@batch,40,1);
SET @detail=SCOPE_IDENTITY();
INSERT dbo.StockSegmentRecords(ReceiptDetailId,WarehouseId,QualityStatus) VALUES(@detail,@hcm,'Released');
DECLARE @held int=SCOPE_IDENTITY();
INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,ReceiptDetailId,EffectiveDate,PostedAt) VALUES(@held,40,@detail,@today,@now);
INSERT dbo.ReceiptDetailRecords(ReceiptId,BatchId,Quantity,UnitPrice) VALUES(@receipt,@expired,100,1);
SET @detail=SCOPE_IDENTITY();
INSERT dbo.StockSegmentRecords(ReceiptDetailId,WarehouseId,QualityStatus) VALUES(@detail,@hcm,'Released');
DECLARE @expiredSegment int=SCOPE_IDENTITY();
INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,ReceiptDetailId,EffectiveDate,PostedAt) VALUES(@expiredSegment,100,@detail,@today,@now);
INSERT dbo.ReceiptRecords(DocumentNo,WarehouseId,SupplierId,DocumentDate,Status,CreatedById,PostedAt)
    VALUES('IN-HN-SECRET',@hn,@supplier,@today,'Posted',@admin,@now);
SET @receipt=SCOPE_IDENTITY();
INSERT dbo.ReceiptDetailRecords(ReceiptId,BatchId,Quantity,UnitPrice) VALUES(@receipt,@batch,200,1);
SET @detail=SCOPE_IDENTITY();
INSERT dbo.StockSegmentRecords(ReceiptDetailId,WarehouseId,QualityStatus) VALUES(@detail,@hn,'Released');
DECLARE @hnSegment int=SCOPE_IDENTITY();
INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,ReceiptDetailId,EffectiveDate,PostedAt) VALUES(@hnSegment,200,@detail,@today,@now);
INSERT dbo.IssueRecords(DocumentNo,WarehouseId,RecipientId,DocumentDate,Status,CreatedById,PostedAt)
    VALUES('OUT-HCM',@hcm,@recipient,@today,'Posted',@admin,@now);
DECLARE @issue int=SCOPE_IDENTITY();
INSERT dbo.IssueDetailRecords(IssueId,StockSegmentId,Quantity,UnitPrice) VALUES(@issue,@segment,20,1);
DECLARE @issueDetail int=SCOPE_IDENTITY();
INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,IssueDetailId,EffectiveDate,PostedAt) VALUES(@segment,-20,@issueDetail,@today,@now);
-- Legacy leftover active flag on a Posted issue must not reserve twice.
INSERT dbo.StockReservationRecords(IssueDetailId,Quantity,Active) VALUES(@issueDetail,20,1);
INSERT dbo.IssueRecords(DocumentNo,WarehouseId,RecipientId,DocumentDate,Status,CreatedById) VALUES('DRAFT-HCM',@hcm,@recipient,@today,'Draft',@admin);
SET @issue=SCOPE_IDENTITY();
INSERT dbo.IssueDetailRecords(IssueId,StockSegmentId,Quantity,UnitPrice) VALUES(@issue,@segment,15,1);
SET @issueDetail=SCOPE_IDENTITY();
INSERT dbo.StockReservationRecords(IssueDetailId,Quantity,Active) VALUES(@issueDetail,15,1);
INSERT dbo.IssueDetailRecords(IssueId,StockSegmentId,Quantity,UnitPrice) VALUES(@issue,@quarantined,5,1);
SET @issueDetail=SCOPE_IDENTITY();
INSERT dbo.StockReservationRecords(IssueDetailId,Quantity,Active) VALUES(@issueDetail,5,1);
INSERT dbo.IssueDetailRecords(IssueId,StockSegmentId,Quantity,UnitPrice) VALUES(@issue,@held,7,1);
SET @issueDetail=SCOPE_IDENTITY();
INSERT dbo.StockReservationRecords(IssueDetailId,Quantity,Active) VALUES(@issueDetail,7,0);
INSERT dbo.IssueRecords(DocumentNo,WarehouseId,RecipientId,DocumentDate,Status,CreatedById) VALUES('DRAFT-HN-SECRET',@hn,@recipient,@today,'Draft',@admin);
SET @issue=SCOPE_IDENTITY();
INSERT dbo.IssueDetailRecords(IssueId,StockSegmentId,Quantity,UnitPrice) VALUES(@issue,@hnSegment,25,1);
SET @issueDetail=SCOPE_IDENTITY();
INSERT dbo.StockReservationRecords(IssueDetailId,Quantity,Active) VALUES(@issueDetail,25,1);
INSERT dbo.IncidentRecords(Code,WarehouseId,Kind,Description,Status,OccurredAt,ReportedAt,ReportedById)
    VALUES('TRACE-HOLD-1',@hcm,'Other','Test hold','Open',@now,@now,@admin);
DECLARE @incident int=SCOPE_IDENTITY();
INSERT dbo.IncidentStockSegmentRecords(IncidentId,StockSegmentId,BlockedAt) VALUES(@incident,@held,@now),(@incident,@quarantined,@now);
INSERT dbo.IncidentRecords(Code,WarehouseId,Kind,Description,Status,OccurredAt,ReportedAt,ReportedById)
    VALUES('TRACE-HOLD-2',@hcm,'Other','Second hold','Open',@now,@now,@admin);
SET @incident=SCOPE_IDENTITY();
INSERT dbo.IncidentStockSegmentRecords(IncidentId,StockSegmentId,BlockedAt) VALUES(@incident,@quarantined,@now);
INSERT dbo.StockDispositionRecords(DocumentNo,WarehouseId,Kind,Reason,DocumentDate,Status,CreatedById,ApprovedById,ApprovedAt,PostedAt)
    VALUES('DESTROY-HCM',@hcm,'Destroy','Test fixture',@today,'Posted',@admin,@admin,@now,@now);
DECLARE @disposition int=SCOPE_IDENTITY();
INSERT dbo.StockDispositionDetailRecords(StockDispositionId,StockSegmentId,Quantity) VALUES(@disposition,@segment,10);
DECLARE @dispositionDetail int=SCOPE_IDENTITY();
INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,StockDispositionDetailId,EffectiveDate,PostedAt) VALUES(@segment,-10,@dispositionDetail,@today,@now);
-- Deliberately inconsistent fixtures ensure trace fails closed, never leaking
-- a source document from another warehouse or concealing a negative balance.
INSERT dbo.VaccineBatchRecords(VaccineId,BatchNo,ExpiresAt) VALUES(@vaccine,'BROKEN-TRACE',DATEADD(day,90,@today));
DECLARE @brokenBatch int=SCOPE_IDENTITY();
INSERT dbo.ReceiptRecords(DocumentNo,WarehouseId,SupplierId,DocumentDate,Status,CreatedById,PostedAt)
    VALUES('IN-BROKEN-HCM',@hcm,@supplier,@today,'Posted',@admin,@now);
DECLARE @brokenReceipt int=SCOPE_IDENTITY();
INSERT dbo.ReceiptDetailRecords(ReceiptId,BatchId,Quantity,UnitPrice) VALUES(@brokenReceipt,@brokenBatch,10,1);
SET @detail=SCOPE_IDENTITY();
INSERT dbo.StockSegmentRecords(ReceiptDetailId,WarehouseId,QualityStatus) VALUES(@detail,@hcm,'Released');
DECLARE @brokenSegment int=SCOPE_IDENTITY();
INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,ReceiptDetailId,EffectiveDate,PostedAt) VALUES(@brokenSegment,10,@detail,@today,@now);
INSERT dbo.IssueRecords(DocumentNo,WarehouseId,RecipientId,DocumentDate,Status,CreatedById,PostedAt)
    VALUES('WRONG-HN-SECRET',@hn,@recipient,@today,'Posted',@admin,@now);
SET @issue=SCOPE_IDENTITY();
INSERT dbo.IssueDetailRecords(IssueId,StockSegmentId,Quantity,UnitPrice) VALUES(@issue,@brokenSegment,1,1);
SET @issueDetail=SCOPE_IDENTITY();
INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,IssueDetailId,EffectiveDate,PostedAt) VALUES(@brokenSegment,-1,@issueDetail,@today,@now);
INSERT dbo.VaccineBatchRecords(VaccineId,BatchNo,ExpiresAt) VALUES(@vaccine,'NEGATIVE-TRACE',DATEADD(day,90,@today));
DECLARE @negativeBatch int=SCOPE_IDENTITY();
INSERT dbo.ReceiptDetailRecords(ReceiptId,BatchId,Quantity,UnitPrice) VALUES(@brokenReceipt,@negativeBatch,10,1);
SET @detail=SCOPE_IDENTITY();
INSERT dbo.StockSegmentRecords(ReceiptDetailId,WarehouseId,QualityStatus) VALUES(@detail,@hcm,'Released');
SET @brokenSegment=SCOPE_IDENTITY();
INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,ReceiptDetailId,EffectiveDate,PostedAt) VALUES(@brokenSegment,10,@detail,@today,@now);
INSERT dbo.IssueRecords(DocumentNo,WarehouseId,RecipientId,DocumentDate,Status,CreatedById) VALUES('NEGATIVE-HCM',@hcm,@recipient,@today,'Draft',@admin);
SET @issue=SCOPE_IDENTITY();
INSERT dbo.IssueDetailRecords(IssueId,StockSegmentId,Quantity,UnitPrice) VALUES(@issue,@brokenSegment,23,1);
SET @issueDetail=SCOPE_IDENTITY();
INSERT dbo.StockReservationRecords(IssueDetailId,Quantity,Active) VALUES(@issueDetail,23,1);
COMMIT;
