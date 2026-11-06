using VaxStock.Business.Models;
namespace VaxStock.Business.Interfaces;

public interface IBatchService
{
    Task<PageResult<BatchResult>> ListAsync(BatchQuery query,CancellationToken ct);
    Task<BatchResult> GetAsync(int id,CancellationToken ct);
    Task<BatchResult> CreateAsync(CreateBatchCommand command,CancellationToken ct);
    Task<BatchResult> UpdateAsync(UpdateBatchCommand command,CancellationToken ct);
    Task DeleteAsync(AdminActor actor,int id,byte[] version,CancellationToken ct);
    Task<BatchTraceResult> TraceAsync(int actorId,int id,int? warehouseId,int page,int pageSize,CancellationToken ct);
}
