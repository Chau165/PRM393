namespace VaxStock.Business.Models;

public sealed record BatchQuery(int Page=1,int PageSize=20,int? VaccineId=null,string? Search=null,string? ExpiryStatus=null,DateOnly? ExpiresBefore=null,string Sort="expiresAt");
public sealed record CreateBatchCommand(AdminActor Actor,int VaccineId,string BatchNo,DateOnly? ManufacturedAt,DateOnly ExpiresAt);
public sealed record UpdateBatchCommand(AdminActor Actor,int Id,byte[] Version,DateOnly? ManufacturedAt,DateOnly ExpiresAt);
public sealed record BatchResult(int Id,int VaccineId,string VaccineCode,string VaccineName,string BatchNo,DateOnly? ManufacturedAt,DateOnly ExpiresAt,string ExpiryStatus,int DaysToExpiry,string Version);
public sealed record BatchWarehouseResult(int WarehouseId,string WarehouseName,int OnHand,int Reserved,int Available);
public sealed record BatchMovementResult(int Id,int StockSegmentId,int BatchId,int VaccineId,int WarehouseId,int QuantityDelta,
    string SourceType,int SourceId,int SourceDetailId,string DocumentNo,DateOnly EffectiveDate,DateTimeOffset PostedAt);
public sealed record BatchTraceResult(BatchResult Batch,IReadOnlyList<BatchWarehouseResult> Warehouses,PageResult<BatchMovementResult> Movements);

public static class VaccineCalendar
{
    public static DateOnly Today(TimeProvider clock)=>DateOnly.FromDateTime(clock.GetUtcNow().ToOffset(TimeSpan.FromHours(7)).DateTime);
    public static string ExpiryStatus(DateOnly expiresAt,DateOnly today)=>expiresAt<=today?"Expired":expiresAt.DayNumber-today.DayNumber<=30?"NearExpiry":"Valid";
}
