using Microsoft.EntityFrameworkCore;
using VaxStock.Business.Interfaces;
using VaxStock.DataAccess.Data;
using VaxStock.DataAccess.Entities;
namespace VaxStock.Api.Infrastructure;

public static class DevelopmentSeeder
{
    // Explicit CLI command only. Never seeds or migrates on normal startup.
    public static async Task Run(IServiceProvider services, IConfiguration configuration)
    {
        var password = configuration["Seed:Password"];
        if (string.IsNullOrWhiteSpace(password) || password.Length is < 12 or > 128)
            throw new InvalidOperationException("Set Seed:Password to a development password of 12–128 characters.");
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<WarehouseDbContext>();
        var passwords = scope.ServiceProvider.GetRequiredService<IPasswordService>();
        await using var tx = await db.Database.BeginTransactionAsync();
        var whs = new List<Warehouse>();
        foreach (var (code, name) in new[] { ("AUTH-HCM", "Kho demo HCM"), ("AUTH-HN", "Kho demo Hà Nội") })
        {
            var warehouse = await db.WarehouseRecords.SingleOrDefaultAsync(w => w.Code == code);
            if (warehouse is null)
            {
                warehouse = new Warehouse { Code = code, Name = name };
                db.Add(warehouse);
                await db.SaveChangesAsync();
            }
            whs.Add(warehouse);
        }
        foreach (var (name, role, index) in new[] { ("admin", "Admin", 0), ("staff.hcm", "WarehouseStaff", 0), ("quality.hn", "QualityManager", 1) })
        {
            var user = await db.AppUserRecords.SingleOrDefaultAsync(u => u.Username == name);
            if (user is null)
            {
                user = new AppUser { Username = name, FullName = name, Role = role, PasswordHash = passwords.Hash(password) };
                db.Add(user);
                await db.SaveChangesAsync();
            }
            if (!await db.WarehouseAssignmentRecords.AnyAsync(a => a.UserId == user.Id && a.WarehouseId == whs[index].Id))
                db.Add(new WarehouseAssignment { UserId = user.Id, WarehouseId = whs[index].Id });
        }
        await db.SaveChangesAsync();
        await tx.CommitAsync();
    }
}
