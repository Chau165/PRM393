namespace VaxStock.DataAccess.Interfaces;

public sealed record BatchRow
{
    public int Id { get; init; }
    public int VaccineId { get; init; }
    public string VaccineCode { get; init; } = "";
    public string VaccineName { get; init; } = "";
    public string BatchNo { get; init; } = "";
    public DateOnly? ManufacturedAt { get; init; }
    public DateOnly ExpiresAt { get; init; }
    public byte[] RowVersion { get; init; } = [];
}
public sealed record BatchSegmentRow(int WarehouseId, string WarehouseName, int OnHand, int Reserved, bool Released, bool HasHold);
public sealed record BatchMovementRow
{
    public bool IsConsistent { get; init; }
    public int Id { get; init; }
    public int StockSegmentId { get; init; }
    public int BatchId { get; init; }
    public int VaccineId { get; init; }
    public int WarehouseId { get; init; }
    public int QuantityDelta { get; init; }
    public string SourceType { get; init; } = "";
    public int SourceId { get; init; }
    public int SourceDetailId { get; init; }
    public string DocumentNo { get; init; } = "";
    public DateOnly EffectiveDate { get; init; }
    public DateTimeOffset PostedAt { get; init; }
}
public sealed record BatchTraceRows(BatchRow Batch, IReadOnlyList<BatchSegmentRow> Segments, StorePage<BatchMovementRow> Movements);
public enum BatchStoreError { NotFound, MissingVaccine, Duplicate, MetadataConflict, Stale, InUse, InvalidActor, ForbiddenWarehouse, Integrity }
public sealed class BatchStoreException(BatchStoreError error, int? existingBatchId = null) : Exception(error.ToString())
{
    public BatchStoreError Error { get; } = error;
    public int? ExistingBatchId { get; } = existingBatchId;
}
public interface IBatchRepository
{
    Task<StorePage<BatchRow>> ListAsync(int page, int pageSize, int? vaccineId, string? search, string? expiryStatus, DateOnly? expiresBefore, string sort, DateOnly today, CancellationToken ct);
    Task<BatchRow?> GetAsync(int id, CancellationToken ct);
    Task<BatchRow> CreateAsync(int actorId, int authVersion, int vaccineId, string batchNo, DateOnly? manufacturedAt, DateOnly expiresAt, CancellationToken ct);
    Task<BatchRow> UpdateAsync(int actorId, int authVersion, int id, byte[] version, DateOnly? manufacturedAt, DateOnly expiresAt, CancellationToken ct);
    Task DeleteAsync(int actorId, int authVersion, int id, byte[] version, CancellationToken ct);
    Task<BatchTraceRows> TraceAsync(int actorId, int id, int? warehouseId, int page, int pageSize, CancellationToken ct);
}
