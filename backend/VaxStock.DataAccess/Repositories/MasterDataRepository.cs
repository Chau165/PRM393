using System.Text.Json;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using VaxStock.DataAccess.Data;
using VaxStock.DataAccess.Entities;
using VaxStock.DataAccess.Interfaces;
namespace VaxStock.DataAccess.Repositories;

public sealed class MasterDataRepository(WarehouseDbContext db) : IMasterDataRepository
{
    private IQueryable<CatalogRow> Query(CatalogKind kind, int actorId) => kind switch
    {
        CatalogKind.Warehouse => db.WarehouseRecords.AsNoTracking()
            .Where(w => db.AppUserRecords.Any(u => u.Id == actorId && u.Role == "Admin") || db.WarehouseAssignmentRecords.Any(a => a.UserId == actorId && a.WarehouseId == w.Id))
            .Select(w => new CatalogRow { Id = w.Id, Code = w.Code, Name = w.Name, RowVersion = w.RowVersion }),
        CatalogKind.Organization => db.OrganizationRecords.AsNoTracking()
            .Select(o => new CatalogRow { Id = o.Id, Code = o.Code, Name = o.Name, Country = o.Country, Kind = o.Kind, RowVersion = o.RowVersion }),
        _ => from v in db.VaccineRecords.AsNoTracking() join o in db.OrganizationRecords on v.ManufacturerId equals o.Id
            select new CatalogRow { Id = v.Id, Code = v.Code, Name = v.Name, ManufacturerId = v.ManufacturerId, ManufacturerName = o.Name,
                DosesPerVial = v.DosesPerVial, VialsPerPack = v.VialsPerPack, StorageMin = v.StorageMin, StorageMax = v.StorageMax, RowVersion = v.RowVersion }
    };
    public async Task<StorePage<CatalogRow>> ListAsync(CatalogKind kind, int actorId, int page, int pageSize, string? search,
        string sort, string? organizationKind, string? country, int? manufacturerId, CancellationToken ct)
    {
        var query = Query(kind, actorId);
        if (!string.IsNullOrWhiteSpace(search)) query = query.Where(x => x.Code.Contains(search) || x.Name.Contains(search));
        if (organizationKind is not null) query = query.Where(x => x.Kind == organizationKind);
        if (country is not null) query = query.Where(x => x.Country == country);
        if (manufacturerId is not null) query = query.Where(x => x.ManufacturerId == manufacturerId);
        var total = await query.CountAsync(ct);
        var sorted = sort switch { "name" => query.OrderBy(x => x.Name).ThenBy(x => x.Id), "id" => query.OrderBy(x => x.Id), _ => query.OrderBy(x => x.Code).ThenBy(x => x.Id) };
        return new(await sorted.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct), total);
    }
    public Task<CatalogRow?> GetAsync(CatalogKind kind, int id, int actorId, CancellationToken ct) => Query(kind, actorId).SingleOrDefaultAsync(x => x.Id == id, ct);
    private async Task<IDbContextTransaction> Begin(int actorId, int actorVersion, CancellationToken ct)
    {
        var tx = await db.Database.BeginTransactionAsync(ct);
        try
        {
            // Share the administration lock with grants/role changes: deletion
            // cannot race a permission grant, and a waiting writer is revalidated.
            await db.Database.ExecuteSqlRawAsync("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=N'VaxStock.UserAdministration', @LockMode=N'Exclusive', @LockOwner=N'Transaction', @LockTimeout=10000; IF @r < 0 THROW 51010, 'Administration lock unavailable.', 1;", ct);
            if (!await db.AppUserRecords.AsNoTracking().AnyAsync(u => u.Id == actorId && u.Role == "Admin" && u.AuthVersion == actorVersion, ct)) throw new CatalogException(CatalogError.InvalidActor);
            return tx;
        }
        catch { await tx.DisposeAsync(); throw; }
    }
    private Task<bool> Used(CatalogKind kind, int id, CancellationToken ct) => kind switch
    {
        CatalogKind.Warehouse => db.WarehouseRecords.AnyAsync(w => w.Id == id && (
            db.WarehouseAssignmentRecords.Any(x => x.WarehouseId == id) || db.ReceiptRecords.Any(x => x.WarehouseId == id)
            || db.IssueRecords.Any(x => x.WarehouseId == id) || db.StockSegmentRecords.Any(x => x.WarehouseId == id)
            || db.IncidentRecords.Any(x => x.WarehouseId == id) || db.StockDispositionRecords.Any(x => x.WarehouseId == id)), ct),
        CatalogKind.Organization => db.OrganizationRecords.AnyAsync(o => o.Id == id && (
            db.VaccineRecords.Any(x => x.ManufacturerId == id) || db.ReceiptRecords.Any(x => x.SupplierId == id)
            || db.IssueRecords.Any(x => x.RecipientId == id) || db.StockDispositionRecords.Any(x => x.SupplierId == id)
            || db.TradeShipmentRecords.Any(x => x.PartnerId == id)), ct),
        _ => db.VaccineBatchRecords.AnyAsync(x => x.VaccineId == id, ct)
    };
    public async Task<CatalogRow> SaveAsync(CatalogKind kind, int actorId, int actorVersion, int? id, byte[]? version, CatalogInput input, CancellationToken ct)
    {
        await using var tx = await Begin(actorId, actorVersion, ct);
        var existing = id is null ? null : await GetAsync(kind, id.Value, actorId, ct) ?? throw new CatalogException(CatalogError.NotFound);
        if (existing is not null && !existing.RowVersion.SequenceEqual(version!)) throw new CatalogException(CatalogError.Stale);
        var used = id is not null && await Used(kind, id.Value, ct);
        if (used && existing!.Code != input.Code) throw new CatalogException(CatalogError.InUse);
        if (kind == CatalogKind.Organization && used && existing!.Kind != input.Kind) throw new CatalogException(CatalogError.InUse);
        if (kind == CatalogKind.Vaccine && used && (existing!.ManufacturerId != input.ManufacturerId || existing.DosesPerVial != input.DosesPerVial || existing.VialsPerPack != input.VialsPerPack))
            throw new CatalogException(CatalogError.InUse);
        if (kind == CatalogKind.Vaccine && !await db.OrganizationRecords.AnyAsync(o => o.Id == input.ManufacturerId && o.Kind == "Manufacturer", ct))
            throw new CatalogException(CatalogError.InvalidManufacturer);
        var duplicate = kind switch
        {
            CatalogKind.Warehouse => await db.WarehouseRecords.AnyAsync(x => x.Code == input.Code && x.Id != (id ?? 0), ct),
            CatalogKind.Organization => await db.OrganizationRecords.AnyAsync(x => x.Code == input.Code && x.Id != (id ?? 0), ct),
            _ => await db.VaccineRecords.AnyAsync(x => x.Code == input.Code && x.Id != (id ?? 0), ct)
        };
        if (duplicate) throw new CatalogException(CatalogError.Duplicate);
        object entity;
        if (kind == CatalogKind.Warehouse)
        {
            var w = id is null ? new Warehouse() : await db.WarehouseRecords.SingleAsync(x => x.Id == id, ct);
            w.Code = input.Code; w.Name = input.Name;
            entity = w;
        }
        else if (kind == CatalogKind.Organization)
        {
            var o = id is null ? new Organization() : await db.OrganizationRecords.SingleAsync(x => x.Id == id, ct);
            o.Code = input.Code; o.Name = input.Name; o.Country = input.Country!; o.Kind = input.Kind!;
            entity = o;
        }
        else
        {
            var v = id is null ? new Vaccine() : await db.VaccineRecords.SingleAsync(x => x.Id == id, ct);
            v.Code = input.Code; v.Name = input.Name; v.ManufacturerId = input.ManufacturerId;
            v.DosesPerVial = input.DosesPerVial; v.VialsPerPack = input.VialsPerPack; v.StorageMin = input.StorageMin; v.StorageMax = input.StorageMax;
            entity = v;
        }
        if (id is null) db.Add(entity);
        else
        {
            db.Entry(entity).Property("RowVersion").OriginalValue = version;
            db.Entry(entity).Property("Name").IsModified = true;
        }
        await Save(ct);
        var entityId = (int)db.Entry(entity).Property("Id").CurrentValue!;
        var review = kind == CatalogKind.Vaccine && existing is not null && (existing.StorageMin != input.StorageMin || existing.StorageMax != input.StorageMax);
        db.AuditLogRecords.Add(new AuditLog { ActorId = actorId, EntityType = kind.ToString(), EntityId = entityId,
            Action = (id is null ? "Create" : "Update") + kind,
            Details = JsonSerializer.Serialize(new { before = existing, after = input, storageReviewRequired = review }), OccurredAt = DateTimeOffset.UtcNow });
        await Save(ct);
        var result = (await GetAsync(kind, entityId, actorId, ct))!;
        await tx.CommitAsync(ct);
        return result with { StorageReviewRequired = review };
    }
    public async Task DeleteAsync(CatalogKind kind, int actorId, int actorVersion, int id, byte[] version, CancellationToken ct)
    {
        await using var tx = await Begin(actorId, actorVersion, ct);
        var existing = await GetAsync(kind, id, actorId, ct) ?? throw new CatalogException(CatalogError.NotFound);
        if (!existing.RowVersion.SequenceEqual(version)) throw new CatalogException(CatalogError.Stale);
        if (await Used(kind, id, ct)) throw new CatalogException(CatalogError.InUse);
        object entity = kind switch
        {
            CatalogKind.Warehouse => await db.WarehouseRecords.SingleAsync(x => x.Id == id, ct),
            CatalogKind.Organization => await db.OrganizationRecords.SingleAsync(x => x.Id == id, ct),
            _ => await db.VaccineRecords.SingleAsync(x => x.Id == id, ct)
        };
        db.Entry(entity).Property("RowVersion").OriginalValue = version;
        db.Remove(entity);
        db.AuditLogRecords.Add(new AuditLog { ActorId = actorId, EntityType = kind.ToString(), EntityId = id,
            Action = "Delete" + kind, Details = JsonSerializer.Serialize(existing), OccurredAt = DateTimeOffset.UtcNow });
        await Save(ct); await tx.CommitAsync(ct);
    }
    private async Task Save(CancellationToken ct)
    {
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateConcurrencyException) { throw new CatalogException(CatalogError.Stale); }
        catch (DbUpdateException e) when (e.InnerException is SqlException { Number: 2601 or 2627 }) { throw new CatalogException(CatalogError.Duplicate); }
        catch (DbUpdateException e) when (e.InnerException is SqlException { Number: 547 }) { throw new CatalogException(CatalogError.InUse); }
    }
}
