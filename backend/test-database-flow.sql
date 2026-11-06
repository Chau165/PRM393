-- Integration checks against SQL Server. All fixture data is rolled back.
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET XACT_ABORT OFF;
IF DB_NAME() <> N'VaxStockDev' THROW 51100, 'Use VaxStockDev.', 1;
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @suffix nvarchar(36) = CONVERT(nvarchar(36), NEWID());
    INSERT dbo.AppUserRecords(Username,PasswordHash,FullName,Role)
        VALUES (@suffix,'TEST-NOT-A-REAL-HASH','DB fixture','QualityManager');
    DECLARE @user int = SCOPE_IDENTITY();
    INSERT dbo.WarehouseRecords(Code,Name) VALUES (@suffix,'Test warehouse');
    DECLARE @warehouse int = SCOPE_IDENTITY();
    INSERT dbo.OrganizationRecords(Code,Name,Country,Kind) VALUES (@suffix,'Test partner','VN','Manufacturer');
    DECLARE @partner int = SCOPE_IDENTITY();
    INSERT dbo.VaccineRecords(Code,Name,ManufacturerId,DosesPerVial,VialsPerPack,StorageMin,StorageMax)
        VALUES (@suffix,'Test vaccine',@partner,1,10,2,8);
    DECLARE @vaccine int = SCOPE_IDENTITY();
    INSERT dbo.VaccineBatchRecords(VaccineId,BatchNo,ManufacturedAt,ExpiresAt)
        VALUES (@vaccine,@suffix,'2026-01-01','2030-01-01');
    DECLARE @batch int = SCOPE_IDENTITY();
    INSERT dbo.ReceiptRecords(DocumentNo,WarehouseId,SupplierId,DocumentDate,Status,CreatedById,PostedAt)
        VALUES (@suffix,@warehouse,@partner,'2026-11-06','Posted',@user,SYSDATETIMEOFFSET());
    DECLARE @receipt int = SCOPE_IDENTITY();
    INSERT dbo.ReceiptDetailRecords(ReceiptId,BatchId,Quantity,UnitPrice) VALUES (@receipt,@batch,100,10);
    DECLARE @receiptDetail int = SCOPE_IDENTITY();
    INSERT dbo.StockSegmentRecords(ReceiptDetailId,WarehouseId,QualityStatus) VALUES (@receiptDetail,@warehouse,'Pending');
    DECLARE @segment int = SCOPE_IDENTITY();
    INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,ReceiptDetailId,EffectiveDate,PostedAt)
        VALUES (@segment,100,@receiptDetail,'2026-11-06',SYSDATETIMEOFFSET());

    INSERT dbo.IncidentRecords(Code,WarehouseId,Kind,Description,Status,OccurredAt,ReportedAt,ReportedById)
        VALUES (@suffix,@warehouse,'TemperatureExcursion','Test incident','Open',SYSDATETIMEOFFSET(),SYSDATETIMEOFFSET(),@user);
    DECLARE @incident int = SCOPE_IDENTITY();
    INSERT dbo.IncidentStockSegmentRecords(IncidentId,StockSegmentId,BlockedAt)
        VALUES (@incident,@segment,SYSDATETIMEOFFSET());
    UPDATE dbo.StockSegmentRecords SET QualityStatus='Quarantined' WHERE Id=@segment;
    INSERT dbo.QualityDecisionRecords(StockSegmentId,IncidentId,DecidedById,Status,Reason,DecidedAt)
        VALUES (@segment,@incident,@user,'Quarantined','Test hold',SYSDATETIMEOFFSET());

    -- A second independent incident must keep the segment blocked even after
    -- the first incident's hold has been released.
    INSERT dbo.IncidentRecords(Code,WarehouseId,Kind,Description,Status,OccurredAt,ReportedAt,ReportedById)
        VALUES (@suffix+'-2',@warehouse,'PackagingDamage','Second hold','Open',SYSDATETIMEOFFSET(),SYSDATETIMEOFFSET(),@user);
    DECLARE @incident2 int = SCOPE_IDENTITY();
    INSERT dbo.IncidentStockSegmentRecords(IncidentId,StockSegmentId,BlockedAt)
        VALUES (@incident2,@segment,SYSDATETIMEOFFSET());
    UPDATE dbo.IncidentStockSegmentRecords SET ReleasedAt=SYSDATETIMEOFFSET(),ReleasedById=@user,ReleaseReason='Test resolution'
        WHERE IncidentId=@incident;
    IF (SELECT COUNT(*) FROM dbo.IncidentStockSegmentRecords WHERE StockSegmentId=@segment AND ReleasedAt IS NULL) <> 1
        THROW 51101, 'Independent incident hold lost.', 1;

    INSERT dbo.StockDispositionRecords(DocumentNo,WarehouseId,Kind,IncidentId,Reason,DocumentDate,Status,CreatedById,ApprovedById,ApprovedAt,PostedAt)
        VALUES (@suffix,@warehouse,'Destroy',@incident2,'Test damaged stock','2026-11-06','Posted',@user,@user,SYSDATETIMEOFFSET(),SYSDATETIMEOFFSET());
    DECLARE @disposition int = SCOPE_IDENTITY();
    INSERT dbo.StockDispositionDetailRecords(StockDispositionId,StockSegmentId,Quantity) VALUES (@disposition,@segment,10);
    DECLARE @detail int = SCOPE_IDENTITY();
    INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,StockDispositionDetailId,EffectiveDate,PostedAt)
        VALUES (@segment,-10,@detail,'2026-11-06',SYSDATETIMEOFFSET());
    IF (SELECT SUM(QuantityDelta) FROM dbo.StockMovementRecords WHERE StockSegmentId=@segment) <> 90
        THROW 51102, 'Disposition stock balance incorrect.', 1;

    BEGIN TRY
        INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,StockDispositionDetailId,EffectiveDate,PostedAt)
            VALUES (@segment,-10,@detail,'2026-11-06',SYSDATETIMEOFFSET());
        THROW 51103, 'Duplicate posting was accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (2601,2627) THROW;
    END CATCH;
    -- Use unused, valid source keys so unique indexes cannot mask the
    -- check-constraint failure when a movement declares two sources.
    INSERT dbo.ReceiptDetailRecords(ReceiptId,BatchId,Quantity,UnitPrice) VALUES (@receipt,@batch,1,10);
    DECLARE @unusedReceiptDetail int = SCOPE_IDENTITY();
    DELETE dbo.StockMovementRecords WHERE StockDispositionDetailId=@detail;
    BEGIN TRY
        INSERT dbo.StockMovementRecords(StockSegmentId,QuantityDelta,ReceiptDetailId,StockDispositionDetailId,EffectiveDate,PostedAt)
            VALUES (@segment,-1,@unusedReceiptDetail,@detail,'2026-11-06',SYSDATETIMEOFFSET());
        THROW 51104, 'Multiple movement sources were accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 547 THROW;
    END CATCH;
    BEGIN TRY
        INSERT dbo.StockDispositionRecords(DocumentNo,WarehouseId,Kind,Reason,DocumentDate,Status,CreatedById)
            VALUES (@suffix+'-invalid',@warehouse,'ReturnToSupplier','Test','2026-11-06','Draft',@user);
        THROW 51105, 'Supplier-less return was accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 547 THROW;
    END CATCH;
    BEGIN TRY
        UPDATE dbo.IncidentRecords SET Status='Closed' WHERE Id=@incident;
        THROW 51106, 'Closure without actor/time/resolution was accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 547 THROW;
    END CATCH;
    BEGIN TRY
        INSERT dbo.StockDispositionRecords(DocumentNo,WarehouseId,Kind,Reason,DocumentDate,Status,CreatedById,PostedAt)
            VALUES (@suffix+'-unapproved',@warehouse,'Destroy','Test','2026-11-06','Posted',@user,SYSDATETIMEOFFSET());
        THROW 51107, 'Posted disposition without approval was accepted.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 547 THROW;
    END CATCH;
    ROLLBACK;
    SELECT 'PASS: receipt, independent holds, disposition, balance and invalid-data constraints. Fixture rolled back.' AS Result;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
