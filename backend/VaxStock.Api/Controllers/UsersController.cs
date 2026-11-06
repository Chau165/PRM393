using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VaxStock.Api.Contracts;
using VaxStock.Api.Infrastructure;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Models;
namespace VaxStock.Api.Controllers;

[ApiController, Route("api/v1/users"), Authorize(Roles = "Admin")]
public sealed class UsersController(IUserManagementService users) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PageResponse<CurrentUserResponse>>> List(int page = 1, int pageSize = 20,
        string? search = null, string? role = null, string sort = "username", CancellationToken ct = default)
    {
        var result = await users.ListUsersAsync(page, pageSize, search, role, sort, ct);
        return Ok(new PageResponse<CurrentUserResponse>(result.Items.Select(Map).ToArray(), result.Page, result.PageSize, result.TotalItems, result.TotalPages));
    }
    [HttpGet("{id:int:min(1)}")]
    public async Task<ActionResult<CurrentUserResponse>> Get(int id, CancellationToken ct)
    {
        var result = await users.GetUserAsync(id, ct); EntityVersions.Set(Response, result.Version); return Ok(Map(result));
    }
    [HttpPost]
    public async Task<ActionResult<CurrentUserResponse>> Create(CreateUserRequest request, CancellationToken ct)
    {
        var result = await users.CreateUserAsync(new(Actor, request.Username, request.Password, request.FullName, request.Role), ct);
        EntityVersions.Set(Response, result.Version);
        return CreatedAtAction(nameof(Get), new { id = result.Id }, Map(result));
    }
    [HttpPut("{id:int:min(1)}")]
    public async Task<ActionResult<CurrentUserResponse>> Update(int id, UpdateUserRequest request, CancellationToken ct)
    {
        var result = await users.UpdateUserAsync(new(Actor, id, EntityVersions.Require(Request), request.FullName, request.Role), ct);
        EntityVersions.Set(Response, result.Version); return Ok(Map(result));
    }
    [HttpPost("{id:int:min(1)}/reset-password")]
    public async Task<ActionResult<ResetPasswordResponse>> ResetPassword(int id, ResetPasswordRequest request, CancellationToken ct)
    {
        var result = await users.ResetPasswordAsync(new(Actor, id, EntityVersions.Require(Request), request.NewPassword, request.Reason), ct);
        EntityVersions.Set(Response, result.Version); return Ok(new ResetPasswordResponse(result.Id, result.ReauthenticationRequired, result.Version));
    }
    private AdminActor Actor => new(int.Parse(User.FindFirstValue("sub")!), int.Parse(User.FindFirstValue("authVersion")!));
    private static CurrentUserResponse Map(CurrentUserResult u) => new(u.Id, u.Username, u.FullName, u.Role,
        u.Warehouses.Select(w => new WarehouseResponse(w.Id, w.Code, w.Name)).ToArray(), u.Version);
}
