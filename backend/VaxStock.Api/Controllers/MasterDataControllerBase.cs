using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using VaxStock.Api.Contracts;
using VaxStock.Api.Infrastructure;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Models;
namespace VaxStock.Api.Controllers;

// Shared HTTP mapping only; no business rules or EF access in controllers.
public abstract class MasterDataControllerBase(IMasterDataService service, MasterDataType type) : ControllerBase
{
    protected AdminActor Actor => new(int.Parse(User.FindFirstValue("sub")!), int.Parse(User.FindFirstValue("authVersion")!));
    protected async Task<IActionResult> ListCore(MasterDataQuery query, CancellationToken ct)
    {
        var page = await service.ListAsync(type, Actor.Id, query, ct);
        return Ok(new PageResponse<object>(page.Items.Select(Map).ToArray(), page.Page, page.PageSize, page.TotalItems, page.TotalPages));
    }
    protected async Task<IActionResult> GetCore(int id, CancellationToken ct)
    {
        var result = await service.GetAsync(type, id, Actor.Id, ct); EntityVersions.Set(Response, result.Version); return Ok(Map(result));
    }
    protected async Task<IActionResult> SaveCore(int? id, MasterDataInput input, CancellationToken ct)
    {
        var result = await service.SaveAsync(type, Actor, id, id is null ? null : EntityVersions.Require(Request), input, ct);
        EntityVersions.Set(Response, result.Version);
        return id is null ? CreatedAtAction("Get", new { id = result.Id }, Map(result)) : Ok(Map(result));
    }
    protected async Task<IActionResult> DeleteCore(int id, CancellationToken ct)
    {
        await service.DeleteAsync(type, Actor, id, EntityVersions.Require(Request), ct); return NoContent();
    }
    private object Map(MasterDataResult x) => type switch
    {
        MasterDataType.Warehouse => new WarehouseResponse(x.Id, x.Code, x.Name, x.Version),
        MasterDataType.Organization => new OrganizationResponse(x.Id, x.Code, x.Name, x.Country!, x.Kind!, x.Version),
        _ => new VaccineResponse(x.Id, x.Code, x.Name, x.ManufacturerId, x.ManufacturerName!, x.DosesPerVial, x.VialsPerPack, x.StorageMin, x.StorageMax, x.Version, x.StorageReviewRequired)
    };
}
