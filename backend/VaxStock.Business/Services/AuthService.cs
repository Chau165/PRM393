using VaxStock.Business.Exceptions;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Models;
using VaxStock.DataAccess.Entities;
using VaxStock.DataAccess.Interfaces;

namespace VaxStock.Business.Services;

public sealed class AuthService(IAuthRepository users, IPasswordService passwords, ITokenService tokens) : IAuthService
{
    // The singleton hasher precomputes this at startup; unknown users still
    // perform one password verification rather than return immediately.
    public async Task<LoginResult> LoginAsync(LoginCommand command, CancellationToken ct)
    {
        var user = await users.FindByUsernameAsync(command.Username.Trim().ToLowerInvariant(), ct);
        var valid = passwords.Verify(user?.PasswordHash ?? string.Empty, command.Password);
        if (user is null || !valid) throw Unauthorized();
        var token = tokens.Issue(new(user.Id, user.Username, user.Role, user.AuthVersion));
        return new(token.AccessToken, token.ExpiresIn, await MapUser(user, ct));
    }

    public async Task<CurrentUserResult> GetCurrentUserAsync(int userId, CancellationToken ct) =>
        await MapUser(await users.FindByIdAsync(userId, ct) ?? throw Unauthorized(), ct);

    public async Task<bool> IsSessionValidAsync(int userId, int authVersion, string role, CancellationToken ct)
    {
        var user = await users.FindByIdAsync(userId, ct);
        return user is not null && user.AuthVersion == authVersion && user.Role == role;
    }

    public async Task RequireWarehouseAccessAsync(int userId, int warehouseId, CancellationToken ct)
    {
        var user = await GetCurrentUserAsync(userId, ct);
        if (!user.Warehouses.Any(w => w.Id == warehouseId))
            throw new AuthException("WAREHOUSE_ACCESS_DENIED", "Bạn không có quyền truy cập kho này.", 403);
    }

    public async Task ChangePasswordAsync(ChangePasswordCommand command, CancellationToken ct)
    {
        var user = await users.FindByIdAsync(command.UserId, ct) ?? throw Unauthorized();
        if (user.AuthVersion != command.AuthVersion) throw Unauthorized();
        if (!passwords.Verify(user.PasswordHash, command.CurrentPassword))
            throw new AuthException("CURRENT_PASSWORD_INVALID", "Mật khẩu hiện tại không đúng.", 400);
        if (command.NewPassword.Length is < 12 or > 128 || string.IsNullOrWhiteSpace(command.NewPassword))
            throw new AuthException("PASSWORD_POLICY", "Mật khẩu mới phải có từ 12 đến 128 ký tự.", 400);
        if (passwords.Verify(user.PasswordHash, command.NewPassword))
            throw new AuthException("PASSWORD_UNCHANGED", "Mật khẩu mới phải khác mật khẩu hiện tại.", 400);
        if (!await users.RevokeAsync(user.Id, user.AuthVersion, passwords.Hash(command.NewPassword), ct))
            throw Unauthorized();
    }

    public async Task LogoutAsync(int userId, int authVersion, CancellationToken ct)
    {
        if (!await users.RevokeAsync(userId, authVersion, null, ct)) throw Unauthorized();
    }

    private async Task<CurrentUserResult> MapUser(AppUser user, CancellationToken ct) => new(
        user.Id, user.Username, user.FullName, user.Role,
        (await users.GetWarehousesAsync(user.Id, user.Role == "Admin", ct))
            .Select(w => new WarehouseResult(w.Id, w.Code, w.Name)).ToArray(), Convert.ToBase64String(user.RowVersion));

    private static AuthException Unauthorized() => new("INVALID_CREDENTIALS_OR_SESSION", "Thông tin đăng nhập hoặc phiên làm việc không hợp lệ.", 401);
}
