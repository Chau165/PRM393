using System.Text;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using VaxStock.Api.Infrastructure;
using VaxStock.Api.Security;
using VaxStock.Business.Exceptions;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Services;
using VaxStock.DataAccess.Data;
using VaxStock.DataAccess.Interfaces;
using VaxStock.DataAccess.Repositories;

var builder = WebApplication.CreateBuilder(args);
if (builder.Environment.IsDevelopment())
    builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: false).AddEnvironmentVariables();

var jwt = builder.Configuration.GetSection("Jwt").Get<JwtSettings>() ?? new();
// A design-time factory in DataAccess supplies EF's context without starting the API.
jwt.Validate();
builder.Services.AddSingleton(jwt);
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<IPasswordService, PasswordService>();
builder.Services.AddSingleton<ITokenService, TokenService>();
builder.Services.AddScoped<IAuthRepository, AuthRepository>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUserManagementRepository, UserManagementRepository>();
builder.Services.AddScoped<IUserManagementService, UserManagementService>();
builder.Services.AddScoped<IMasterDataRepository, MasterDataRepository>();
builder.Services.AddScoped<IMasterDataService, MasterDataService>();
builder.Services.AddScoped<IBatchRepository, BatchRepository>();
builder.Services.AddScoped<IBatchService, BatchService>();
builder.Services.AddDbContext<WarehouseDbContext>(options => options.UseSqlServer(
    builder.Configuration.GetConnectionString("Warehouse")
    ?? throw new InvalidOperationException("ConnectionStrings:Warehouse is required.")));
builder.Services.AddControllers().AddJsonOptions(o => o.JsonSerializerOptions.UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow);
builder.Services.Configure<ApiBehaviorOptions>(o => o.InvalidModelStateResponseFactory = context =>
    new BadRequestObjectResult(ApiProblems.Create(context.HttpContext, 400, "VALIDATION_ERROR", "Dữ liệu không hợp lệ.",
        context.ModelState.Where(p => p.Value!.Errors.Count > 0).ToDictionary(p => p.Key,
            p => p.Value!.Errors.Select(_ => "Kiểm tra định dạng và độ dài trường.").ToArray()))));
builder.Services.AddProblemDetails();
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
{
    o.MapInboundClaims = false;
    o.TokenValidationParameters = new()
    {
        ValidateIssuer = true, ValidIssuer = jwt.Issuer,
        ValidateAudience = true, ValidAudience = jwt.Audience,
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.SigningKey)),
        ValidateLifetime = true, RequireExpirationTime = true, RequireSignedTokens = true,
        ValidAlgorithms = [SecurityAlgorithms.HmacSha256], ClockSkew = TimeSpan.Zero,
        NameClaimType = "sub", RoleClaimType = "role"
    };
    o.Events = new JwtBearerEvents
    {
        OnTokenValidated = async c =>
        {
            if (!int.TryParse(c.Principal?.FindFirst("sub")?.Value, out var id)
                || !int.TryParse(c.Principal?.FindFirst("authVersion")?.Value, out var version)
                || !await c.HttpContext.RequestServices.GetRequiredService<IAuthService>()
                    .IsSessionValidAsync(id, version, c.Principal?.FindFirst("role")?.Value ?? "", c.HttpContext.RequestAborted))
                c.Fail("Session revoked.");
        },
        OnChallenge = async c =>
        {
            c.HandleResponse();
            c.Response.Headers.WWWAuthenticate = "Bearer";
            await ApiProblems.Write(c.HttpContext, 401, "UNAUTHENTICATED", "Vui lòng đăng nhập lại.");
        },
        OnForbidden = c => ApiProblems.Write(c.HttpContext, 403, "FORBIDDEN", "Bạn không có quyền thực hiện thao tác này.")
    };
});
builder.Services.AddAuthorization(o => o.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());
builder.Services.AddRateLimiter(o =>
{
    o.AddPolicy("login", c => RateLimitPartition.GetFixedWindowLimiter(
        c.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
    o.OnRejected = async (c, _) =>
    {
        c.HttpContext.Response.Headers.RetryAfter = "60";
        await ApiProblems.Write(c.HttpContext, 429, "RATE_LIMITED", "Thử đăng nhập quá nhiều lần. Vui lòng thử lại sau.");
    };
});
var origins = builder.Configuration.GetSection("Cors:Origins").Get<string[]>() ?? [];
builder.Services.AddCors(o => o.AddDefaultPolicy(p => { if (origins.Length > 0) p.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod().WithExposedHeaders("ETag", "Location"); }));

var app = builder.Build();
if (!app.Environment.IsDevelopment()) app.UseHttpsRedirection();
app.UseExceptionHandler(error => error.Run(async context =>
{
    var exception = context.Features.Get<IExceptionHandlerFeature>()?.Error;
    if (exception is AuthException auth)
        await ApiProblems.Write(context, auth.Status, auth.Code, auth.Message);
    else if (exception is ManagementException management)
        await ApiProblems.Write(context, management.Status, management.Code, management.Message, management.ExistingBatchId);
    else
        await ApiProblems.Write(context, 500, "SERVER_ERROR", "Không thể xử lý yêu cầu. Vui lòng thử lại.");
}));
app.UseCors();
app.UseAuthentication();
app.UseRateLimiter();
app.UseAuthorization();
app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "VaxStock.Api" })).AllowAnonymous();
app.MapControllers();
if (args.Contains("--seed-auth"))
{
    if (!app.Environment.IsDevelopment()) throw new InvalidOperationException("Auth seed is development-only.");
    await DevelopmentSeeder.Run(app.Services, app.Configuration);
    return;
}
app.Run();
public partial class Program;
