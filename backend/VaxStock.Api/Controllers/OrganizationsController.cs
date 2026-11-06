using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VaxStock.Api.Contracts;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Models;
namespace VaxStock.Api.Controllers;

[ApiController, Route("api/v1/organizations"), Authorize]
public sealed class OrganizationsController(IMasterDataService service) : MasterDataControllerBase(service, MasterDataType.Organization)
{
    [HttpGet]
    public Task<IActionResult> List(int page = 1, int pageSize = 20, string? search = null, string sort = "code", string? kind = null, string? country = null, CancellationToken ct = default) =>
        ListCore(new(page, pageSize, search, sort, kind, country), ct);
    [HttpGet("{id:int:min(1)}")]
    public Task<IActionResult> Get(int id, CancellationToken ct) => GetCore(id, ct);
    [HttpPost, Authorize(Roles = "Admin")]
    public Task<IActionResult> Create(OrganizationRequest request, CancellationToken ct) => SaveCore(null, new(request.Code, request.Name, request.Country, request.Kind), ct);
    [HttpPut("{id:int:min(1)}"), Authorize(Roles = "Admin")]
    public Task<IActionResult> Update(int id, OrganizationRequest request, CancellationToken ct) => SaveCore(id, new(request.Code, request.Name, request.Country, request.Kind), ct);
    [HttpDelete("{id:int:min(1)}"), Authorize(Roles = "Admin")]
    public Task<IActionResult> Delete(int id, CancellationToken ct) => DeleteCore(id, ct);
}
