namespace VaxStock.Business.Models;

public sealed record AdminActor(int Id, int AuthVersion);
public sealed record PageResult<T>(IReadOnlyList<T> Items, int Page, int PageSize, int TotalItems)
{
    public int TotalPages => (int)Math.Ceiling(TotalItems / (double)PageSize);
}
public sealed record CreateUserCommand(AdminActor Actor, string Username, string Password, string FullName, string Role);
public sealed record UpdateUserCommand(AdminActor Actor, int Id, byte[] Version, string FullName, string Role);
public sealed record ResetPasswordCommand(AdminActor Actor, int Id, byte[] Version, string NewPassword, string Reason);
public sealed record AssignmentResult(int Id, int UserId, string Username, int WarehouseId, string WarehouseName, string Version);
public sealed record ResetPasswordResult(int Id, bool ReauthenticationRequired, string Version);
