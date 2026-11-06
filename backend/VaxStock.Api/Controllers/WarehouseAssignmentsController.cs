using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VaxStock.Api.Contracts;
using VaxStock.Api.Infrastructure;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Models;
namespace VaxStock.Api.Controllers;

[ApiController, Route("api/v1/warehouse-assignments"), Authorize(Roles = "Admin")]
public sealed class WarehouseAssignmentsController(IUserManagementService users) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PageResponse<AssignmentResponse>>> List(int page = 1, int pageSize = 20,
        int? userId = null, int? warehouseId = null, CancellationToken ct = default)
    {
        var result = await users.ListAssignmentsAsync(page, pageSize, userId, warehouseId, ct);
        return Ok(new PageResponse<AssignmentResponse>(result.Items.Select(Map).ToArray(), result.Page, result.PageSize, result.TotalItems, result.TotalPages));
    }
    [HttpGet("{id:int:min(1)}")]
    public async Task<ActionResult<AssignmentResponse>> Get(int id, CancellationToken ct)
    {
        var result = await users.GetAssignmentAsync(id, ct); EntityVersions.Set(Response, result.Version); return Ok(Map(result));
    }
    [HttpPost]
    public async Task<ActionResult<AssignmentResponse>> Create(CreateAssignmentRequest request, CancellationToken ct)
    {
        var result = await users.CreateAssignmentAsync(Actor, request.UserId, request.WarehouseId, ct);
        EntityVersions.Set(Response, result.Version);
        return CreatedAtAction(nameof(Get), new { id = result.Id }, Map(result));
    }
    [HttpDelete("{id:int:min(1)}")]
    public async Task<IActionResult> Delete(int id, CancellationToken ct)
    {
        await users.DeleteAssignmentAsync(Actor, id, EntityVersions.Require(Request), ct); return NoContent();
    }
    private AdminActor Actor => new(int.Parse(User.FindFirstValue("sub")!), int.Parse(User.FindFirstValue("authVersion")!));
    private static AssignmentResponse Map(AssignmentResult a) => new(a.Id, a.UserId, a.Username, a.WarehouseId, a.WarehouseName, a.Version);
}
