using VaxStock.Business.Models;
namespace VaxStock.Business.Interfaces;

public interface IMasterDataService
{
    Task<PageResult<MasterDataResult>> ListAsync(MasterDataType type, int actorId, MasterDataQuery query, CancellationToken ct);
    Task<MasterDataResult> GetAsync(MasterDataType type, int id, int actorId, CancellationToken ct);
    Task<MasterDataResult> SaveAsync(MasterDataType type, AdminActor actor, int? id, byte[]? version, MasterDataInput input, CancellationToken ct);
    Task DeleteAsync(MasterDataType type, AdminActor actor, int id, byte[] version, CancellationToken ct);
}
