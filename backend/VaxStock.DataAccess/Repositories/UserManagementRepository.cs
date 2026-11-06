using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using VaxStock.DataAccess.Data;
using VaxStock.DataAccess.Entities;
using VaxStock.DataAccess.Interfaces;

namespace VaxStock.DataAccess.Repositories;

public sealed class UserManagementRepository(WarehouseDbContext db) : IUserManagementRepository
{
    public async Task<StorePage<AppUser>> ListUsersAsync(int page, int pageSize, string? search, string? role, string sort, CancellationToken ct)
    {
        var query = db.AppUserRecords.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(search)) query = query.Where(u => u.Username.Contains(search) || u.FullName.Contains(search));
        if (role is not null) query = query.Where(u => u.Role == role);
        var total = await query.CountAsync(ct);
        var sorted = sort == "id" ? query.OrderBy(u => u.Id) : query.OrderBy(u => u.Username).ThenBy(u => u.Id);
        return new(await sorted.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct), total);
    }
    public Task<AppUser?> GetUserAsync(int id, CancellationToken ct) => db.AppUserRecords.AsNoTracking().SingleOrDefaultAsync(u => u.Id == id, ct);

    // All admin mutations take the same SQL application lock. This serializes
    // cross-instance role changes and protects the last-admin invariant.
    // The actor is revalidated after acquiring the lock, not only at HTTP entry.
    private async Task<IDbContextTransaction> BeginAsync(int actorId, int actorVersion, CancellationToken ct)
    {
        var tx = await db.Database.BeginTransactionAsync(ct);
        try
        {
            await db.Database.ExecuteSqlRawAsync("DECLARE @r int; EXEC @r = sys.sp_getapplock @Resource=N'VaxStock.UserAdministration', @LockMode=N'Exclusive', @LockOwner=N'Transaction', @LockTimeout=10000; IF @r < 0 THROW 51010, 'User administration lock unavailable.', 1;", ct);
            if (!await db.AppUserRecords.AsNoTracking().AnyAsync(u => u.Id == actorId && u.AuthVersion == actorVersion && u.Role == "Admin", ct))
                throw new UserStoreException(UserStoreError.InvalidActor);
            return tx;
        }
        catch { await tx.DisposeAsync(); throw; }
    }
    private void Audit(int actorId, string action, string entityType, int entityId, object details) =>
        db.AuditLogRecords.Add(new AuditLog { ActorId = actorId, Action = action, EntityType = entityType, EntityId = entityId,
            Details = JsonSerializer.Serialize(details), OccurredAt = DateTimeOffset.UtcNow });
    private static void CheckVersion(byte[] actual, byte[] expected)
    {
        if (!actual.SequenceEqual(expected)) throw new UserStoreException(UserStoreError.Stale);
    }
    public async Task<AppUser> CreateUserAsync(int actorId, int actorVersion, AppUser user, CancellationToken ct)
    {
        await using var tx = await BeginAsync(actorId, actorVersion, ct);
        if (await db.AppUserRecords.AnyAsync(u => u.Username == user.Username, ct)) throw new UserStoreException(UserStoreError.Duplicate);
        db.AppUserRecords.Add(user);
        await db.SaveChangesAsync(ct);
        Audit(actorId, "CreateUser", "AppUser", user.Id, new { user.Username, user.FullName, user.Role });
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return user;
    }
    public async Task<AppUser> UpdateUserAsync(int actorId, int actorVersion, int id, byte[] version, string fullName, string role, CancellationToken ct)
    {
        await using var tx = await BeginAsync(actorId, actorVersion, ct);
        var user = await db.AppUserRecords.SingleOrDefaultAsync(u => u.Id == id, ct) ?? throw new UserStoreException(UserStoreError.NotFound);
        CheckVersion(user.RowVersion, version);
        if (user.Role == "Admin" && role != "Admin" && await db.AppUserRecords.CountAsync(u => u.Role == "Admin", ct) <= 1)
            throw new UserStoreException(UserStoreError.LastAdmin);
        var before = new { user.FullName, user.Role };
        if (user.Role != role) user.AuthVersion++;
        user.FullName = fullName; user.Role = role;
        // A successful PUT always produces a fresh ETag, including no-op PUTs.
        db.Entry(user).Property(u => u.FullName).IsModified = true;
        Audit(actorId, "UpdateUser", "AppUser", id, new { before, after = new { fullName, role } });
        await SaveAsync(ct); await tx.CommitAsync(ct); return user;
    }
    public async Task<AppUser> ResetPasswordAsync(int actorId, int actorVersion, int id, byte[] version, string hash, string reason, CancellationToken ct)
    {
        await using var tx = await BeginAsync(actorId, actorVersion, ct);
        var user = await db.AppUserRecords.SingleOrDefaultAsync(u => u.Id == id, ct) ?? throw new UserStoreException(UserStoreError.NotFound);
        CheckVersion(user.RowVersion, version);
        user.PasswordHash = hash; user.AuthVersion++;
        Audit(actorId, "ResetPassword", "AppUser", id, new { reason, sessionsRevoked = true });
        await SaveAsync(ct); await tx.CommitAsync(ct); return user;
    }
    private IQueryable<AssignmentRow> Assignments() => from a in db.WarehouseAssignmentRecords.AsNoTracking()
        join u in db.AppUserRecords on a.UserId equals u.Id
        join w in db.WarehouseRecords on a.WarehouseId equals w.Id
        select new AssignmentRow { Id = a.Id, UserId = a.UserId, Username = u.Username, WarehouseId = a.WarehouseId, WarehouseName = w.Name, RowVersion = a.RowVersion };
    public async Task<StorePage<AssignmentRow>> ListAssignmentsAsync(int page, int pageSize, int? userId, int? warehouseId, CancellationToken ct)
    {
        var query = Assignments();
        if (userId is not null) query = query.Where(a => a.UserId == userId);
        if (warehouseId is not null) query = query.Where(a => a.WarehouseId == warehouseId);
        return new(await query.OrderBy(a => a.Id).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct), await query.CountAsync(ct));
    }
    public Task<AssignmentRow?> GetAssignmentAsync(int id, CancellationToken ct) => Assignments().SingleOrDefaultAsync(a => a.Id == id, ct);
    public async Task<AssignmentRow> CreateAssignmentAsync(int actorId, int actorVersion, int userId, int warehouseId, CancellationToken ct)
    {
        await using var tx = await BeginAsync(actorId, actorVersion, ct);
        var user = await db.AppUserRecords.SingleOrDefaultAsync(u => u.Id == userId, ct);
        if (user is null || !await db.WarehouseRecords.AnyAsync(w => w.Id == warehouseId, ct)) throw new UserStoreException(UserStoreError.MissingReference);
        if (await db.WarehouseAssignmentRecords.AnyAsync(a => a.UserId == userId && a.WarehouseId == warehouseId, ct)) throw new UserStoreException(UserStoreError.Duplicate);
        var assignment = new WarehouseAssignment { UserId = userId, WarehouseId = warehouseId };
        db.Add(assignment);
        db.Entry(user).Property(u => u.FullName).IsModified = true;
        await SaveAsync(ct);
        Audit(actorId, "GrantWarehouse", "WarehouseAssignment", assignment.Id, new { userId, warehouseId });
        await db.SaveChangesAsync(ct);
        var result = (await GetAssignmentAsync(assignment.Id, ct))!;
        await tx.CommitAsync(ct);
        return result;
    }
    public async Task DeleteAssignmentAsync(int actorId, int actorVersion, int id, byte[] version, CancellationToken ct)
    {
        await using var tx = await BeginAsync(actorId, actorVersion, ct);
        var assignment = await db.WarehouseAssignmentRecords.SingleOrDefaultAsync(a => a.Id == id, ct) ?? throw new UserStoreException(UserStoreError.NotFound);
        CheckVersion(assignment.RowVersion, version);
        var user = await db.AppUserRecords.SingleAsync(u => u.Id == assignment.UserId, ct);
        db.Entry(user).Property(u => u.FullName).IsModified = true;
        db.Remove(assignment);
        Audit(actorId, "RevokeWarehouse", "WarehouseAssignment", id, new { assignment.UserId, assignment.WarehouseId });
        await SaveAsync(ct); await tx.CommitAsync(ct);
    }
    private async Task SaveAsync(CancellationToken ct)
    {
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateConcurrencyException) { throw new UserStoreException(UserStoreError.Stale); }
    }
}
