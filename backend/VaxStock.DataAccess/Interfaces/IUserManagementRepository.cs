using VaxStock.DataAccess.Entities;

namespace VaxStock.DataAccess.Interfaces;

public sealed record StorePage<T>(IReadOnlyList<T> Items, int Total);
public sealed record AssignmentRow
{
    public int Id { get; init; }
    public int UserId { get; init; }
    public string Username { get; init; } = string.Empty;
    public int WarehouseId { get; init; }
    public string WarehouseName { get; init; } = string.Empty;
    public byte[] RowVersion { get; init; } = [];
}
public enum UserStoreError { NotFound, Duplicate, Stale, LastAdmin, InvalidActor, MissingReference }
public sealed class UserStoreException(UserStoreError error) : Exception(error.ToString())
{
    public UserStoreError Error { get; } = error;
}

public interface IUserManagementRepository
{
    Task<StorePage<AppUser>> ListUsersAsync(int page, int pageSize, string? search, string? role, string sort, CancellationToken ct);
    Task<AppUser?> GetUserAsync(int id, CancellationToken ct);
    Task<AppUser> CreateUserAsync(int actorId, int actorVersion, AppUser user, CancellationToken ct);
    Task<AppUser> UpdateUserAsync(int actorId, int actorVersion, int id, byte[] version, string fullName, string role, CancellationToken ct);
    Task<AppUser> ResetPasswordAsync(int actorId, int actorVersion, int id, byte[] version, string hash, string reason, CancellationToken ct);
    Task<StorePage<AssignmentRow>> ListAssignmentsAsync(int page, int pageSize, int? userId, int? warehouseId, CancellationToken ct);
    Task<AssignmentRow?> GetAssignmentAsync(int id, CancellationToken ct);
    Task<AssignmentRow> CreateAssignmentAsync(int actorId, int actorVersion, int userId, int warehouseId, CancellationToken ct);
    Task DeleteAssignmentAsync(int actorId, int actorVersion, int id, byte[] version, CancellationToken ct);
}
