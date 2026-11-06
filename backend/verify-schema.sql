SET NOCOUNT ON;
IF DB_NAME() <> N'VaxStockDev'
    THROW 51000, 'Select VaxStockDev before verification.', 1;

DECLARE @tables TABLE (Name sysname);
INSERT @tables VALUES
('AppUserRecords'), ('WarehouseRecords'), ('WarehouseAssignmentRecords'),
('OrganizationRecords'), ('VaccineRecords'), ('VaccineBatchRecords'),
('ReceiptRecords'), ('ReceiptDetailRecords'), ('StockSegmentRecords'),
('IssueRecords'), ('IssueDetailRecords'), ('StockReservationRecords'),
('StockMovementRecords'), ('QualityDecisionRecords'), ('TradeShipmentRecords'),
('ShipmentDocumentLinkRecords'), ('AuditLogRecords'), ('IncidentRecords'),
('IncidentStockSegmentRecords'), ('StockDispositionRecords'), ('StockDispositionDetailRecords');

IF EXISTS (SELECT 1 FROM @tables WHERE OBJECT_ID(N'dbo.' + Name, N'U') IS NULL)
    THROW 51001, 'A required domain table is missing.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.__EFMigrationsHistory WHERE MigrationId LIKE '%InitialWarehouseSchema')
    THROW 51002, 'Initial migration is not applied.', 1;
IF (SELECT COUNT(*) FROM sys.check_constraints WHERE name LIKE 'CK_%_Valid' AND is_disabled = 0) <> 16
    THROW 51003, 'Expected 16 enabled domain Valid constraints.', 1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id IN
    (SELECT OBJECT_ID(N'dbo.' + Name) FROM @tables) AND (is_disabled = 1 OR delete_referential_action <> 0))
    THROW 51004, 'Foreign keys must be enabled and restrict deletion.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.StockSegmentRecords') AND name = 'RowVersion' AND system_type_id = 189)
    THROW 51005, 'StockSegment rowversion is missing.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.__EFMigrationsHistory WHERE MigrationId LIKE '%IncidentAndDispositionFlow')
    THROW 51006, 'Incident/disposition migration is not applied.', 1;
IF COL_LENGTH('dbo.AppUserRecords','AuthVersion') IS NULL
    OR COL_LENGTH('dbo.AppUserRecords','RowVersion') IS NULL
    THROW 51007, 'Auth session columns are missing.', 1;
IF COL_LENGTH('dbo.WarehouseAssignmentRecords','RowVersion') IS NULL
    THROW 51008, 'Warehouse assignment version is missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.AuditLogRecords') AND name='Details' AND max_length=-1)
    THROW 51009, 'Audit JSON column must preserve long encoded reasons.', 1;
IF COL_LENGTH('dbo.WarehouseRecords','RowVersion') IS NULL
    OR COL_LENGTH('dbo.OrganizationRecords','RowVersion') IS NULL
    OR COL_LENGTH('dbo.VaccineRecords','RowVersion') IS NULL
    THROW 51011, 'Catalog rowversions are missing.', 1;
IF COL_LENGTH('dbo.VaccineBatchRecords','RowVersion') IS NULL
    THROW 51012, 'Vaccine batch version is missing.', 1;
SELECT 'PASS: 21 domain tables, migrations, checks, foreign keys and rowversion.' AS Result;
