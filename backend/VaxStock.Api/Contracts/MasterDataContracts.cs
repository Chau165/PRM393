using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
namespace VaxStock.Api.Contracts;

public sealed record WarehouseRequest([Required, StringLength(200)] string Code, [Required, StringLength(200)] string Name);
public sealed record OrganizationRequest([Required, StringLength(200)] string Code, [Required, StringLength(200)] string Name,
    [Required, StringLength(2)] string Country, [Required] string Kind);
public sealed record VaccineRequest([Required, StringLength(200)] string Code, [Required, StringLength(200)] string Name,
    [Range(1,int.MaxValue)] int ManufacturerId, [Range(1,int.MaxValue)] int DosesPerVial, [Range(1,int.MaxValue)] int VialsPerPack,
    [property: JsonRequired] decimal StorageMin, [property: JsonRequired] decimal StorageMax);
public sealed record OrganizationResponse(int Id, string Code, string Name, string Country, string Kind, string Version);
public sealed record VaccineResponse(int Id, string Code, string Name, int ManufacturerId, string ManufacturerName,
    int DosesPerVial, int VialsPerPack, decimal StorageMin, decimal StorageMax, string Version, bool StorageReviewRequired);
