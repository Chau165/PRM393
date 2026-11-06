using Microsoft.EntityFrameworkCore;
using VaxStock.Api.Data;
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddProblemDetails();
builder.Services.AddDbContext<WarehouseDbContext>(options => options.UseSqlServer(
    builder.Configuration.GetConnectionString("Warehouse")
    ?? throw new InvalidOperationException("ConnectionStrings:Warehouse is required.")));
var app = builder.Build();
app.UseExceptionHandler();
app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "VaxStock.Api" }));
app.MapControllers();
app.Run();
