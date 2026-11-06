using System.ComponentModel.DataAnnotations;
namespace VaxStock.Api.Contracts;

public sealed record LoginRequest(
    [Required, StringLength(200)] string Username,
    [Required, StringLength(128)] string Password);
public sealed record ChangePasswordRequest(
    [Required, StringLength(128)] string CurrentPassword,
    [Required, StringLength(128, MinimumLength = 12)] string NewPassword);
public sealed record WarehouseResponse(int Id, string Code, string Name, string? Version = null);
public sealed record CurrentUserResponse(int Id, string Username, string FullName, string Role, IReadOnlyList<WarehouseResponse> Warehouses, string Version)
{
    public IReadOnlyList<int> WarehouseIds => Warehouses.Select(w => w.Id).ToArray();
}
public sealed record LoginResponse(string AccessToken, string TokenType, int ExpiresIn, CurrentUserResponse User);
