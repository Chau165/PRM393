using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace VaxStock.DataAccess.Data;

public sealed class WarehouseDbContextFactory : IDesignTimeDbContextFactory<WarehouseDbContext>
{
    public WarehouseDbContext CreateDbContext(string[] args)
    {
        // Design-time only; environment override supports another instance/db.
        var connection = Environment.GetEnvironmentVariable("ConnectionStrings__Warehouse")
            ?? "Server=localhost;Database=VaxStockDev;Integrated Security=True;Encrypt=True;TrustServerCertificate=True";
        return new(new DbContextOptionsBuilder<WarehouseDbContext>().UseSqlServer(connection).Options);
    }
}
