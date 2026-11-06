using VaxStock.Business.Exceptions;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Models;
using VaxStock.DataAccess.Entities;
using VaxStock.DataAccess.Interfaces;

namespace VaxStock.Business.Services;

public sealed class UserManagementService(IUserManagementRepository store, IAuthRepository auth, IPasswordService passwords) : IUserManagementService
{
    private static readonly string[] Roles = ["Admin", "WarehouseStaff", "QualityManager"];
    public async Task<PageResult<CurrentUserResult>> ListUsersAsync(int page, int pageSize, string? search, string? role, string sort, CancellationToken ct)
    {
        ValidatePage(page, pageSize);
        if (role is not null) ValidateRole(role);
        if (sort is not ("username" or "id")) throw Bad("Sort chỉ nhận username hoặc id.");
        if (search?.Length > 200) throw Bad("Từ khóa quá dài.");
        var result = await store.ListUsersAsync(page, pageSize, search?.Trim(), role, sort, ct);
        var users = new List<CurrentUserResult>();
        foreach (var user in result.Items) users.Add(await Map(user, ct));
        return new(users, page, pageSize, result.Total);
    }
    public async Task<CurrentUserResult> GetUserAsync(int id, CancellationToken ct) =>
        await Map(await store.GetUserAsync(id, ct) ?? throw new ManagementException("USER_NOT_FOUND", "Không tìm thấy tài khoản.", 404), ct);

    public Task<CurrentUserResult> CreateUserAsync(CreateUserCommand c, CancellationToken ct) => Translate(async () =>
    {
        ValidateRole(c.Role); ValidatePassword(c.Password);
        var username = Text(c.Username, 200).ToLowerInvariant();
        if (username.Any(char.IsWhiteSpace)) throw Bad("Tên đăng nhập không được có khoảng trắng.");
        var user = await store.CreateUserAsync(c.Actor.Id, c.Actor.AuthVersion,
            new AppUser { Username = username, FullName = Text(c.FullName, 200), Role = c.Role, PasswordHash = passwords.Hash(c.Password) }, ct);
        return await Map(user, ct);
    });
    public Task<CurrentUserResult> UpdateUserAsync(UpdateUserCommand c, CancellationToken ct) => Translate(async () =>
    {
        ValidateRole(c.Role);
        return await Map(await store.UpdateUserAsync(c.Actor.Id, c.Actor.AuthVersion, c.Id, c.Version, Text(c.FullName, 200), c.Role, ct), ct);
    });
    public Task<ResetPasswordResult> ResetPasswordAsync(ResetPasswordCommand c, CancellationToken ct) => Translate(async () =>
    {
        ValidatePassword(c.NewPassword);
        var user = await store.ResetPasswordAsync(c.Actor.Id, c.Actor.AuthVersion, c.Id, c.Version,
            passwords.Hash(c.NewPassword), Text(c.Reason, 2000), ct);
        return new ResetPasswordResult(user.Id, true, Convert.ToBase64String(user.RowVersion));
    });
    public async Task<PageResult<AssignmentResult>> ListAssignmentsAsync(int page, int pageSize, int? userId, int? warehouseId, CancellationToken ct)
    {
        ValidatePage(page, pageSize);
        if (userId <= 0 || warehouseId <= 0) throw Bad("ID phải lớn hơn 0.");
        var result = await store.ListAssignmentsAsync(page, pageSize, userId, warehouseId, ct);
        return new(result.Items.Select(Map).ToArray(), page, pageSize, result.Total);
    }
    public async Task<AssignmentResult> GetAssignmentAsync(int id, CancellationToken ct) =>
        Map(await store.GetAssignmentAsync(id, ct) ?? throw new ManagementException("ASSIGNMENT_NOT_FOUND", "Không tìm thấy phân quyền.", 404));
    public Task<AssignmentResult> CreateAssignmentAsync(AdminActor actor, int userId, int warehouseId, CancellationToken ct) => Translate(async () =>
    {
        if (userId <= 0 || warehouseId <= 0) throw Bad("ID phải lớn hơn 0.");
        return Map(await store.CreateAssignmentAsync(actor.Id, actor.AuthVersion, userId, warehouseId, ct));
    });
    public async Task DeleteAssignmentAsync(AdminActor actor, int id, byte[] version, CancellationToken ct) =>
        await Translate(async () => { await store.DeleteAssignmentAsync(actor.Id, actor.AuthVersion, id, version, ct); return true; });

    private async Task<CurrentUserResult> Map(AppUser user, CancellationToken ct) => new(user.Id, user.Username, user.FullName, user.Role,
        (await auth.GetWarehousesAsync(user.Id, user.Role == "Admin", ct)).Select(w => new WarehouseResult(w.Id, w.Code, w.Name)).ToArray(), Convert.ToBase64String(user.RowVersion));
    private static AssignmentResult Map(AssignmentRow a) => new(a.Id, a.UserId, a.Username, a.WarehouseId, a.WarehouseName, Convert.ToBase64String(a.RowVersion));
    private static void ValidatePage(int page, int pageSize)
    {
        if (page < 1 || page > 1_000_000 || pageSize is < 1 or > 100) throw Bad("page >= 1, pageSize từ 1 đến 100.");
    }
    private static string Text(string value, int max)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > max) throw Bad("Trường bắt buộc bị trống hoặc vượt độ dài cho phép.");
        return value.Trim();
    }
    private static void ValidateRole(string role) { if (!Roles.Contains(role)) throw Bad("Vai trò không hợp lệ."); }
    private static void ValidatePassword(string password)
    {
        if (string.IsNullOrWhiteSpace(password) || password.Length is < 12 or > 128) throw Bad("Mật khẩu phải có từ 12 đến 128 ký tự.");
    }
    private static ManagementException Bad(string message) => new("VALIDATION_ERROR", message, 400);
    private static async Task<T> Translate<T>(Func<Task<T>> action)
    {
        try { return await action(); }
        catch (UserStoreException e)
        {
            throw e.Error switch
            {
                UserStoreError.NotFound => new ManagementException("RESOURCE_NOT_FOUND", "Không tìm thấy dữ liệu.", 404),
                UserStoreError.Duplicate => new ManagementException("DUPLICATE_CODE", "Tên đăng nhập hoặc phân quyền đã tồn tại.", 409),
                UserStoreError.Stale => new ManagementException("CONCURRENCY_CONFLICT", "Dữ liệu đã thay đổi. Vui lòng tải lại.", 412),
                UserStoreError.LastAdmin => new ManagementException("LAST_ADMIN_REQUIRED", "Không thể hạ quyền quản trị viên cuối cùng.", 409),
                UserStoreError.InvalidActor => new ManagementException("UNAUTHENTICATED", "Phiên quản trị đã thay đổi. Vui lòng đăng nhập lại.", 401),
                _ => new ManagementException("INVALID_REFERENCE", "Người dùng hoặc kho không tồn tại.", 400)
            };
        }
    }
}
