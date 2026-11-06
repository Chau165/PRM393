namespace VaxStock.Business.Models;

public enum MasterDataType { Warehouse, Organization, Vaccine }
public sealed record MasterDataInput(string Code, string Name, string? Country = null, string? Kind = null,
    int ManufacturerId = 0, int DosesPerVial = 0, int VialsPerPack = 0, decimal StorageMin = 0, decimal StorageMax = 0);
public sealed record MasterDataResult(int Id, string Code, string Name, string Version, string? Country, string? Kind,
    int ManufacturerId, string? ManufacturerName, int DosesPerVial, int VialsPerPack, decimal StorageMin, decimal StorageMax, bool StorageReviewRequired);
public sealed record MasterDataQuery(int Page = 1, int PageSize = 20, string? Search = null, string Sort = "code",
    string? Kind = null, string? Country = null, int? ManufacturerId = null);
