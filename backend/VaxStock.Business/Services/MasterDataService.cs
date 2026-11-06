using VaxStock.Business.Exceptions;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Models;
using VaxStock.DataAccess.Interfaces;
namespace VaxStock.Business.Services;

public sealed class MasterDataService(IMasterDataRepository store) : IMasterDataService
{
    private static readonly string[] Kinds = ["Manufacturer", "Supplier", "Recipient", "Carrier"];
    public async Task<PageResult<MasterDataResult>> ListAsync(MasterDataType type, int actorId, MasterDataQuery q, CancellationToken ct)
    {
        if (q.Page is < 1 or > 1_000_000 || q.PageSize is < 1 or > 100 || q.Search?.Length > 200 || q.Sort is not ("code" or "name" or "id")) throw Bad("Filter, sort hoặc phân trang không hợp lệ.");
        if (q.Kind is not null && !Kinds.Contains(q.Kind)) throw Bad("Loại đối tác không hợp lệ.");
        if (q.ManufacturerId <= 0) throw Bad("manufacturerId phải lớn hơn 0.");
        var result = await store.ListAsync(ToKind(type), actorId, q.Page, q.PageSize, q.Search?.Trim(), q.Sort, q.Kind,
            q.Country is null ? null : Country(q.Country), q.ManufacturerId, ct);
        return new(result.Items.Select(Map).ToArray(), q.Page, q.PageSize, result.Total);
    }
    public async Task<MasterDataResult> GetAsync(MasterDataType type, int id, int actorId, CancellationToken ct) =>
        Map(await store.GetAsync(ToKind(type), id, actorId, ct) ?? throw new ManagementException("RESOURCE_NOT_FOUND", "Không tìm thấy dữ liệu trong phạm vi được phép.", 404));
    public Task<MasterDataResult> SaveAsync(MasterDataType type, AdminActor actor, int? id, byte[]? version, MasterDataInput input, CancellationToken ct) => Translate(async () =>
    {
        var normalized = input with { Code = Text(input.Code), Name = Text(input.Name) };
        if (type == MasterDataType.Organization)
        {
            if (!Kinds.Contains(input.Kind)) throw Bad("Loại đối tác không hợp lệ.");
            normalized = normalized with { Country = Country(input.Country) };
        }
        if (type == MasterDataType.Vaccine)
        {
            if (input.ManufacturerId <= 0 || input.DosesPerVial <= 0 || input.VialsPerPack <= 0) throw Bad("Nhà sản xuất và quy cách phải hợp lệ.");
            if (input.StorageMin >= input.StorageMax || decimal.Round(input.StorageMin, 2) != input.StorageMin || decimal.Round(input.StorageMax, 2) != input.StorageMax
                || input.StorageMin is < -9999999999999999.99m or > 9999999999999999.99m || input.StorageMax is < -9999999999999999.99m or > 9999999999999999.99m)
                throw Bad("Khoảng nhiệt độ phải tăng dần và có tối đa 2 chữ số thập phân.");
        }
        return Map(await store.SaveAsync(ToKind(type), actor.Id, actor.AuthVersion, id, version,
            new(normalized.Code, normalized.Name, normalized.Country, normalized.Kind, normalized.ManufacturerId,
                normalized.DosesPerVial, normalized.VialsPerPack, normalized.StorageMin, normalized.StorageMax), ct));
    });
    public async Task DeleteAsync(MasterDataType type, AdminActor actor, int id, byte[] version, CancellationToken ct) =>
        await Translate(async () => { await store.DeleteAsync(ToKind(type), actor.Id, actor.AuthVersion, id, version, ct); return true; });
    private static CatalogKind ToKind(MasterDataType type) => type switch { MasterDataType.Warehouse => CatalogKind.Warehouse, MasterDataType.Organization => CatalogKind.Organization, _ => CatalogKind.Vaccine };
    private static MasterDataResult Map(CatalogRow x) => new(x.Id, x.Code, x.Name, Convert.ToBase64String(x.RowVersion), x.Country, x.Kind,
        x.ManufacturerId, x.ManufacturerName, x.DosesPerVial, x.VialsPerPack, x.StorageMin, x.StorageMax, x.StorageReviewRequired);
    private static string Text(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > 200) throw Bad("Mã/tên phải có từ 1 đến 200 ký tự.");
        return value.Trim();
    }
    private static string Country(string? value)
    {
        var code = value?.Trim().ToUpperInvariant();
        if (code is null || code.Length != 2 || !code.All(char.IsAsciiLetter)) throw Bad("Quốc gia phải là mã hai chữ cái.");
        return code;
    }
    private static ManagementException Bad(string message) => new("VALIDATION_ERROR", message, 400);
    private static async Task<T> Translate<T>(Func<Task<T>> operation)
    {
        try { return await operation(); }
        catch (CatalogException e)
        {
            throw e.Error switch
            {
                CatalogError.NotFound => new ManagementException("RESOURCE_NOT_FOUND", "Không tìm thấy dữ liệu.", 404),
                CatalogError.Duplicate => new ManagementException("DUPLICATE_CODE", "Mã đã tồn tại.", 409),
                CatalogError.Stale => new ManagementException("CONCURRENCY_CONFLICT", "Dữ liệu đã thay đổi. Vui lòng tải lại.", 412),
                CatalogError.InUse => new ManagementException("RESOURCE_IN_USE", "Dữ liệu đã được tham chiếu; không được xóa hoặc sửa thuộc tính đã khóa.", 409),
                CatalogError.InvalidManufacturer => new ManagementException("INVALID_MANUFACTURER", "Đối tác phải tồn tại và có loại Manufacturer.", 400),
                _ => new ManagementException("UNAUTHENTICATED", "Phiên quản trị đã thay đổi. Vui lòng đăng nhập lại.", 401)
            };
        }
    }
}
