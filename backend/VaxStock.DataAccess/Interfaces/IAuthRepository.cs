using VaxStock.DataAccess.Entities;

namespace VaxStock.DataAccess.Interfaces;

public interface IAuthRepository
{
    Task<AppUser?> FindByUsernameAsync(string username, CancellationToken ct);
    Task<AppUser?> FindByIdAsync(int id, CancellationToken ct);
    Task<IReadOnlyList<Warehouse>> GetWarehousesAsync(int userId, bool admin, CancellationToken ct);
    Task<bool> RevokeAsync(int userId, int expectedVersion, string? newPasswordHash, CancellationToken ct);
}
