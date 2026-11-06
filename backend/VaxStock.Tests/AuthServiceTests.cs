using VaxStock.Api.Security;
using VaxStock.Business.Exceptions;
using VaxStock.Business.Models;
using VaxStock.Business.Services;
using VaxStock.Business.Interfaces;
using VaxStock.DataAccess.Entities;
using VaxStock.DataAccess.Interfaces;
using Xunit;

namespace VaxStock.Tests;

public sealed class AuthServiceTests
{
    private const string Password = "Test-only-password-123!";
    private readonly PasswordService _passwords = new();

    [Fact]
    public async Task Unknown_user_and_wrong_password_have_same_error()
    {
        var repo = CreateRepository();
        var service = Service(repo);
        var unknown = await Assert.ThrowsAsync<AuthException>(() => service.LoginAsync(new("unknown", Password), default));
        var wrong = await Assert.ThrowsAsync<AuthException>(() => service.LoginAsync(new("staff", "wrong"), default));
        Assert.Equal(unknown.Code, wrong.Code);
        Assert.Equal(unknown.Message, wrong.Message);
        Assert.Equal(401, wrong.Status);
    }

    [Fact]
    public async Task Logout_revokes_all_tokens_with_old_version()
    {
        var repo = CreateRepository();
        var service = Service(repo);
        Assert.True(await service.IsSessionValidAsync(1, 0, "WarehouseStaff", default));
        await service.LogoutAsync(1, 0, default);
        Assert.False(await service.IsSessionValidAsync(1, 0, "WarehouseStaff", default));
        Assert.True(await service.IsSessionValidAsync(1, 1, "WarehouseStaff", default));
    }

    [Fact]
    public async Task Changing_password_requires_old_password_and_revokes_old_version()
    {
        var repo = CreateRepository();
        var service = Service(repo);
        await Assert.ThrowsAsync<AuthException>(() => service.ChangePasswordAsync(new(1,0,"wrong","A-new-password-123!"), default));
        Assert.Equal(0, repo.User.AuthVersion);
        await service.ChangePasswordAsync(new(1,0,Password,"A-new-password-123!"), default);
        Assert.False(_passwords.Verify(repo.User.PasswordHash, Password));
        Assert.True(_passwords.Verify(repo.User.PasswordHash, "A-new-password-123!"));
        Assert.False(await service.IsSessionValidAsync(1,0,"WarehouseStaff",default));
    }

    [Fact]
    public async Task Stale_change_cannot_overwrite_new_credentials()
    {
        var repo = CreateRepository();
        var service = Service(repo);
        await service.LogoutAsync(1,0,default);
        await Assert.ThrowsAsync<AuthException>(() => service.ChangePasswordAsync(new(1,0,Password,"A-new-password-123!"),default));
        Assert.True(_passwords.Verify(repo.User.PasswordHash, Password));
    }

    [Fact]
    public async Task Permission_is_rechecked_from_assignments_and_role()
    {
        var repo = CreateRepository();
        var service = Service(repo);
        await service.RequireWarehouseAccessAsync(1, 10, default);
        repo.Assigned = false;
        var error = await Assert.ThrowsAsync<AuthException>(() => service.RequireWarehouseAccessAsync(1,10,default));
        Assert.Equal(403,error.Status);
        repo.User.Role = "QualityManager";
        Assert.False(await service.IsSessionValidAsync(1,0,"WarehouseStaff",default));
    }

    [Theory]
    [InlineData("short")]
    [InlineData("            ")]
    [InlineData(Password)]
    public async Task Invalid_or_unchanged_new_password_is_rejected(string next)
    {
        var repo = CreateRepository();
        await Assert.ThrowsAsync<AuthException>(() => Service(repo).ChangePasswordAsync(new(1,0,Password,next),default));
        Assert.Equal(0,repo.User.AuthVersion);
    }

    private FakeRepository CreateRepository() => new(new AppUser { Id=1, Username="staff", FullName="Staff", Role="WarehouseStaff", PasswordHash=_passwords.Hash(Password) });
    private AuthService Service(FakeRepository repo) => new(repo,_passwords,new FakeTokens());
    private sealed class FakeTokens : ITokenService
    {
        public TokenResult Issue(TokenSubject subject) => new("test-token",900);
    }
    private sealed class FakeRepository(AppUser user) : IAuthRepository
    {
        public AppUser User { get; } = user;
        public bool Assigned { get; set; } = true;
        public Task<AppUser?> FindByIdAsync(int id,CancellationToken ct) => Task.FromResult<AppUser?>(id == User.Id ? User : null);
        public Task<AppUser?> FindByUsernameAsync(string username,CancellationToken ct) => Task.FromResult<AppUser?>(username == User.Username ? User : null);
        public Task<IReadOnlyList<Warehouse>> GetWarehousesAsync(int id,bool admin,CancellationToken ct) =>
            Task.FromResult<IReadOnlyList<Warehouse>>(Assigned || admin ? [new Warehouse { Id=10,Code="HCM",Name="HCM" }] : []);
        public Task<bool> RevokeAsync(int id,int expectedVersion,string? hash,CancellationToken ct)
        {
            if (id != User.Id || expectedVersion != User.AuthVersion) return Task.FromResult(false);
            User.AuthVersion++;
            if (hash is not null) User.PasswordHash=hash;
            return Task.FromResult(true);
        }
    }
}
