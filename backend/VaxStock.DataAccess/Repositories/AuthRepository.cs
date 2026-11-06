using Microsoft.EntityFrameworkCore;
using VaxStock.DataAccess.Data;
using VaxStock.DataAccess.Entities;
using VaxStock.DataAccess.Interfaces;

namespace VaxStock.DataAccess.Repositories;

public sealed class AuthRepository(WarehouseDbContext db) : IAuthRepository
{
    public Task<AppUser?> FindByUsernameAsync(string username, CancellationToken ct) =>
        db.AppUserRecords.AsNoTracking().SingleOrDefaultAsync(x => x.Username == username, ct);

    public Task<AppUser?> FindByIdAsync(int id, CancellationToken ct) =>
        db.AppUserRecords.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct);

    public async Task<IReadOnlyList<Warehouse>> GetWarehousesAsync(int userId, bool admin, CancellationToken ct) =>
        await db.WarehouseRecords.AsNoTracking()
            .Where(w => admin || db.WarehouseAssignmentRecords.Any(a => a.UserId == userId && a.WarehouseId == w.Id))
            .OrderBy(w => w.Code).ToListAsync(ct);

    // One SQL statement performs compare-and-swap; a concurrent password change
    // or logout must not overwrite a newer credential/version.
    public async Task<bool> RevokeAsync(int userId, int expectedVersion, string? newPasswordHash, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var query = db.AppUserRecords.Where(u => u.Id == userId && u.AuthVersion == expectedVersion);
        var changed = newPasswordHash is null
            ? await query.ExecuteUpdateAsync(s => s.SetProperty(u => u.AuthVersion, u => u.AuthVersion + 1), ct)
            : await query.ExecuteUpdateAsync(s => s
                .SetProperty(u => u.PasswordHash, newPasswordHash)
                .SetProperty(u => u.AuthVersion, u => u.AuthVersion + 1), ct);
        if (changed != 1) return false;
        db.AuditLogRecords.Add(new AuditLog
        {
            ActorId = userId, EntityId = userId, EntityType = "AppUser",
            Action = newPasswordHash is null ? "LogoutAllSessions" : "ChangePassword",
            Details = "{\"sessionsRevoked\":true}", OccurredAt = DateTimeOffset.UtcNow
        });
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return true;
    }
}
