namespace VaxStock.Business.Models;

public sealed record LoginCommand(string Username, string Password);
public sealed record ChangePasswordCommand(int UserId, int AuthVersion, string CurrentPassword, string NewPassword);
public sealed record WarehouseResult(int Id, string Code, string Name);
public sealed record CurrentUserResult(int Id, string Username, string FullName, string Role, IReadOnlyList<WarehouseResult> Warehouses, string Version = "")
{
    public IReadOnlyList<int> WarehouseIds => Warehouses.Select(w => w.Id).ToArray();
}
public sealed record TokenSubject(int Id, string Username, string Role, int AuthVersion);
public sealed record TokenResult(string AccessToken, int ExpiresIn);
public sealed record LoginResult(string AccessToken, int ExpiresIn, CurrentUserResult User);
