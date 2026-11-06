using System.ComponentModel.DataAnnotations;
namespace VaxStock.Api.Contracts;

public sealed record CreateUserRequest(
    [Required, StringLength(200)] string Username,
    [Required, StringLength(128, MinimumLength = 12)] string Password,
    [Required, StringLength(200)] string FullName,
    [Required] string Role);
public sealed record UpdateUserRequest([Required, StringLength(200)] string FullName, [Required] string Role);
public sealed record ResetPasswordRequest(
    [Required, StringLength(128, MinimumLength = 12)] string NewPassword,
    [Required, StringLength(2000)] string Reason);
public sealed record CreateAssignmentRequest([Range(1, int.MaxValue)] int UserId, [Range(1, int.MaxValue)] int WarehouseId);
public sealed record AssignmentResponse(int Id, int UserId, string Username, int WarehouseId, string WarehouseName, string Version);
public sealed record ResetPasswordResponse(int Id, bool ReauthenticationRequired, string Version);
public sealed record PageResponse<T>(IReadOnlyList<T> Items, int Page, int PageSize, int TotalItems, int TotalPages);
