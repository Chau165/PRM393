using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace VaxStock.DataAccess.Migrations
{
    /// <inheritdoc />
    public partial class InitialWarehouseSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AppUserRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Username = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    PasswordHash = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    FullName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Role = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AppUserRecords", x => x.Id);
                    table.CheckConstraint("CK_AppUser_Valid", "[Role] IN ('Admin','WarehouseStaff','QualityManager')");
                });

            migrationBuilder.CreateTable(
                name: "OrganizationRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Code = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Country = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Kind = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OrganizationRecords", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "WarehouseRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Code = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WarehouseRecords", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "AuditLogRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ActorId = table.Column<int>(type: "int", nullable: false),
                    Action = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    EntityType = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    EntityId = table.Column<int>(type: "int", nullable: false),
                    Details = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    OccurredAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AuditLogRecords", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AuditLogRecords_AppUserRecords_ActorId",
                        column: x => x.ActorId,
                        principalTable: "AppUserRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "TradeShipmentRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Code = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Kind = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    PartnerId = table.Column<int>(type: "int", nullable: false),
                    OriginCountry = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    DestinationCountry = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    ExpectedDate = table.Column<DateOnly>(type: "date", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TradeShipmentRecords", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TradeShipmentRecords_OrganizationRecords_PartnerId",
                        column: x => x.PartnerId,
                        principalTable: "OrganizationRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "VaccineRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Code = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    ManufacturerId = table.Column<int>(type: "int", nullable: false),
                    DosesPerVial = table.Column<int>(type: "int", nullable: false),
                    VialsPerPack = table.Column<int>(type: "int", nullable: false),
                    StorageMin = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    StorageMax = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VaccineRecords", x => x.Id);
                    table.CheckConstraint("CK_Vaccine_Valid", "[DosesPerVial] > 0 AND [VialsPerPack] > 0 AND [StorageMin] < [StorageMax]");
                    table.ForeignKey(
                        name: "FK_VaccineRecords_OrganizationRecords_ManufacturerId",
                        column: x => x.ManufacturerId,
                        principalTable: "OrganizationRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "IssueRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DocumentNo = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    WarehouseId = table.Column<int>(type: "int", nullable: false),
                    RecipientId = table.Column<int>(type: "int", nullable: false),
                    DocumentDate = table.Column<DateOnly>(type: "date", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    CreatedById = table.Column<int>(type: "int", nullable: false),
                    PostedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_IssueRecords", x => x.Id);
                    table.CheckConstraint("CK_Issue_Valid", "([Status] IN ('Draft','Cancelled') AND [PostedAt] IS NULL) OR ([Status] = 'Posted' AND [PostedAt] IS NOT NULL)");
                    table.ForeignKey(
                        name: "FK_IssueRecords_AppUserRecords_CreatedById",
                        column: x => x.CreatedById,
                        principalTable: "AppUserRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_IssueRecords_OrganizationRecords_RecipientId",
                        column: x => x.RecipientId,
                        principalTable: "OrganizationRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_IssueRecords_WarehouseRecords_WarehouseId",
                        column: x => x.WarehouseId,
                        principalTable: "WarehouseRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ReceiptRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DocumentNo = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    WarehouseId = table.Column<int>(type: "int", nullable: false),
                    SupplierId = table.Column<int>(type: "int", nullable: false),
                    DocumentDate = table.Column<DateOnly>(type: "date", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    CreatedById = table.Column<int>(type: "int", nullable: false),
                    PostedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ReceiptRecords", x => x.Id);
                    table.CheckConstraint("CK_Receipt_Valid", "([Status] = 'Draft' AND [PostedAt] IS NULL) OR ([Status] = 'Posted' AND [PostedAt] IS NOT NULL)");
                    table.ForeignKey(
                        name: "FK_ReceiptRecords_AppUserRecords_CreatedById",
                        column: x => x.CreatedById,
                        principalTable: "AppUserRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ReceiptRecords_OrganizationRecords_SupplierId",
                        column: x => x.SupplierId,
                        principalTable: "OrganizationRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ReceiptRecords_WarehouseRecords_WarehouseId",
                        column: x => x.WarehouseId,
                        principalTable: "WarehouseRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "WarehouseAssignmentRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    WarehouseId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WarehouseAssignmentRecords", x => x.Id);
                    table.ForeignKey(
                        name: "FK_WarehouseAssignmentRecords_AppUserRecords_UserId",
                        column: x => x.UserId,
                        principalTable: "AppUserRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_WarehouseAssignmentRecords_WarehouseRecords_WarehouseId",
                        column: x => x.WarehouseId,
                        principalTable: "WarehouseRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "VaccineBatchRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    VaccineId = table.Column<int>(type: "int", nullable: false),
                    BatchNo = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    ManufacturedAt = table.Column<DateOnly>(type: "date", nullable: true),
                    ExpiresAt = table.Column<DateOnly>(type: "date", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VaccineBatchRecords", x => x.Id);
                    table.CheckConstraint("CK_VaccineBatch_Valid", "[ManufacturedAt] IS NULL OR [ManufacturedAt] <= [ExpiresAt]");
                    table.ForeignKey(
                        name: "FK_VaccineBatchRecords_VaccineRecords_VaccineId",
                        column: x => x.VaccineId,
                        principalTable: "VaccineRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ShipmentDocumentLinkRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TradeShipmentId = table.Column<int>(type: "int", nullable: false),
                    ReceiptId = table.Column<int>(type: "int", nullable: true),
                    IssueId = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ShipmentDocumentLinkRecords", x => x.Id);
                    table.CheckConstraint("CK_ShipmentDocumentLink_Valid", "([ReceiptId] IS NOT NULL AND [IssueId] IS NULL) OR ([ReceiptId] IS NULL AND [IssueId] IS NOT NULL)");
                    table.ForeignKey(
                        name: "FK_ShipmentDocumentLinkRecords_IssueRecords_IssueId",
                        column: x => x.IssueId,
                        principalTable: "IssueRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ShipmentDocumentLinkRecords_ReceiptRecords_ReceiptId",
                        column: x => x.ReceiptId,
                        principalTable: "ReceiptRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ShipmentDocumentLinkRecords_TradeShipmentRecords_TradeShipmentId",
                        column: x => x.TradeShipmentId,
                        principalTable: "TradeShipmentRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ReceiptDetailRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ReceiptId = table.Column<int>(type: "int", nullable: false),
                    BatchId = table.Column<int>(type: "int", nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false),
                    UnitPrice = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ReceiptDetailRecords", x => x.Id);
                    table.CheckConstraint("CK_ReceiptDetail_Valid", "[Quantity] > 0 AND [UnitPrice] >= 0");
                    table.ForeignKey(
                        name: "FK_ReceiptDetailRecords_ReceiptRecords_ReceiptId",
                        column: x => x.ReceiptId,
                        principalTable: "ReceiptRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ReceiptDetailRecords_VaccineBatchRecords_BatchId",
                        column: x => x.BatchId,
                        principalTable: "VaccineBatchRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "StockSegmentRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ReceiptDetailId = table.Column<int>(type: "int", nullable: false),
                    WarehouseId = table.Column<int>(type: "int", nullable: false),
                    QualityStatus = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StockSegmentRecords", x => x.Id);
                    table.CheckConstraint("CK_StockSegment_Valid", "[QualityStatus] IN ('Pending','Released','Quarantined','Rejected')");
                    table.ForeignKey(
                        name: "FK_StockSegmentRecords_ReceiptDetailRecords_ReceiptDetailId",
                        column: x => x.ReceiptDetailId,
                        principalTable: "ReceiptDetailRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockSegmentRecords_WarehouseRecords_WarehouseId",
                        column: x => x.WarehouseId,
                        principalTable: "WarehouseRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "IssueDetailRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    IssueId = table.Column<int>(type: "int", nullable: false),
                    StockSegmentId = table.Column<int>(type: "int", nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false),
                    UnitPrice = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_IssueDetailRecords", x => x.Id);
                    table.CheckConstraint("CK_IssueDetail_Valid", "[Quantity] > 0 AND [UnitPrice] >= 0");
                    table.ForeignKey(
                        name: "FK_IssueDetailRecords_IssueRecords_IssueId",
                        column: x => x.IssueId,
                        principalTable: "IssueRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_IssueDetailRecords_StockSegmentRecords_StockSegmentId",
                        column: x => x.StockSegmentId,
                        principalTable: "StockSegmentRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "QualityDecisionRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    StockSegmentId = table.Column<int>(type: "int", nullable: false),
                    DecidedById = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    DecidedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_QualityDecisionRecords", x => x.Id);
                    table.CheckConstraint("CK_QualityDecision_Valid", "[Status] IN ('Pending','Released','Quarantined','Rejected')");
                    table.ForeignKey(
                        name: "FK_QualityDecisionRecords_AppUserRecords_DecidedById",
                        column: x => x.DecidedById,
                        principalTable: "AppUserRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_QualityDecisionRecords_StockSegmentRecords_StockSegmentId",
                        column: x => x.StockSegmentId,
                        principalTable: "StockSegmentRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "StockMovementRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    StockSegmentId = table.Column<int>(type: "int", nullable: false),
                    QuantityDelta = table.Column<int>(type: "int", nullable: false),
                    ReceiptDetailId = table.Column<int>(type: "int", nullable: true),
                    IssueDetailId = table.Column<int>(type: "int", nullable: true),
                    EffectiveDate = table.Column<DateOnly>(type: "date", nullable: false),
                    PostedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StockMovementRecords", x => x.Id);
                    table.CheckConstraint("CK_StockMovement_Valid", "([ReceiptDetailId] IS NOT NULL AND [IssueDetailId] IS NULL AND [QuantityDelta] > 0) OR ([ReceiptDetailId] IS NULL AND [IssueDetailId] IS NOT NULL AND [QuantityDelta] < 0)");
                    table.ForeignKey(
                        name: "FK_StockMovementRecords_IssueDetailRecords_IssueDetailId",
                        column: x => x.IssueDetailId,
                        principalTable: "IssueDetailRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockMovementRecords_ReceiptDetailRecords_ReceiptDetailId",
                        column: x => x.ReceiptDetailId,
                        principalTable: "ReceiptDetailRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockMovementRecords_StockSegmentRecords_StockSegmentId",
                        column: x => x.StockSegmentId,
                        principalTable: "StockSegmentRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "StockReservationRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    IssueDetailId = table.Column<int>(type: "int", nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false),
                    Active = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StockReservationRecords", x => x.Id);
                    table.CheckConstraint("CK_StockReservation_Valid", "[Quantity] > 0");
                    table.ForeignKey(
                        name: "FK_StockReservationRecords_IssueDetailRecords_IssueDetailId",
                        column: x => x.IssueDetailId,
                        principalTable: "IssueDetailRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AppUserRecords_Username",
                table: "AppUserRecords",
                column: "Username",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AuditLogRecords_ActorId",
                table: "AuditLogRecords",
                column: "ActorId");

            migrationBuilder.CreateIndex(
                name: "IX_IssueDetailRecords_IssueId",
                table: "IssueDetailRecords",
                column: "IssueId");

            migrationBuilder.CreateIndex(
                name: "IX_IssueDetailRecords_StockSegmentId",
                table: "IssueDetailRecords",
                column: "StockSegmentId");

            migrationBuilder.CreateIndex(
                name: "IX_IssueRecords_CreatedById",
                table: "IssueRecords",
                column: "CreatedById");

            migrationBuilder.CreateIndex(
                name: "IX_IssueRecords_DocumentNo",
                table: "IssueRecords",
                column: "DocumentNo",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_IssueRecords_RecipientId",
                table: "IssueRecords",
                column: "RecipientId");

            migrationBuilder.CreateIndex(
                name: "IX_IssueRecords_WarehouseId",
                table: "IssueRecords",
                column: "WarehouseId");

            migrationBuilder.CreateIndex(
                name: "IX_OrganizationRecords_Code",
                table: "OrganizationRecords",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_QualityDecisionRecords_DecidedById",
                table: "QualityDecisionRecords",
                column: "DecidedById");

            migrationBuilder.CreateIndex(
                name: "IX_QualityDecisionRecords_StockSegmentId",
                table: "QualityDecisionRecords",
                column: "StockSegmentId");

            migrationBuilder.CreateIndex(
                name: "IX_ReceiptDetailRecords_BatchId",
                table: "ReceiptDetailRecords",
                column: "BatchId");

            migrationBuilder.CreateIndex(
                name: "IX_ReceiptDetailRecords_ReceiptId",
                table: "ReceiptDetailRecords",
                column: "ReceiptId");

            migrationBuilder.CreateIndex(
                name: "IX_ReceiptRecords_CreatedById",
                table: "ReceiptRecords",
                column: "CreatedById");

            migrationBuilder.CreateIndex(
                name: "IX_ReceiptRecords_DocumentNo",
                table: "ReceiptRecords",
                column: "DocumentNo",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ReceiptRecords_SupplierId",
                table: "ReceiptRecords",
                column: "SupplierId");

            migrationBuilder.CreateIndex(
                name: "IX_ReceiptRecords_WarehouseId",
                table: "ReceiptRecords",
                column: "WarehouseId");

            migrationBuilder.CreateIndex(
                name: "IX_ShipmentDocumentLinkRecords_IssueId",
                table: "ShipmentDocumentLinkRecords",
                column: "IssueId");

            migrationBuilder.CreateIndex(
                name: "IX_ShipmentDocumentLinkRecords_ReceiptId",
                table: "ShipmentDocumentLinkRecords",
                column: "ReceiptId");

            migrationBuilder.CreateIndex(
                name: "IX_ShipmentDocumentLinkRecords_TradeShipmentId",
                table: "ShipmentDocumentLinkRecords",
                column: "TradeShipmentId");

            migrationBuilder.CreateIndex(
                name: "IX_StockMovementRecords_IssueDetailId",
                table: "StockMovementRecords",
                column: "IssueDetailId",
                unique: true,
                filter: "[IssueDetailId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_StockMovementRecords_ReceiptDetailId",
                table: "StockMovementRecords",
                column: "ReceiptDetailId",
                unique: true,
                filter: "[ReceiptDetailId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_StockMovementRecords_StockSegmentId",
                table: "StockMovementRecords",
                column: "StockSegmentId");

            migrationBuilder.CreateIndex(
                name: "IX_StockReservationRecords_IssueDetailId",
                table: "StockReservationRecords",
                column: "IssueDetailId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_StockSegmentRecords_ReceiptDetailId",
                table: "StockSegmentRecords",
                column: "ReceiptDetailId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_StockSegmentRecords_WarehouseId",
                table: "StockSegmentRecords",
                column: "WarehouseId");

            migrationBuilder.CreateIndex(
                name: "IX_TradeShipmentRecords_Code",
                table: "TradeShipmentRecords",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TradeShipmentRecords_PartnerId",
                table: "TradeShipmentRecords",
                column: "PartnerId");

            migrationBuilder.CreateIndex(
                name: "IX_VaccineBatchRecords_VaccineId_BatchNo",
                table: "VaccineBatchRecords",
                columns: new[] { "VaccineId", "BatchNo" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_VaccineRecords_Code",
                table: "VaccineRecords",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_VaccineRecords_ManufacturerId",
                table: "VaccineRecords",
                column: "ManufacturerId");

            migrationBuilder.CreateIndex(
                name: "IX_WarehouseAssignmentRecords_UserId_WarehouseId",
                table: "WarehouseAssignmentRecords",
                columns: new[] { "UserId", "WarehouseId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_WarehouseAssignmentRecords_WarehouseId",
                table: "WarehouseAssignmentRecords",
                column: "WarehouseId");

            migrationBuilder.CreateIndex(
                name: "IX_WarehouseRecords_Code",
                table: "WarehouseRecords",
                column: "Code",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AuditLogRecords");

            migrationBuilder.DropTable(
                name: "QualityDecisionRecords");

            migrationBuilder.DropTable(
                name: "ShipmentDocumentLinkRecords");

            migrationBuilder.DropTable(
                name: "StockMovementRecords");

            migrationBuilder.DropTable(
                name: "StockReservationRecords");

            migrationBuilder.DropTable(
                name: "WarehouseAssignmentRecords");

            migrationBuilder.DropTable(
                name: "TradeShipmentRecords");

            migrationBuilder.DropTable(
                name: "IssueDetailRecords");

            migrationBuilder.DropTable(
                name: "IssueRecords");

            migrationBuilder.DropTable(
                name: "StockSegmentRecords");

            migrationBuilder.DropTable(
                name: "ReceiptDetailRecords");

            migrationBuilder.DropTable(
                name: "ReceiptRecords");

            migrationBuilder.DropTable(
                name: "VaccineBatchRecords");

            migrationBuilder.DropTable(
                name: "AppUserRecords");

            migrationBuilder.DropTable(
                name: "WarehouseRecords");

            migrationBuilder.DropTable(
                name: "VaccineRecords");

            migrationBuilder.DropTable(
                name: "OrganizationRecords");
        }
    }
}
