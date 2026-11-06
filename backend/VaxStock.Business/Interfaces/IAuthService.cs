using VaxStock.Business.Models;

namespace VaxStock.Business.Interfaces;

public interface IAuthService
{
    Task<LoginResult> LoginAsync(LoginCommand command, CancellationToken ct);
    Task<CurrentUserResult> GetCurrentUserAsync(int userId, CancellationToken ct);
    Task ChangePasswordAsync(ChangePasswordCommand command, CancellationToken ct);
    Task LogoutAsync(int userId, int authVersion, CancellationToken ct);
    Task<bool> IsSessionValidAsync(int userId, int authVersion, string role, CancellationToken ct);
    Task RequireWarehouseAccessAsync(int userId, int warehouseId, CancellationToken ct);
}

public interface IPasswordService
{
    string Hash(string password);
    bool Verify(string hash, string password);
}

public interface ITokenService
{
    TokenResult Issue(TokenSubject subject);
}
