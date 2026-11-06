IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [AppUserRecords] (
        [Id] int NOT NULL IDENTITY,
        [Username] nvarchar(200) NOT NULL,
        [PasswordHash] nvarchar(200) NOT NULL,
        [FullName] nvarchar(200) NOT NULL,
        [Role] nvarchar(200) NOT NULL,
        CONSTRAINT [PK_AppUserRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_AppUser_Valid] CHECK ([Role] IN ('Admin','WarehouseStaff','QualityManager'))
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [OrganizationRecords] (
        [Id] int NOT NULL IDENTITY,
        [Code] nvarchar(200) NOT NULL,
        [Name] nvarchar(200) NOT NULL,
        [Country] nvarchar(200) NOT NULL,
        [Kind] nvarchar(200) NOT NULL,
        CONSTRAINT [PK_OrganizationRecords] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [WarehouseRecords] (
        [Id] int NOT NULL IDENTITY,
        [Code] nvarchar(200) NOT NULL,
        [Name] nvarchar(200) NOT NULL,
        CONSTRAINT [PK_WarehouseRecords] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [AuditLogRecords] (
        [Id] int NOT NULL IDENTITY,
        [ActorId] int NOT NULL,
        [Action] nvarchar(200) NOT NULL,
        [EntityType] nvarchar(200) NOT NULL,
        [EntityId] int NOT NULL,
        [Details] nvarchar(2000) NOT NULL,
        [OccurredAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_AuditLogRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_AuditLogRecords_AppUserRecords_ActorId] FOREIGN KEY ([ActorId]) REFERENCES [AppUserRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [TradeShipmentRecords] (
        [Id] int NOT NULL IDENTITY,
        [Code] nvarchar(200) NOT NULL,
        [Kind] nvarchar(200) NOT NULL,
        [PartnerId] int NOT NULL,
        [OriginCountry] nvarchar(200) NOT NULL,
        [DestinationCountry] nvarchar(200) NOT NULL,
        [Status] nvarchar(200) NOT NULL,
        [ExpectedDate] date NULL,
        CONSTRAINT [PK_TradeShipmentRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_TradeShipmentRecords_OrganizationRecords_PartnerId] FOREIGN KEY ([PartnerId]) REFERENCES [OrganizationRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [VaccineRecords] (
        [Id] int NOT NULL IDENTITY,
        [Code] nvarchar(200) NOT NULL,
        [Name] nvarchar(200) NOT NULL,
        [ManufacturerId] int NOT NULL,
        [DosesPerVial] int NOT NULL,
        [VialsPerPack] int NOT NULL,
        [StorageMin] decimal(18,2) NOT NULL,
        [StorageMax] decimal(18,2) NOT NULL,
        CONSTRAINT [PK_VaccineRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_Vaccine_Valid] CHECK ([DosesPerVial] > 0 AND [VialsPerPack] > 0 AND [StorageMin] < [StorageMax]),
        CONSTRAINT [FK_VaccineRecords_OrganizationRecords_ManufacturerId] FOREIGN KEY ([ManufacturerId]) REFERENCES [OrganizationRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [IssueRecords] (
        [Id] int NOT NULL IDENTITY,
        [DocumentNo] nvarchar(200) NOT NULL,
        [WarehouseId] int NOT NULL,
        [RecipientId] int NOT NULL,
        [DocumentDate] date NOT NULL,
        [Status] nvarchar(200) NOT NULL,
        [CreatedById] int NOT NULL,
        [PostedAt] datetimeoffset NULL,
        CONSTRAINT [PK_IssueRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_Issue_Valid] CHECK (([Status] IN ('Draft','Cancelled') AND [PostedAt] IS NULL) OR ([Status] = 'Posted' AND [PostedAt] IS NOT NULL)),
        CONSTRAINT [FK_IssueRecords_AppUserRecords_CreatedById] FOREIGN KEY ([CreatedById]) REFERENCES [AppUserRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_IssueRecords_OrganizationRecords_RecipientId] FOREIGN KEY ([RecipientId]) REFERENCES [OrganizationRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_IssueRecords_WarehouseRecords_WarehouseId] FOREIGN KEY ([WarehouseId]) REFERENCES [WarehouseRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [ReceiptRecords] (
        [Id] int NOT NULL IDENTITY,
        [DocumentNo] nvarchar(200) NOT NULL,
        [WarehouseId] int NOT NULL,
        [SupplierId] int NOT NULL,
        [DocumentDate] date NOT NULL,
        [Status] nvarchar(200) NOT NULL,
        [CreatedById] int NOT NULL,
        [PostedAt] datetimeoffset NULL,
        CONSTRAINT [PK_ReceiptRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_Receipt_Valid] CHECK (([Status] = 'Draft' AND [PostedAt] IS NULL) OR ([Status] = 'Posted' AND [PostedAt] IS NOT NULL)),
        CONSTRAINT [FK_ReceiptRecords_AppUserRecords_CreatedById] FOREIGN KEY ([CreatedById]) REFERENCES [AppUserRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_ReceiptRecords_OrganizationRecords_SupplierId] FOREIGN KEY ([SupplierId]) REFERENCES [OrganizationRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_ReceiptRecords_WarehouseRecords_WarehouseId] FOREIGN KEY ([WarehouseId]) REFERENCES [WarehouseRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [WarehouseAssignmentRecords] (
        [Id] int NOT NULL IDENTITY,
        [UserId] int NOT NULL,
        [WarehouseId] int NOT NULL,
        CONSTRAINT [PK_WarehouseAssignmentRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_WarehouseAssignmentRecords_AppUserRecords_UserId] FOREIGN KEY ([UserId]) REFERENCES [AppUserRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_WarehouseAssignmentRecords_WarehouseRecords_WarehouseId] FOREIGN KEY ([WarehouseId]) REFERENCES [WarehouseRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [VaccineBatchRecords] (
        [Id] int NOT NULL IDENTITY,
        [VaccineId] int NOT NULL,
        [BatchNo] nvarchar(200) NOT NULL,
        [ManufacturedAt] date NULL,
        [ExpiresAt] date NOT NULL,
        CONSTRAINT [PK_VaccineBatchRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_VaccineBatch_Valid] CHECK ([ManufacturedAt] IS NULL OR [ManufacturedAt] <= [ExpiresAt]),
        CONSTRAINT [FK_VaccineBatchRecords_VaccineRecords_VaccineId] FOREIGN KEY ([VaccineId]) REFERENCES [VaccineRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [ShipmentDocumentLinkRecords] (
        [Id] int NOT NULL IDENTITY,
        [TradeShipmentId] int NOT NULL,
        [ReceiptId] int NULL,
        [IssueId] int NULL,
        CONSTRAINT [PK_ShipmentDocumentLinkRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_ShipmentDocumentLink_Valid] CHECK (([ReceiptId] IS NOT NULL AND [IssueId] IS NULL) OR ([ReceiptId] IS NULL AND [IssueId] IS NOT NULL)),
        CONSTRAINT [FK_ShipmentDocumentLinkRecords_IssueRecords_IssueId] FOREIGN KEY ([IssueId]) REFERENCES [IssueRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_ShipmentDocumentLinkRecords_ReceiptRecords_ReceiptId] FOREIGN KEY ([ReceiptId]) REFERENCES [ReceiptRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_ShipmentDocumentLinkRecords_TradeShipmentRecords_TradeShipmentId] FOREIGN KEY ([TradeShipmentId]) REFERENCES [TradeShipmentRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [ReceiptDetailRecords] (
        [Id] int NOT NULL IDENTITY,
        [ReceiptId] int NOT NULL,
        [BatchId] int NOT NULL,
        [Quantity] int NOT NULL,
        [UnitPrice] decimal(18,2) NOT NULL,
        CONSTRAINT [PK_ReceiptDetailRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_ReceiptDetail_Valid] CHECK ([Quantity] > 0 AND [UnitPrice] >= 0),
        CONSTRAINT [FK_ReceiptDetailRecords_ReceiptRecords_ReceiptId] FOREIGN KEY ([ReceiptId]) REFERENCES [ReceiptRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_ReceiptDetailRecords_VaccineBatchRecords_BatchId] FOREIGN KEY ([BatchId]) REFERENCES [VaccineBatchRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [StockSegmentRecords] (
        [Id] int NOT NULL IDENTITY,
        [ReceiptDetailId] int NOT NULL,
        [WarehouseId] int NOT NULL,
        [QualityStatus] nvarchar(200) NOT NULL,
        [RowVersion] rowversion NOT NULL,
        CONSTRAINT [PK_StockSegmentRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_StockSegment_Valid] CHECK ([QualityStatus] IN ('Pending','Released','Quarantined','Rejected')),
        CONSTRAINT [FK_StockSegmentRecords_ReceiptDetailRecords_ReceiptDetailId] FOREIGN KEY ([ReceiptDetailId]) REFERENCES [ReceiptDetailRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_StockSegmentRecords_WarehouseRecords_WarehouseId] FOREIGN KEY ([WarehouseId]) REFERENCES [WarehouseRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [IssueDetailRecords] (
        [Id] int NOT NULL IDENTITY,
        [IssueId] int NOT NULL,
        [StockSegmentId] int NOT NULL,
        [Quantity] int NOT NULL,
        [UnitPrice] decimal(18,2) NOT NULL,
        CONSTRAINT [PK_IssueDetailRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_IssueDetail_Valid] CHECK ([Quantity] > 0 AND [UnitPrice] >= 0),
        CONSTRAINT [FK_IssueDetailRecords_IssueRecords_IssueId] FOREIGN KEY ([IssueId]) REFERENCES [IssueRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_IssueDetailRecords_StockSegmentRecords_StockSegmentId] FOREIGN KEY ([StockSegmentId]) REFERENCES [StockSegmentRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [QualityDecisionRecords] (
        [Id] int NOT NULL IDENTITY,
        [StockSegmentId] int NOT NULL,
        [DecidedById] int NOT NULL,
        [Status] nvarchar(200) NOT NULL,
        [Reason] nvarchar(2000) NOT NULL,
        [DecidedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_QualityDecisionRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_QualityDecision_Valid] CHECK ([Status] IN ('Pending','Released','Quarantined','Rejected')),
        CONSTRAINT [FK_QualityDecisionRecords_AppUserRecords_DecidedById] FOREIGN KEY ([DecidedById]) REFERENCES [AppUserRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_QualityDecisionRecords_StockSegmentRecords_StockSegmentId] FOREIGN KEY ([StockSegmentId]) REFERENCES [StockSegmentRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [StockMovementRecords] (
        [Id] int NOT NULL IDENTITY,
        [StockSegmentId] int NOT NULL,
        [QuantityDelta] int NOT NULL,
        [ReceiptDetailId] int NULL,
        [IssueDetailId] int NULL,
        [EffectiveDate] date NOT NULL,
        [PostedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_StockMovementRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_StockMovement_Valid] CHECK (([ReceiptDetailId] IS NOT NULL AND [IssueDetailId] IS NULL AND [QuantityDelta] > 0) OR ([ReceiptDetailId] IS NULL AND [IssueDetailId] IS NOT NULL AND [QuantityDelta] < 0)),
        CONSTRAINT [FK_StockMovementRecords_IssueDetailRecords_IssueDetailId] FOREIGN KEY ([IssueDetailId]) REFERENCES [IssueDetailRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_StockMovementRecords_ReceiptDetailRecords_ReceiptDetailId] FOREIGN KEY ([ReceiptDetailId]) REFERENCES [ReceiptDetailRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_StockMovementRecords_StockSegmentRecords_StockSegmentId] FOREIGN KEY ([StockSegmentId]) REFERENCES [StockSegmentRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE TABLE [StockReservationRecords] (
        [Id] int NOT NULL IDENTITY,
        [IssueDetailId] int NOT NULL,
        [Quantity] int NOT NULL,
        [Active] bit NOT NULL,
        CONSTRAINT [PK_StockReservationRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_StockReservation_Valid] CHECK ([Quantity] > 0),
        CONSTRAINT [FK_StockReservationRecords_IssueDetailRecords_IssueDetailId] FOREIGN KEY ([IssueDetailId]) REFERENCES [IssueDetailRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE UNIQUE INDEX [IX_AppUserRecords_Username] ON [AppUserRecords] ([Username]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_AuditLogRecords_ActorId] ON [AuditLogRecords] ([ActorId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_IssueDetailRecords_IssueId] ON [IssueDetailRecords] ([IssueId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_IssueDetailRecords_StockSegmentId] ON [IssueDetailRecords] ([StockSegmentId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_IssueRecords_CreatedById] ON [IssueRecords] ([CreatedById]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE UNIQUE INDEX [IX_IssueRecords_DocumentNo] ON [IssueRecords] ([DocumentNo]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_IssueRecords_RecipientId] ON [IssueRecords] ([RecipientId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_IssueRecords_WarehouseId] ON [IssueRecords] ([WarehouseId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE UNIQUE INDEX [IX_OrganizationRecords_Code] ON [OrganizationRecords] ([Code]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_QualityDecisionRecords_DecidedById] ON [QualityDecisionRecords] ([DecidedById]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_QualityDecisionRecords_StockSegmentId] ON [QualityDecisionRecords] ([StockSegmentId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_ReceiptDetailRecords_BatchId] ON [ReceiptDetailRecords] ([BatchId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_ReceiptDetailRecords_ReceiptId] ON [ReceiptDetailRecords] ([ReceiptId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_ReceiptRecords_CreatedById] ON [ReceiptRecords] ([CreatedById]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE UNIQUE INDEX [IX_ReceiptRecords_DocumentNo] ON [ReceiptRecords] ([DocumentNo]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_ReceiptRecords_SupplierId] ON [ReceiptRecords] ([SupplierId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_ReceiptRecords_WarehouseId] ON [ReceiptRecords] ([WarehouseId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_ShipmentDocumentLinkRecords_IssueId] ON [ShipmentDocumentLinkRecords] ([IssueId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_ShipmentDocumentLinkRecords_ReceiptId] ON [ShipmentDocumentLinkRecords] ([ReceiptId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_ShipmentDocumentLinkRecords_TradeShipmentId] ON [ShipmentDocumentLinkRecords] ([TradeShipmentId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_StockMovementRecords_IssueDetailId] ON [StockMovementRecords] ([IssueDetailId]) WHERE [IssueDetailId] IS NOT NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_StockMovementRecords_ReceiptDetailId] ON [StockMovementRecords] ([ReceiptDetailId]) WHERE [ReceiptDetailId] IS NOT NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_StockMovementRecords_StockSegmentId] ON [StockMovementRecords] ([StockSegmentId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE UNIQUE INDEX [IX_StockReservationRecords_IssueDetailId] ON [StockReservationRecords] ([IssueDetailId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE UNIQUE INDEX [IX_StockSegmentRecords_ReceiptDetailId] ON [StockSegmentRecords] ([ReceiptDetailId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_StockSegmentRecords_WarehouseId] ON [StockSegmentRecords] ([WarehouseId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE UNIQUE INDEX [IX_TradeShipmentRecords_Code] ON [TradeShipmentRecords] ([Code]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_TradeShipmentRecords_PartnerId] ON [TradeShipmentRecords] ([PartnerId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE UNIQUE INDEX [IX_VaccineBatchRecords_VaccineId_BatchNo] ON [VaccineBatchRecords] ([VaccineId], [BatchNo]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE UNIQUE INDEX [IX_VaccineRecords_Code] ON [VaccineRecords] ([Code]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_VaccineRecords_ManufacturerId] ON [VaccineRecords] ([ManufacturerId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE UNIQUE INDEX [IX_WarehouseAssignmentRecords_UserId_WarehouseId] ON [WarehouseAssignmentRecords] ([UserId], [WarehouseId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE INDEX [IX_WarehouseAssignmentRecords_WarehouseId] ON [WarehouseAssignmentRecords] ([WarehouseId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    CREATE UNIQUE INDEX [IX_WarehouseRecords_Code] ON [WarehouseRecords] ([Code]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261105174847_InitialWarehouseSchema'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261105174847_InitialWarehouseSchema', N'10.0.12');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    DROP INDEX [IX_StockSegmentRecords_WarehouseId] ON [StockSegmentRecords];
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    ALTER TABLE [StockMovementRecords] DROP CONSTRAINT [CK_StockMovement_Valid];
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    ALTER TABLE [StockMovementRecords] ADD [StockDispositionDetailId] int NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    ALTER TABLE [QualityDecisionRecords] ADD [IncidentId] int NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE TABLE [IncidentRecords] (
        [Id] int NOT NULL IDENTITY,
        [Code] nvarchar(200) NOT NULL,
        [WarehouseId] int NOT NULL,
        [Kind] nvarchar(200) NOT NULL,
        [Description] nvarchar(2000) NOT NULL,
        [Status] nvarchar(200) NOT NULL,
        [OccurredAt] datetimeoffset NOT NULL,
        [ReportedAt] datetimeoffset NOT NULL,
        [ReportedById] int NOT NULL,
        [ClosedAt] datetimeoffset NULL,
        [ClosedById] int NULL,
        [Resolution] nvarchar(2000) NULL,
        [RowVersion] rowversion NOT NULL,
        CONSTRAINT [PK_IncidentRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_Incident_Dates] CHECK ([ReportedAt] >= [OccurredAt] AND ([ClosedAt] IS NULL OR [ClosedAt] >= [ReportedAt])),
        CONSTRAINT [CK_Incident_Kind] CHECK ([Kind] IN ('TemperatureExcursion','PackagingDamage','Expiry','Recall','Other')),
        CONSTRAINT [CK_Incident_Valid] CHECK (([Status] IN ('Open','Investigating') AND [ClosedAt] IS NULL AND [ClosedById] IS NULL AND [Resolution] IS NULL) OR ([Status] = 'Closed' AND [ClosedAt] IS NOT NULL AND [ClosedById] IS NOT NULL AND [Resolution] IS NOT NULL AND LEN(LTRIM(RTRIM([Resolution]))) > 0)),
        CONSTRAINT [FK_IncidentRecords_AppUserRecords_ClosedById] FOREIGN KEY ([ClosedById]) REFERENCES [AppUserRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_IncidentRecords_AppUserRecords_ReportedById] FOREIGN KEY ([ReportedById]) REFERENCES [AppUserRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_IncidentRecords_WarehouseRecords_WarehouseId] FOREIGN KEY ([WarehouseId]) REFERENCES [WarehouseRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE TABLE [IncidentStockSegmentRecords] (
        [Id] int NOT NULL IDENTITY,
        [IncidentId] int NOT NULL,
        [StockSegmentId] int NOT NULL,
        [BlockedAt] datetimeoffset NOT NULL,
        [ReleasedAt] datetimeoffset NULL,
        [ReleasedById] int NULL,
        [ReleaseReason] nvarchar(2000) NULL,
        CONSTRAINT [PK_IncidentStockSegmentRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_IncidentStockSegment_Valid] CHECK (([ReleasedAt] IS NULL AND [ReleasedById] IS NULL AND [ReleaseReason] IS NULL) OR ([ReleasedAt] IS NOT NULL AND [ReleasedAt] >= [BlockedAt] AND [ReleasedById] IS NOT NULL AND [ReleaseReason] IS NOT NULL AND LEN(LTRIM(RTRIM([ReleaseReason]))) > 0)),
        CONSTRAINT [FK_IncidentStockSegmentRecords_AppUserRecords_ReleasedById] FOREIGN KEY ([ReleasedById]) REFERENCES [AppUserRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_IncidentStockSegmentRecords_IncidentRecords_IncidentId] FOREIGN KEY ([IncidentId]) REFERENCES [IncidentRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_IncidentStockSegmentRecords_StockSegmentRecords_StockSegmentId] FOREIGN KEY ([StockSegmentId]) REFERENCES [StockSegmentRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE TABLE [StockDispositionRecords] (
        [Id] int NOT NULL IDENTITY,
        [DocumentNo] nvarchar(200) NOT NULL,
        [WarehouseId] int NOT NULL,
        [Kind] nvarchar(200) NOT NULL,
        [SupplierId] int NULL,
        [IncidentId] int NULL,
        [Reason] nvarchar(2000) NOT NULL,
        [DocumentDate] date NOT NULL,
        [Status] nvarchar(200) NOT NULL,
        [CreatedById] int NOT NULL,
        [ApprovedById] int NULL,
        [ApprovedAt] datetimeoffset NULL,
        [PostedAt] datetimeoffset NULL,
        [RowVersion] rowversion NOT NULL,
        CONSTRAINT [PK_StockDispositionRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_StockDisposition_Kind] CHECK (([Kind] = 'ReturnToSupplier' AND [SupplierId] IS NOT NULL) OR ([Kind] = 'Destroy' AND [SupplierId] IS NULL)),
        CONSTRAINT [CK_StockDisposition_Reason] CHECK (LEN(LTRIM(RTRIM([Reason]))) > 0),
        CONSTRAINT [CK_StockDisposition_Valid] CHECK (([Status] IN ('Draft','Cancelled') AND [ApprovedAt] IS NULL AND [ApprovedById] IS NULL AND [PostedAt] IS NULL) OR ([Status] = 'Approved' AND [ApprovedAt] IS NOT NULL AND [ApprovedById] IS NOT NULL AND [PostedAt] IS NULL) OR ([Status] = 'Posted' AND [ApprovedAt] IS NOT NULL AND [ApprovedById] IS NOT NULL AND [PostedAt] IS NOT NULL AND [PostedAt] >= [ApprovedAt])),
        CONSTRAINT [FK_StockDispositionRecords_AppUserRecords_ApprovedById] FOREIGN KEY ([ApprovedById]) REFERENCES [AppUserRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_StockDispositionRecords_AppUserRecords_CreatedById] FOREIGN KEY ([CreatedById]) REFERENCES [AppUserRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_StockDispositionRecords_IncidentRecords_IncidentId] FOREIGN KEY ([IncidentId]) REFERENCES [IncidentRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_StockDispositionRecords_OrganizationRecords_SupplierId] FOREIGN KEY ([SupplierId]) REFERENCES [OrganizationRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_StockDispositionRecords_WarehouseRecords_WarehouseId] FOREIGN KEY ([WarehouseId]) REFERENCES [WarehouseRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE TABLE [StockDispositionDetailRecords] (
        [Id] int NOT NULL IDENTITY,
        [StockDispositionId] int NOT NULL,
        [StockSegmentId] int NOT NULL,
        [Quantity] int NOT NULL,
        CONSTRAINT [PK_StockDispositionDetailRecords] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_StockDispositionDetail_Valid] CHECK ([Quantity] > 0),
        CONSTRAINT [FK_StockDispositionDetailRecords_StockDispositionRecords_StockDispositionId] FOREIGN KEY ([StockDispositionId]) REFERENCES [StockDispositionRecords] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_StockDispositionDetailRecords_StockSegmentRecords_StockSegmentId] FOREIGN KEY ([StockSegmentId]) REFERENCES [StockSegmentRecords] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_VaccineBatchRecords_ExpiresAt] ON [VaccineBatchRecords] ([ExpiresAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_StockSegmentRecords_WarehouseId_QualityStatus] ON [StockSegmentRecords] ([WarehouseId], [QualityStatus]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_StockMovementRecords_StockDispositionDetailId] ON [StockMovementRecords] ([StockDispositionDetailId]) WHERE [StockDispositionDetailId] IS NOT NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    EXEC(N'ALTER TABLE [StockMovementRecords] ADD CONSTRAINT [CK_StockMovement_Valid] CHECK (([ReceiptDetailId] IS NOT NULL AND [IssueDetailId] IS NULL AND [StockDispositionDetailId] IS NULL AND [QuantityDelta] > 0) OR ([ReceiptDetailId] IS NULL AND [IssueDetailId] IS NOT NULL AND [StockDispositionDetailId] IS NULL AND [QuantityDelta] < 0) OR ([ReceiptDetailId] IS NULL AND [IssueDetailId] IS NULL AND [StockDispositionDetailId] IS NOT NULL AND [QuantityDelta] < 0))');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_QualityDecisionRecords_IncidentId] ON [QualityDecisionRecords] ([IncidentId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_IncidentRecords_ClosedById] ON [IncidentRecords] ([ClosedById]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE UNIQUE INDEX [IX_IncidentRecords_Code] ON [IncidentRecords] ([Code]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_IncidentRecords_ReportedById] ON [IncidentRecords] ([ReportedById]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_IncidentRecords_WarehouseId_Status] ON [IncidentRecords] ([WarehouseId], [Status]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE UNIQUE INDEX [IX_IncidentStockSegmentRecords_IncidentId_StockSegmentId] ON [IncidentStockSegmentRecords] ([IncidentId], [StockSegmentId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_IncidentStockSegmentRecords_ReleasedById] ON [IncidentStockSegmentRecords] ([ReleasedById]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_IncidentStockSegmentRecords_StockSegmentId_ReleasedAt] ON [IncidentStockSegmentRecords] ([StockSegmentId], [ReleasedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE UNIQUE INDEX [IX_StockDispositionDetailRecords_StockDispositionId_StockSegmentId] ON [StockDispositionDetailRecords] ([StockDispositionId], [StockSegmentId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_StockDispositionDetailRecords_StockSegmentId] ON [StockDispositionDetailRecords] ([StockSegmentId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_StockDispositionRecords_ApprovedById] ON [StockDispositionRecords] ([ApprovedById]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_StockDispositionRecords_CreatedById] ON [StockDispositionRecords] ([CreatedById]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE UNIQUE INDEX [IX_StockDispositionRecords_DocumentNo] ON [StockDispositionRecords] ([DocumentNo]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_StockDispositionRecords_IncidentId] ON [StockDispositionRecords] ([IncidentId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_StockDispositionRecords_SupplierId] ON [StockDispositionRecords] ([SupplierId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    CREATE INDEX [IX_StockDispositionRecords_WarehouseId] ON [StockDispositionRecords] ([WarehouseId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    ALTER TABLE [QualityDecisionRecords] ADD CONSTRAINT [FK_QualityDecisionRecords_IncidentRecords_IncidentId] FOREIGN KEY ([IncidentId]) REFERENCES [IncidentRecords] ([Id]) ON DELETE NO ACTION;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    ALTER TABLE [StockMovementRecords] ADD CONSTRAINT [FK_StockMovementRecords_StockDispositionDetailRecords_StockDispositionDetailId] FOREIGN KEY ([StockDispositionDetailId]) REFERENCES [StockDispositionDetailRecords] ([Id]) ON DELETE NO ACTION;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106072445_IncidentAndDispositionFlow'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261106072445_IncidentAndDispositionFlow', N'10.0.12');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106142011_AuthSessionVersion'
)
BEGIN
    ALTER TABLE [AppUserRecords] ADD [AuthVersion] int NOT NULL DEFAULT 0;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106142011_AuthSessionVersion'
)
BEGIN
    ALTER TABLE [AppUserRecords] ADD [RowVersion] rowversion NOT NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106142011_AuthSessionVersion'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261106142011_AuthSessionVersion', N'10.0.12');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106150206_UserManagementConcurrency'
)
BEGIN
    ALTER TABLE [WarehouseAssignmentRecords] ADD [RowVersion] rowversion NOT NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106150206_UserManagementConcurrency'
)
BEGIN
    DECLARE @var nvarchar(max);
    SELECT @var = QUOTENAME([d].[name])
    FROM [sys].[default_constraints] [d]
    INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
    WHERE ([d].[parent_object_id] = OBJECT_ID(N'[AuditLogRecords]') AND [c].[name] = N'Details');
    IF @var IS NOT NULL EXEC(N'ALTER TABLE [AuditLogRecords] DROP CONSTRAINT ' + @var + ';');
    ALTER TABLE [AuditLogRecords] ALTER COLUMN [Details] nvarchar(max) NOT NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106150206_UserManagementConcurrency'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261106150206_UserManagementConcurrency', N'10.0.12');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106152736_MasterDataConcurrency'
)
BEGIN
    ALTER TABLE [WarehouseRecords] ADD [RowVersion] rowversion NOT NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106152736_MasterDataConcurrency'
)
BEGIN
    ALTER TABLE [VaccineRecords] ADD [RowVersion] rowversion NOT NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106152736_MasterDataConcurrency'
)
BEGIN
    ALTER TABLE [OrganizationRecords] ADD [RowVersion] rowversion NOT NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106152736_MasterDataConcurrency'
)
BEGIN
    EXEC(N'ALTER TABLE [OrganizationRecords] ADD CONSTRAINT [CK_Organization_Kind] CHECK ([Kind] IN (''Manufacturer'',''Supplier'',''Recipient'',''Carrier''))');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106152736_MasterDataConcurrency'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261106152736_MasterDataConcurrency', N'10.0.12');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106153926_VaccineBatchConcurrency'
)
BEGIN
    ALTER TABLE [VaccineBatchRecords] ADD [RowVersion] rowversion NOT NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261106153926_VaccineBatchConcurrency'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261106153926_VaccineBatchConcurrency', N'10.0.12');
END;

COMMIT;
GO

