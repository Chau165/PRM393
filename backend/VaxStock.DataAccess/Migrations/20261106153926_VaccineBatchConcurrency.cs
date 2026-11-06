using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace VaxStock.DataAccess.Migrations
{
    /// <inheritdoc />
    public partial class VaccineBatchConcurrency : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<byte[]>(
                name: "RowVersion",
                table: "VaccineBatchRecords",
                type: "rowversion",
                rowVersion: true,
                nullable: false,
                defaultValue: new byte[0]);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RowVersion",
                table: "VaccineBatchRecords");
        }
    }
}
