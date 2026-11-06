using VaxStock.Business.Exceptions;
namespace VaxStock.Api.Infrastructure;

public static class EntityVersions
{
    public static byte[] Require(HttpRequest request)
    {
        var header = request.Headers.IfMatch;
        if (header.Count == 0 || string.IsNullOrWhiteSpace(header.ToString()))
            throw new ManagementException("PRECONDITION_REQUIRED", "Cần gửi If-Match của dữ liệu đang sửa.", 428);
        var value = header.ToString();
        if (header.Count != 1 || value.Length < 3 || value[0] != '"' || value[^1] != '"') throw Invalid();
        try
        {
            var bytes = Convert.FromBase64String(value[1..^1]);
            if (bytes.Length != 8 || Convert.ToBase64String(bytes) != value[1..^1]) throw Invalid();
            return bytes;
        }
        catch (FormatException) { throw Invalid(); }
    }
    public static void Set(HttpResponse response, string version) => response.Headers.ETag = $"\"{version}\"";
    private static ManagementException Invalid() => new("INVALID_IF_MATCH", "If-Match phải là một strong ETag hợp lệ, có dấu ngoặc kép.", 400);
}
