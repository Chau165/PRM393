using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace VaxStock.DataAccess.Migrations
{
    /// <inheritdoc />
    public partial class MasterDataConcurrency : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<byte[]>(
                name: "RowVersion",
                table: "WarehouseRecords",
                type: "rowversion",
                rowVersion: true,
                nullable: false,
                defaultValue: new byte[0]);

            migrationBuilder.AddColumn<byte[]>(
                name: "RowVersion",
                table: "VaccineRecords",
                type: "rowversion",
                rowVersion: true,
                nullable: false,
                defaultValue: new byte[0]);

            migrationBuilder.AddColumn<byte[]>(
                name: "RowVersion",
                table: "OrganizationRecords",
                type: "rowversion",
                rowVersion: true,
                nullable: false,
                defaultValue: new byte[0]);

            migrationBuilder.AddCheckConstraint(
                name: "CK_Organization_Kind",
                table: "OrganizationRecords",
                sql: "[Kind] IN ('Manufacturer','Supplier','Recipient','Carrier')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_Organization_Kind",
                table: "OrganizationRecords");

            migrationBuilder.DropColumn(
                name: "RowVersion",
                table: "WarehouseRecords");

            migrationBuilder.DropColumn(
                name: "RowVersion",
                table: "VaccineRecords");

            migrationBuilder.DropColumn(
                name: "RowVersion",
                table: "OrganizationRecords");
        }
    }
}
