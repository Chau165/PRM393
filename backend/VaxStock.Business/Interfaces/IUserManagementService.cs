using VaxStock.Business.Models;

namespace VaxStock.Business.Interfaces;

public interface IUserManagementService
{
    Task<PageResult<CurrentUserResult>> ListUsersAsync(int page, int pageSize, string? search, string? role, string sort, CancellationToken ct);
    Task<CurrentUserResult> GetUserAsync(int id, CancellationToken ct);
    Task<CurrentUserResult> CreateUserAsync(CreateUserCommand command, CancellationToken ct);
    Task<CurrentUserResult> UpdateUserAsync(UpdateUserCommand command, CancellationToken ct);
    Task<ResetPasswordResult> ResetPasswordAsync(ResetPasswordCommand command, CancellationToken ct);
    Task<PageResult<AssignmentResult>> ListAssignmentsAsync(int page, int pageSize, int? userId, int? warehouseId, CancellationToken ct);
    Task<AssignmentResult> GetAssignmentAsync(int id, CancellationToken ct);
    Task<AssignmentResult> CreateAssignmentAsync(AdminActor actor, int userId, int warehouseId, CancellationToken ct);
    Task DeleteAssignmentAsync(AdminActor actor, int id, byte[] version, CancellationToken ct);
}
