using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VaxStock.Api.Contracts;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Models;
namespace VaxStock.Api.Controllers;

[ApiController, Route("api/v1/vaccines"), Authorize]
public sealed class VaccinesController(IMasterDataService service) : MasterDataControllerBase(service, MasterDataType.Vaccine)
{
    [HttpGet]
    public Task<IActionResult> List(int page = 1, int pageSize = 20, string? search = null, string sort = "code", int? manufacturerId = null, CancellationToken ct = default) =>
        ListCore(new(page, pageSize, search, sort, ManufacturerId: manufacturerId), ct);
    [HttpGet("{id:int:min(1)}")]
    public Task<IActionResult> Get(int id, CancellationToken ct) => GetCore(id, ct);
    [HttpPost, Authorize(Roles = "Admin")]
    public Task<IActionResult> Create(VaccineRequest request, CancellationToken ct) => SaveCore(null, Input(request), ct);
    [HttpPut("{id:int:min(1)}"), Authorize(Roles = "Admin")]
    public Task<IActionResult> Update(int id, VaccineRequest request, CancellationToken ct) => SaveCore(id, Input(request), ct);
    [HttpDelete("{id:int:min(1)}"), Authorize(Roles = "Admin")]
    public Task<IActionResult> Delete(int id, CancellationToken ct) => DeleteCore(id, ct);
    private static MasterDataInput Input(VaccineRequest x) => new(x.Code, x.Name, ManufacturerId: x.ManufacturerId,
        DosesPerVial: x.DosesPerVial, VialsPerPack: x.VialsPerPack, StorageMin: x.StorageMin, StorageMax: x.StorageMax);
}
