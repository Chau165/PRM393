using System.Data;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using VaxStock.DataAccess.Data;
using VaxStock.DataAccess.Entities;
using VaxStock.DataAccess.Interfaces;
namespace VaxStock.DataAccess.Repositories;

public sealed class BatchRepository(WarehouseDbContext db) : IBatchRepository
{
    private IQueryable<BatchRow> Query() => from b in db.VaccineBatchRecords.AsNoTracking()
        join v in db.VaccineRecords on b.VaccineId equals v.Id
        select new BatchRow { Id=b.Id, VaccineId=b.VaccineId, VaccineCode=v.Code, VaccineName=v.Name,
            BatchNo=b.BatchNo, ManufacturedAt=b.ManufacturedAt, ExpiresAt=b.ExpiresAt, RowVersion=b.RowVersion };
    public async Task<StorePage<BatchRow>> ListAsync(int page, int pageSize, int? vaccineId, string? search, string? expiryStatus, DateOnly? expiresBefore, string sort, DateOnly today, CancellationToken ct)
    {
        var query=Query();
        if (vaccineId is not null) query=query.Where(x=>x.VaccineId==vaccineId);
        if (!string.IsNullOrWhiteSpace(search)) query=query.Where(x=>x.BatchNo.Contains(search)||x.VaccineCode.Contains(search)||x.VaccineName.Contains(search));
        if (expiresBefore is not null) query=query.Where(x=>x.ExpiresAt<expiresBefore);
        var threshold=today.AddDays(30);
        query=expiryStatus switch { "Expired"=>query.Where(x=>x.ExpiresAt<=today), "NearExpiry"=>query.Where(x=>x.ExpiresAt>today&&x.ExpiresAt<=threshold), "Valid"=>query.Where(x=>x.ExpiresAt>threshold), _=>query };
        var total=await query.CountAsync(ct);
        var sorted=sort switch { "batchNo"=>query.OrderBy(x=>x.BatchNo).ThenBy(x=>x.Id), "id"=>query.OrderBy(x=>x.Id), _=>query.OrderBy(x=>x.ExpiresAt).ThenBy(x=>x.Id) };
        return new(await sorted.Skip((page-1)*pageSize).Take(pageSize).ToListAsync(ct),total);
    }
    public Task<BatchRow?> GetAsync(int id,CancellationToken ct)=>Query().SingleOrDefaultAsync(x=>x.Id==id,ct);
    private async Task<IDbContextTransaction> Begin(int actorId,int authVersion,bool adminOnly,CancellationToken ct)
    {
        var tx=await db.Database.BeginTransactionAsync(ct);
        try
        {
            // Same lock as catalog metadata edits: creating a batch cannot race
            // a manufacturer/packaging edit that must be locked after first use.
            await db.Database.ExecuteSqlRawAsync("DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=N'VaxStock.UserAdministration', @LockMode=N'Exclusive', @LockOwner=N'Transaction', @LockTimeout=10000; IF @r<0 THROW 51010, 'Administration lock unavailable.', 1;",ct);
            if (!await db.AppUserRecords.AsNoTracking().AnyAsync(u=>u.Id==actorId&&u.AuthVersion==authVersion&&(!adminOnly||u.Role=="Admin"),ct))
                throw new BatchStoreException(BatchStoreError.InvalidActor);
            return tx;
        }
        catch { await tx.DisposeAsync(); throw; }
    }
    private void Audit(int actorId,string action,int id,object details)=>db.AuditLogRecords.Add(new AuditLog
    { ActorId=actorId,Action=action,EntityType="VaccineBatch",EntityId=id,Details=JsonSerializer.Serialize(details),OccurredAt=DateTimeOffset.UtcNow });
    public async Task<BatchRow> CreateAsync(int actorId,int authVersion,int vaccineId,string batchNo,DateOnly? manufacturedAt,DateOnly expiresAt,CancellationToken ct)
    {
        await using var tx=await Begin(actorId,authVersion,false,ct);
        if (!await db.VaccineRecords.AnyAsync(v=>v.Id==vaccineId,ct)) throw new BatchStoreException(BatchStoreError.MissingVaccine);
        var existing=await db.VaccineBatchRecords.AsNoTracking().SingleOrDefaultAsync(b=>b.VaccineId==vaccineId&&b.BatchNo==batchNo,ct);
        if (existing is not null) throw new BatchStoreException(existing.ManufacturedAt==manufacturedAt&&existing.ExpiresAt==expiresAt?BatchStoreError.Duplicate:BatchStoreError.MetadataConflict,existing.Id);
        var batch=new VaccineBatch { VaccineId=vaccineId,BatchNo=batchNo,ManufacturedAt=manufacturedAt,ExpiresAt=expiresAt };
        db.Add(batch); await db.SaveChangesAsync(ct);
        Audit(actorId,"CreateBatch",batch.Id,new { vaccineId,batchNo,manufacturedAt,expiresAt });
        await db.SaveChangesAsync(ct);
        var result=(await GetAsync(batch.Id,ct))!;
        await tx.CommitAsync(ct); return result;
    }
    public async Task<BatchRow> UpdateAsync(int actorId,int authVersion,int id,byte[] version,DateOnly? manufacturedAt,DateOnly expiresAt,CancellationToken ct)
    {
        await using var tx=await Begin(actorId,authVersion,true,ct);
        var batch=await db.VaccineBatchRecords.SingleOrDefaultAsync(b=>b.Id==id,ct)??throw new BatchStoreException(BatchStoreError.NotFound);
        CheckVersion(batch.RowVersion,version);
        if (await db.ReceiptDetailRecords.AnyAsync(d=>d.BatchId==id,ct)) throw new BatchStoreException(BatchStoreError.InUse);
        var before=new { batch.ManufacturedAt,batch.ExpiresAt };
        batch.ManufacturedAt=manufacturedAt;batch.ExpiresAt=expiresAt;
        db.Entry(batch).Property(x=>x.ExpiresAt).IsModified=true;
        Audit(actorId,"UpdateBatch",id,new { before,after=new { manufacturedAt,expiresAt } });
        await Save(ct);var result=(await GetAsync(id,ct))!;await tx.CommitAsync(ct);return result;
    }
    public async Task DeleteAsync(int actorId,int authVersion,int id,byte[] version,CancellationToken ct)
    {
        await using var tx=await Begin(actorId,authVersion,true,ct);
        var batch=await db.VaccineBatchRecords.SingleOrDefaultAsync(b=>b.Id==id,ct)??throw new BatchStoreException(BatchStoreError.NotFound);
        CheckVersion(batch.RowVersion,version);
        if (await db.ReceiptDetailRecords.AnyAsync(d=>d.BatchId==id,ct)) throw new BatchStoreException(BatchStoreError.InUse);
        db.Remove(batch);Audit(actorId,"DeleteBatch",id,new { batch.VaccineId,batch.BatchNo,batch.ManufacturedAt,batch.ExpiresAt });
        await Save(ct);await tx.CommitAsync(ct);
    }
    private static void CheckVersion(byte[] actual,byte[] expected) { if (!actual.SequenceEqual(expected)) throw new BatchStoreException(BatchStoreError.Stale); }
    private async Task Save(CancellationToken ct)
    {
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateConcurrencyException) { throw new BatchStoreException(BatchStoreError.Stale); }
        catch (DbUpdateException e) when (e.InnerException is Microsoft.Data.SqlClient.SqlException { Number:547 }) { throw new BatchStoreException(BatchStoreError.InUse); }
    }
    public async Task<BatchTraceRows> TraceAsync(int actorId,int id,int? warehouseId,int page,int pageSize,CancellationToken ct)
    {
        await using var tx=await db.Database.BeginTransactionAsync(IsolationLevel.Serializable,ct);
        var batch=await GetAsync(id,ct)??throw new BatchStoreException(BatchStoreError.NotFound);
        var allowed=db.WarehouseRecords.Where(w=>db.AppUserRecords.Any(u=>u.Id==actorId&&u.Role=="Admin")||db.WarehouseAssignmentRecords.Any(a=>a.UserId==actorId&&a.WarehouseId==w.Id));
        if (warehouseId is not null)
        {
            if (!await allowed.AnyAsync(w=>w.Id==warehouseId,ct)) throw new BatchStoreException(BatchStoreError.ForbiddenWarehouse);
            allowed=allowed.Where(w=>w.Id==warehouseId);
        }
        var segments=from s in db.StockSegmentRecords.AsNoTracking()
            join d in db.ReceiptDetailRecords on s.ReceiptDetailId equals d.Id
            join w in allowed on s.WarehouseId equals w.Id
            where d.BatchId==id
            select new { s.Id,s.ReceiptDetailId,WarehouseId=w.Id,WarehouseName=w.Name,s.QualityStatus };
        var totals=await segments.Select(s=>new BatchSegmentRow(s.WarehouseId,s.WarehouseName,
            db.StockMovementRecords.Where(m=>m.StockSegmentId==s.Id).Sum(m=>(int?)m.QuantityDelta)??0,
            (from r in db.StockReservationRecords join l in db.IssueDetailRecords on r.IssueDetailId equals l.Id
                join issue in db.IssueRecords on l.IssueId equals issue.Id
                where r.Active&&l.StockSegmentId==s.Id&&issue.Status=="Draft"&&issue.WarehouseId==s.WarehouseId
                select (int?)r.Quantity).Sum()??0,
            s.QualityStatus=="Released",db.IncidentStockSegmentRecords.Any(h=>h.StockSegmentId==s.Id&&h.ReleasedAt==null))).ToListAsync(ct);

        var movements=from m in db.StockMovementRecords.AsNoTracking()
            join s in segments on m.StockSegmentId equals s.Id
            join rd in db.ReceiptDetailRecords on m.ReceiptDetailId equals rd.Id into receiptLines
            from rd in receiptLines.DefaultIfEmpty()
            join receipt in db.ReceiptRecords on rd.ReceiptId equals receipt.Id into receipts
            from receipt in receipts.DefaultIfEmpty()
            join line in db.IssueDetailRecords on m.IssueDetailId equals line.Id into issueLines
            from line in issueLines.DefaultIfEmpty()
            join issue in db.IssueRecords on line.IssueId equals issue.Id into issues
            from issue in issues.DefaultIfEmpty()
            join dl in db.StockDispositionDetailRecords on m.StockDispositionDetailId equals dl.Id into dispositionLines
            from dl in dispositionLines.DefaultIfEmpty()
            join disposition in db.StockDispositionRecords on dl.StockDispositionId equals disposition.Id into dispositions
            from disposition in dispositions.DefaultIfEmpty()
            select new BatchMovementRow { Id=m.Id,StockSegmentId=m.StockSegmentId,BatchId=id,VaccineId=batch.VaccineId,WarehouseId=s.WarehouseId,
                IsConsistent=(m.ReceiptDetailId!=null&&rd.Id==s.ReceiptDetailId&&receipt.WarehouseId==s.WarehouseId&&receipt.Status=="Posted"&&m.QuantityDelta==rd.Quantity)
                    ||(m.IssueDetailId!=null&&line.StockSegmentId==s.Id&&issue.WarehouseId==s.WarehouseId&&issue.Status=="Posted"&&m.QuantityDelta==-line.Quantity)
                    ||(m.StockDispositionDetailId!=null&&dl.StockSegmentId==s.Id&&disposition.WarehouseId==s.WarehouseId&&disposition.Status=="Posted"&&m.QuantityDelta==-dl.Quantity),
                QuantityDelta=m.QuantityDelta,SourceType=m.ReceiptDetailId!=null?"Receipt":m.IssueDetailId!=null?"Issue":"StockDisposition",
                SourceId=m.ReceiptDetailId!=null?receipt.Id:m.IssueDetailId!=null?issue.Id:disposition.Id,
                SourceDetailId=m.ReceiptDetailId??m.IssueDetailId??m.StockDispositionDetailId!.Value,
                DocumentNo=m.ReceiptDetailId!=null?receipt.DocumentNo:m.IssueDetailId!=null?issue.DocumentNo:disposition.DocumentNo,
                EffectiveDate=m.EffectiveDate,PostedAt=m.PostedAt };
        if (await movements.AnyAsync(m=>!m.IsConsistent,ct)) throw new BatchStoreException(BatchStoreError.Integrity);
        var count=await movements.CountAsync(ct);
        var items=await movements.OrderByDescending(m=>m.PostedAt).ThenByDescending(m=>m.Id).Skip((page-1)*pageSize).Take(pageSize).ToListAsync(ct);
        await tx.CommitAsync(ct);return new(batch,totals,new(items,count));
    }
}
