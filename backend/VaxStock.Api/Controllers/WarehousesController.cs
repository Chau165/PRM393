using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VaxStock.Api.Contracts;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Models;
namespace VaxStock.Api.Controllers;

[ApiController, Route("api/v1/warehouses"), Authorize]
public sealed class WarehousesController(IMasterDataService service) : MasterDataControllerBase(service, MasterDataType.Warehouse)
{
    [HttpGet]
    public Task<IActionResult> List(int page = 1, int pageSize = 20, string? search = null, string sort = "code", CancellationToken ct = default) => ListCore(new(page, pageSize, search, sort), ct);
    [HttpGet("{id:int:min(1)}")]
    public Task<IActionResult> Get(int id, CancellationToken ct) => GetCore(id, ct);
    [HttpPost, Authorize(Roles = "Admin")]
    public Task<IActionResult> Create(WarehouseRequest request, CancellationToken ct) => SaveCore(null, new(request.Code, request.Name), ct);
    [HttpPut("{id:int:min(1)}"), Authorize(Roles = "Admin")]
    public Task<IActionResult> Update(int id, WarehouseRequest request, CancellationToken ct) => SaveCore(id, new(request.Code, request.Name), ct);
    [HttpDelete("{id:int:min(1)}"), Authorize(Roles = "Admin")]
    public Task<IActionResult> Delete(int id, CancellationToken ct) => DeleteCore(id, ct);
}
