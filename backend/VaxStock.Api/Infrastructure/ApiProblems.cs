using Microsoft.AspNetCore.Mvc;
namespace VaxStock.Api.Infrastructure;

public static class ApiProblems
{
    public static ProblemDetails Create(HttpContext context, int status, string code, string detail,
        IDictionary<string, string[]>? errors = null) => new()
    {
        Type = "about:blank", Title = detail, Status = status,
        Extensions = { ["code"] = code, ["traceId"] = context.TraceIdentifier,
            ["fieldErrors"] = errors ?? new Dictionary<string, string[]>() }
    };
    public static async Task Write(HttpContext context, int status, string code, string detail, int? existingBatchId = null)
    {
        context.Response.StatusCode = status;
        var problem = Create(context, status, code, detail);
        if (existingBatchId is not null) problem.Extensions["existingBatchId"] = existingBatchId;
        await context.Response.WriteAsJsonAsync(problem,
            options: (System.Text.Json.JsonSerializerOptions?)null,
            contentType: "application/problem+json", cancellationToken: context.RequestAborted);
    }
}
