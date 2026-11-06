using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace VaxStock.DataAccess.Migrations
{
    /// <inheritdoc />
    public partial class IncidentAndDispositionFlow : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_StockSegmentRecords_WarehouseId",
                table: "StockSegmentRecords");

            migrationBuilder.DropCheckConstraint(
                name: "CK_StockMovement_Valid",
                table: "StockMovementRecords");

            migrationBuilder.AddColumn<int>(
                name: "StockDispositionDetailId",
                table: "StockMovementRecords",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "IncidentId",
                table: "QualityDecisionRecords",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "IncidentRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Code = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    WarehouseId = table.Column<int>(type: "int", nullable: false),
                    Kind = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    OccurredAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    ReportedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    ReportedById = table.Column<int>(type: "int", nullable: false),
                    ClosedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    ClosedById = table.Column<int>(type: "int", nullable: true),
                    Resolution = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_IncidentRecords", x => x.Id);
                    table.CheckConstraint("CK_Incident_Dates", "[ReportedAt] >= [OccurredAt] AND ([ClosedAt] IS NULL OR [ClosedAt] >= [ReportedAt])");
                    table.CheckConstraint("CK_Incident_Kind", "[Kind] IN ('TemperatureExcursion','PackagingDamage','Expiry','Recall','Other')");
                    table.CheckConstraint("CK_Incident_Valid", "([Status] IN ('Open','Investigating') AND [ClosedAt] IS NULL AND [ClosedById] IS NULL AND [Resolution] IS NULL) OR ([Status] = 'Closed' AND [ClosedAt] IS NOT NULL AND [ClosedById] IS NOT NULL AND [Resolution] IS NOT NULL AND LEN(LTRIM(RTRIM([Resolution]))) > 0)");
                    table.ForeignKey(
                        name: "FK_IncidentRecords_AppUserRecords_ClosedById",
                        column: x => x.ClosedById,
                        principalTable: "AppUserRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_IncidentRecords_AppUserRecords_ReportedById",
                        column: x => x.ReportedById,
                        principalTable: "AppUserRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_IncidentRecords_WarehouseRecords_WarehouseId",
                        column: x => x.WarehouseId,
                        principalTable: "WarehouseRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "IncidentStockSegmentRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    IncidentId = table.Column<int>(type: "int", nullable: false),
                    StockSegmentId = table.Column<int>(type: "int", nullable: false),
                    BlockedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    ReleasedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    ReleasedById = table.Column<int>(type: "int", nullable: true),
                    ReleaseReason = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_IncidentStockSegmentRecords", x => x.Id);
                    table.CheckConstraint("CK_IncidentStockSegment_Valid", "([ReleasedAt] IS NULL AND [ReleasedById] IS NULL AND [ReleaseReason] IS NULL) OR ([ReleasedAt] IS NOT NULL AND [ReleasedAt] >= [BlockedAt] AND [ReleasedById] IS NOT NULL AND [ReleaseReason] IS NOT NULL AND LEN(LTRIM(RTRIM([ReleaseReason]))) > 0)");
                    table.ForeignKey(
                        name: "FK_IncidentStockSegmentRecords_AppUserRecords_ReleasedById",
                        column: x => x.ReleasedById,
                        principalTable: "AppUserRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_IncidentStockSegmentRecords_IncidentRecords_IncidentId",
                        column: x => x.IncidentId,
                        principalTable: "IncidentRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_IncidentStockSegmentRecords_StockSegmentRecords_StockSegmentId",
                        column: x => x.StockSegmentId,
                        principalTable: "StockSegmentRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "StockDispositionRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DocumentNo = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    WarehouseId = table.Column<int>(type: "int", nullable: false),
                    Kind = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    SupplierId = table.Column<int>(type: "int", nullable: true),
                    IncidentId = table.Column<int>(type: "int", nullable: true),
                    Reason = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    DocumentDate = table.Column<DateOnly>(type: "date", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    CreatedById = table.Column<int>(type: "int", nullable: false),
                    ApprovedById = table.Column<int>(type: "int", nullable: true),
                    ApprovedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    PostedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StockDispositionRecords", x => x.Id);
                    table.CheckConstraint("CK_StockDisposition_Kind", "([Kind] = 'ReturnToSupplier' AND [SupplierId] IS NOT NULL) OR ([Kind] = 'Destroy' AND [SupplierId] IS NULL)");
                    table.CheckConstraint("CK_StockDisposition_Reason", "LEN(LTRIM(RTRIM([Reason]))) > 0");
                    table.CheckConstraint("CK_StockDisposition_Valid", "([Status] IN ('Draft','Cancelled') AND [ApprovedAt] IS NULL AND [ApprovedById] IS NULL AND [PostedAt] IS NULL) OR ([Status] = 'Approved' AND [ApprovedAt] IS NOT NULL AND [ApprovedById] IS NOT NULL AND [PostedAt] IS NULL) OR ([Status] = 'Posted' AND [ApprovedAt] IS NOT NULL AND [ApprovedById] IS NOT NULL AND [PostedAt] IS NOT NULL AND [PostedAt] >= [ApprovedAt])");
                    table.ForeignKey(
                        name: "FK_StockDispositionRecords_AppUserRecords_ApprovedById",
                        column: x => x.ApprovedById,
                        principalTable: "AppUserRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockDispositionRecords_AppUserRecords_CreatedById",
                        column: x => x.CreatedById,
                        principalTable: "AppUserRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockDispositionRecords_IncidentRecords_IncidentId",
                        column: x => x.IncidentId,
                        principalTable: "IncidentRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockDispositionRecords_OrganizationRecords_SupplierId",
                        column: x => x.SupplierId,
                        principalTable: "OrganizationRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockDispositionRecords_WarehouseRecords_WarehouseId",
                        column: x => x.WarehouseId,
                        principalTable: "WarehouseRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "StockDispositionDetailRecords",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    StockDispositionId = table.Column<int>(type: "int", nullable: false),
                    StockSegmentId = table.Column<int>(type: "int", nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StockDispositionDetailRecords", x => x.Id);
                    table.CheckConstraint("CK_StockDispositionDetail_Valid", "[Quantity] > 0");
                    table.ForeignKey(
                        name: "FK_StockDispositionDetailRecords_StockDispositionRecords_StockDispositionId",
                        column: x => x.StockDispositionId,
                        principalTable: "StockDispositionRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockDispositionDetailRecords_StockSegmentRecords_StockSegmentId",
                        column: x => x.StockSegmentId,
                        principalTable: "StockSegmentRecords",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_VaccineBatchRecords_ExpiresAt",
                table: "VaccineBatchRecords",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_StockSegmentRecords_WarehouseId_QualityStatus",
                table: "StockSegmentRecords",
                columns: new[] { "WarehouseId", "QualityStatus" });

            migrationBuilder.CreateIndex(
                name: "IX_StockMovementRecords_StockDispositionDetailId",
                table: "StockMovementRecords",
                column: "StockDispositionDetailId",
                unique: true,
                filter: "[StockDispositionDetailId] IS NOT NULL");

            migrationBuilder.AddCheckConstraint(
                name: "CK_StockMovement_Valid",
                table: "StockMovementRecords",
                sql: "([ReceiptDetailId] IS NOT NULL AND [IssueDetailId] IS NULL AND [StockDispositionDetailId] IS NULL AND [QuantityDelta] > 0) OR ([ReceiptDetailId] IS NULL AND [IssueDetailId] IS NOT NULL AND [StockDispositionDetailId] IS NULL AND [QuantityDelta] < 0) OR ([ReceiptDetailId] IS NULL AND [IssueDetailId] IS NULL AND [StockDispositionDetailId] IS NOT NULL AND [QuantityDelta] < 0)");

            migrationBuilder.CreateIndex(
                name: "IX_QualityDecisionRecords_IncidentId",
                table: "QualityDecisionRecords",
                column: "IncidentId");

            migrationBuilder.CreateIndex(
                name: "IX_IncidentRecords_ClosedById",
                table: "IncidentRecords",
                column: "ClosedById");

            migrationBuilder.CreateIndex(
                name: "IX_IncidentRecords_Code",
                table: "IncidentRecords",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_IncidentRecords_ReportedById",
                table: "IncidentRecords",
                column: "ReportedById");

            migrationBuilder.CreateIndex(
                name: "IX_IncidentRecords_WarehouseId_Status",
                table: "IncidentRecords",
                columns: new[] { "WarehouseId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_IncidentStockSegmentRecords_IncidentId_StockSegmentId",
                table: "IncidentStockSegmentRecords",
                columns: new[] { "IncidentId", "StockSegmentId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_IncidentStockSegmentRecords_ReleasedById",
                table: "IncidentStockSegmentRecords",
                column: "ReleasedById");

            migrationBuilder.CreateIndex(
                name: "IX_IncidentStockSegmentRecords_StockSegmentId_ReleasedAt",
                table: "IncidentStockSegmentRecords",
                columns: new[] { "StockSegmentId", "ReleasedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_StockDispositionDetailRecords_StockDispositionId_StockSegmentId",
                table: "StockDispositionDetailRecords",
                columns: new[] { "StockDispositionId", "StockSegmentId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_StockDispositionDetailRecords_StockSegmentId",
                table: "StockDispositionDetailRecords",
                column: "StockSegmentId");

            migrationBuilder.CreateIndex(
                name: "IX_StockDispositionRecords_ApprovedById",
                table: "StockDispositionRecords",
                column: "ApprovedById");

            migrationBuilder.CreateIndex(
                name: "IX_StockDispositionRecords_CreatedById",
                table: "StockDispositionRecords",
                column: "CreatedById");

            migrationBuilder.CreateIndex(
                name: "IX_StockDispositionRecords_DocumentNo",
                table: "StockDispositionRecords",
                column: "DocumentNo",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_StockDispositionRecords_IncidentId",
                table: "StockDispositionRecords",
                column: "IncidentId");

            migrationBuilder.CreateIndex(
                name: "IX_StockDispositionRecords_SupplierId",
                table: "StockDispositionRecords",
                column: "SupplierId");

            migrationBuilder.CreateIndex(
                name: "IX_StockDispositionRecords_WarehouseId",
                table: "StockDispositionRecords",
                column: "WarehouseId");

            migrationBuilder.AddForeignKey(
                name: "FK_QualityDecisionRecords_IncidentRecords_IncidentId",
                table: "QualityDecisionRecords",
                column: "IncidentId",
                principalTable: "IncidentRecords",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_StockMovementRecords_StockDispositionDetailRecords_StockDispositionDetailId",
                table: "StockMovementRecords",
                column: "StockDispositionDetailId",
                principalTable: "StockDispositionDetailRecords",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_QualityDecisionRecords_IncidentRecords_IncidentId",
                table: "QualityDecisionRecords");

            migrationBuilder.DropForeignKey(
                name: "FK_StockMovementRecords_StockDispositionDetailRecords_StockDispositionDetailId",
                table: "StockMovementRecords");

            migrationBuilder.DropTable(
                name: "IncidentStockSegmentRecords");

            migrationBuilder.DropTable(
                name: "StockDispositionDetailRecords");

            migrationBuilder.DropTable(
                name: "StockDispositionRecords");

            migrationBuilder.DropTable(
                name: "IncidentRecords");

            migrationBuilder.DropIndex(
                name: "IX_VaccineBatchRecords_ExpiresAt",
                table: "VaccineBatchRecords");

            migrationBuilder.DropIndex(
                name: "IX_StockSegmentRecords_WarehouseId_QualityStatus",
                table: "StockSegmentRecords");

            migrationBuilder.DropIndex(
                name: "IX_StockMovementRecords_StockDispositionDetailId",
                table: "StockMovementRecords");

            migrationBuilder.DropCheckConstraint(
                name: "CK_StockMovement_Valid",
                table: "StockMovementRecords");

            migrationBuilder.DropIndex(
                name: "IX_QualityDecisionRecords_IncidentId",
                table: "QualityDecisionRecords");

            migrationBuilder.DropColumn(
                name: "StockDispositionDetailId",
                table: "StockMovementRecords");

            migrationBuilder.DropColumn(
                name: "IncidentId",
                table: "QualityDecisionRecords");

            migrationBuilder.CreateIndex(
                name: "IX_StockSegmentRecords_WarehouseId",
                table: "StockSegmentRecords",
                column: "WarehouseId");

            migrationBuilder.AddCheckConstraint(
                name: "CK_StockMovement_Valid",
                table: "StockMovementRecords",
                sql: "([ReceiptDetailId] IS NOT NULL AND [IssueDetailId] IS NULL AND [QuantityDelta] > 0) OR ([ReceiptDetailId] IS NULL AND [IssueDetailId] IS NOT NULL AND [QuantityDelta] < 0)");
        }
    }
}
