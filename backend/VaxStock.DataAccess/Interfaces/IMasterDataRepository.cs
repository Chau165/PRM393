using VaxStock.DataAccess.Entities;
namespace VaxStock.DataAccess.Interfaces;

public enum CatalogKind { Warehouse, Organization, Vaccine }
public sealed record CatalogInput(string Code, string Name, string? Country = null, string? Kind = null,
    int ManufacturerId = 0, int DosesPerVial = 0, int VialsPerPack = 0, decimal StorageMin = 0, decimal StorageMax = 0);
public sealed record CatalogRow
{
    public int Id { get; init; }
    public string Code { get; init; } = "";
    public string Name { get; init; } = "";
    public string? Country { get; init; }
    public string? Kind { get; init; }
    public int ManufacturerId { get; init; }
    public string? ManufacturerName { get; init; }
    public int DosesPerVial { get; init; }
    public int VialsPerPack { get; init; }
    public decimal StorageMin { get; init; }
    public decimal StorageMax { get; init; }
    public byte[] RowVersion { get; init; } = [];
    public bool StorageReviewRequired { get; init; }
}
public enum CatalogError { NotFound, Duplicate, Stale, InUse, InvalidManufacturer, InvalidActor }
public sealed class CatalogException(CatalogError error) : Exception(error.ToString())
{
    public CatalogError Error { get; } = error;
}
public interface IMasterDataRepository
{
    Task<StorePage<CatalogRow>> ListAsync(CatalogKind kind, int actorId, int page, int pageSize, string? search,
        string sort, string? organizationKind, string? country, int? manufacturerId, CancellationToken ct);
    Task<CatalogRow?> GetAsync(CatalogKind kind, int id, int actorId, CancellationToken ct);
    Task<CatalogRow> SaveAsync(CatalogKind kind, int actorId, int actorVersion, int? id, byte[]? version, CatalogInput input, CancellationToken ct);
    Task DeleteAsync(CatalogKind kind, int actorId, int actorVersion, int id, byte[] version, CancellationToken ct);
}
