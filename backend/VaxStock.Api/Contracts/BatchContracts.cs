using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
namespace VaxStock.Api.Contracts;

public sealed record CreateBatchRequest([Range(1,int.MaxValue)] int VaccineId,[Required,StringLength(200)] string BatchNo,
    DateOnly? ManufacturedAt,[property:JsonRequired] DateOnly ExpiresAt);
public sealed record UpdateBatchRequest([property:JsonRequired] DateOnly? ManufacturedAt,[property:JsonRequired] DateOnly ExpiresAt);
public sealed record BatchResponse(int Id,int VaccineId,string VaccineCode,string VaccineName,string BatchNo,DateOnly? ManufacturedAt,
    DateOnly ExpiresAt,string ExpiryStatus,int DaysToExpiry,string Version);
public sealed record BatchWarehouseResponse(int WarehouseId,string WarehouseName,int OnHand,int Reserved,int Available);
public sealed record BatchMovementResponse(int Id,int StockSegmentId,int BatchId,int VaccineId,int WarehouseId,int QuantityDelta,
    string SourceType,int SourceId,int SourceDetailId,string DocumentNo,DateOnly EffectiveDate,DateTimeOffset PostedAt);
public sealed record BatchTraceResponse(BatchResponse Batch,IReadOnlyList<BatchWarehouseResponse> Warehouses,PageResponse<BatchMovementResponse> Movements);
