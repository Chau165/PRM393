using VaxStock.Business.Exceptions;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Models;
using VaxStock.DataAccess.Interfaces;
namespace VaxStock.Business.Services;

public sealed class BatchService(IBatchRepository store,TimeProvider clock):IBatchService
{
    public async Task<PageResult<BatchResult>> ListAsync(BatchQuery q,CancellationToken ct)
    {
        Page(q.Page,q.PageSize);
        if (q.VaccineId<=0||q.Search?.Length>200||q.Sort is not ("expiresAt" or "batchNo" or "id")
            ||q.ExpiryStatus is not (null or "Expired" or "NearExpiry" or "Valid")) throw Bad("Filter hoặc sort không hợp lệ.");
        var today=VaccineCalendar.Today(clock);
        var result=await store.ListAsync(q.Page,q.PageSize,q.VaccineId,q.Search?.Trim(),q.ExpiryStatus,q.ExpiresBefore,q.Sort,today,ct);
        return new(result.Items.Select(x=>Map(x,today)).ToArray(),q.Page,q.PageSize,result.Total);
    }
    public async Task<BatchResult> GetAsync(int id,CancellationToken ct)=>Map(await store.GetAsync(id,ct)??throw new ManagementException("BATCH_NOT_FOUND","Không tìm thấy lô vaccine.",404),VaccineCalendar.Today(clock));
    public Task<BatchResult> CreateAsync(CreateBatchCommand c,CancellationToken ct)=>Translate(async()=>
    {
        Dates(c.ManufacturedAt,c.ExpiresAt);
        if (c.VaccineId<=0||string.IsNullOrWhiteSpace(c.BatchNo)||c.BatchNo.Length>200) throw Bad("Vaccine và số lô phải hợp lệ.");
        return Map(await store.CreateAsync(c.Actor.Id,c.Actor.AuthVersion,c.VaccineId,c.BatchNo.Trim(),c.ManufacturedAt,c.ExpiresAt,ct),VaccineCalendar.Today(clock));
    });
    public Task<BatchResult> UpdateAsync(UpdateBatchCommand c,CancellationToken ct)=>Translate(async()=>
    {
        Dates(c.ManufacturedAt,c.ExpiresAt);
        return Map(await store.UpdateAsync(c.Actor.Id,c.Actor.AuthVersion,c.Id,c.Version,c.ManufacturedAt,c.ExpiresAt,ct),VaccineCalendar.Today(clock));
    });
    public async Task DeleteAsync(AdminActor actor,int id,byte[] version,CancellationToken ct)=>
        await Translate(async()=>{await store.DeleteAsync(actor.Id,actor.AuthVersion,id,version,ct);return true;});
    public Task<BatchTraceResult> TraceAsync(int actorId,int id,int? warehouseId,int page,int pageSize,CancellationToken ct)=>Translate(async()=>
    {
        Page(page,pageSize);if (warehouseId<=0) throw Bad("warehouseId phải lớn hơn 0.");
        var today=VaccineCalendar.Today(clock);
        var trace=await store.TraceAsync(actorId,id,warehouseId,page,pageSize,ct);
        if (trace.Segments.Any(s=>s.OnHand<0||s.Reserved<0||s.Reserved>s.OnHand)) throw new ManagementException("INVENTORY_INTEGRITY_ERROR","Số dư tồn hoặc giữ hàng không nhất quán.",409);
        var warehouses=trace.Segments.GroupBy(s=>new {s.WarehouseId,s.WarehouseName}).OrderBy(g=>g.Key.WarehouseId)
            .Select(g=>new BatchWarehouseResult(g.Key.WarehouseId,g.Key.WarehouseName,g.Sum(s=>s.OnHand),g.Sum(s=>s.Reserved),
                g.Sum(s=>s.Released&&!s.HasHold&&trace.Batch.ExpiresAt>today?s.OnHand-s.Reserved:0))).ToArray();
        var movements=trace.Movements.Items.Select(m=>new BatchMovementResult(m.Id,m.StockSegmentId,m.BatchId,m.VaccineId,m.WarehouseId,
            m.QuantityDelta,m.SourceType,m.SourceId,m.SourceDetailId,m.DocumentNo,m.EffectiveDate,m.PostedAt)).ToArray();
        return new BatchTraceResult(Map(trace.Batch,today),warehouses,new(movements,page,pageSize,trace.Movements.Total));
    });
    private static BatchResult Map(BatchRow b,DateOnly today)=>new(b.Id,b.VaccineId,b.VaccineCode,b.VaccineName,b.BatchNo,b.ManufacturedAt,b.ExpiresAt,
        VaccineCalendar.ExpiryStatus(b.ExpiresAt,today),b.ExpiresAt.DayNumber-today.DayNumber,Convert.ToBase64String(b.RowVersion));
    private static void Dates(DateOnly? manufacturedAt,DateOnly expiresAt)
    {
        if (expiresAt==default||manufacturedAt>expiresAt) throw Bad("Hạn dùng bắt buộc và ngày sản xuất không được sau hạn dùng.");
    }
    private static void Page(int page,int pageSize)
    {
        if (page is <1 or >1_000_000||pageSize is <1 or >100) throw Bad("Phân trang không hợp lệ.");
    }
    private static ManagementException Bad(string detail)=>new("VALIDATION_ERROR",detail,400);
    private static async Task<T> Translate<T>(Func<Task<T>> operation)
    {
        try{return await operation();}
        catch(BatchStoreException e)
        {
            throw e.Error switch
            {
                BatchStoreError.NotFound=>new ManagementException("BATCH_NOT_FOUND","Không tìm thấy lô vaccine.",404),
                BatchStoreError.MissingVaccine=>new ManagementException("INVALID_VACCINE","Vaccine không tồn tại.",400),
                BatchStoreError.Duplicate=>new ManagementException("DUPLICATE_CODE","Lô đã tồn tại với cùng thông tin. Hãy chọn lô hiện có.",409,e.ExistingBatchId),
                BatchStoreError.MetadataConflict=>new ManagementException("BATCH_METADATA_CONFLICT","Số lô đã tồn tại nhưng ngày sản xuất hoặc hạn dùng khác.",409,e.ExistingBatchId),
                BatchStoreError.Stale=>new ManagementException("CONCURRENCY_CONFLICT","Lô đã thay đổi. Vui lòng tải lại.",412),
                BatchStoreError.InUse=>new ManagementException("RESOURCE_IN_USE","Lô đã có chi tiết nhập, không thể sửa hoặc xóa.",409),
                BatchStoreError.ForbiddenWarehouse=>new ManagementException("WAREHOUSE_ACCESS_DENIED","Không có quyền truy xuất kho được chọn.",403),
                BatchStoreError.Integrity=>new ManagementException("INVENTORY_INTEGRITY_ERROR","Chứng từ nguồn và biến động tồn không nhất quán.",409),
                _=>new ManagementException("UNAUTHENTICATED","Phiên làm việc đã thay đổi. Vui lòng đăng nhập lại.",401)
            };
        }
    }
}
