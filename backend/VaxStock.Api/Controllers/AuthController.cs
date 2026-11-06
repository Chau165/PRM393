using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using VaxStock.Api.Contracts;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Models;
namespace VaxStock.Api.Controllers;

[ApiController, Route("api/v1/auth"), Authorize]
public sealed class AuthController(IAuthService auth) : ControllerBase
{
    [HttpPost("login"), AllowAnonymous, EnableRateLimiting("login")]
    public async Task<ActionResult<LoginResponse>> Login(LoginRequest request, CancellationToken ct)
    {
        var result = await auth.LoginAsync(new(request.Username, request.Password), ct);
        return Ok(new LoginResponse(result.AccessToken, "Bearer", result.ExpiresIn, Map(result.User)));
    }
    [HttpGet("me")]
    public async Task<ActionResult<CurrentUserResponse>> Me(CancellationToken ct)
    {
        var user = await auth.GetCurrentUserAsync(UserId, ct);
        Response.Headers.ETag = $"\"{user.Version}\"";
        return Ok(Map(user));
    }
    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest request, CancellationToken ct)
    {
        await auth.ChangePasswordAsync(new(UserId, AuthVersion, request.CurrentPassword, request.NewPassword), ct);
        return Ok(new { reauthenticationRequired = true });
    }
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(CancellationToken ct)
    {
        await auth.LogoutAsync(UserId, AuthVersion, ct);
        return Ok(new { loggedOut = true });
    }
    private int UserId => int.Parse(User.FindFirstValue("sub")!);
    private int AuthVersion => int.Parse(User.FindFirstValue("authVersion")!);
    private static CurrentUserResponse Map(CurrentUserResult u) => new(u.Id, u.Username, u.FullName, u.Role,
        u.Warehouses.Select(w => new WarehouseResponse(w.Id, w.Code, w.Name)).ToArray(), u.Version);
}
