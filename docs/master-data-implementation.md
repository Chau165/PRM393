# Mục 6 — API danh mục đã triển khai

Phạm vi: BE 3 tầng cho Kho, Đối tác và Vaccine. Flutter đã nối [shell và Kho](flutter-shell-warehouse-integration.md), cùng [Đối tác/Vaccine](flutter-partner-vaccine-integration.md). API lô mục 7 đã triển khai riêng tại [lô và trace](batch-implementation.md).

## Endpoint

Base `/api/v1`, tất cả request có Bearer token. GET cho tài khoản đăng nhập; POST/PUT/DELETE chỉ Admin.

| Resource | List | Detail | Create | Update | Delete |
|---|---|---|---|---|---|
| Kho | GET /warehouses | GET /warehouses/{id} | POST /warehouses | PUT /warehouses/{id} | DELETE /warehouses/{id} |
| Đối tác | GET /organizations | GET /organizations/{id} | POST /organizations | PUT /organizations/{id} | DELETE /organizations/{id} |
| Vaccine | GET /vaccines | GET /vaccines/{id} | POST /vaccines | PUT /vaccines/{id} | DELETE /vaccines/{id} |

POST trả 201 + Location + ETag. GET detail/PUT trả 200 + ETag. DELETE trả 204. PUT/DELETE bắt buộc If-Match từ GET mới nhất: thiếu 428, sai strong ETag 400, stale 412. Không xóa cascade dữ liệu tham chiếu.

## Request/response

Kho POST/PUT:

```json
{"code":"HCM-02","name":"Kho HCM 02"}
```

Response: id, code, name, version.

Đối tác POST/PUT:

```json
{"code":"NSX-01","name":"Nhà sản xuất mẫu","country":"VN","kind":"Manufacturer"}
```

Response: id, code, name, country, kind, version. Kind chỉ Manufacturer/Supplier/Recipient/Carrier. Country là mã hai chữ cái, chuẩn hóa uppercase; mới kiểm tra định dạng, chưa có danh mục quốc gia riêng. Một đối tác một vai trò trong MVP.

Vaccine POST/PUT:

```json
{
  "code":"VAC-01",
  "name":"Vaccine mẫu",
  "manufacturerId":1,
  "dosesPerVial":1,
  "vialsPerPack":10,
  "storageMin":2,
  "storageMax":8
}
```

Response: id, code, name, manufacturerId, manufacturerName, dosesPerVial, vialsPerPack, storageMin, storageMax, version, storageReviewRequired. Nhiệt độ trong ví dụ là dữ liệu giả lập; giá trị phải được nhập theo đúng tài liệu sản phẩm, không phải khoảng mặc định cho mọi vaccine.

StorageReviewRequired=true chỉ trong response PUT đã thay đổi khoảng bảo quản; đây là thông báo cần rà soát cho thao tác vừa thực hiện, không phải trạng thái chất lượng được lưu. Các GET hoặc update không đổi khoảng trả false. Thay đổi và cờ này được ghi audit để truy vết; không tự giải phóng/cách ly tồn hoặc tạo sự cố.

## Tìm kiếm/phân trang

List trả `{items,page,pageSize,totalItems,totalPages}`; page từ 1, pageSize 1–100, mặc định 20. Search theo code/name tối đa 200 ký tự. Sort code/name/id, luôn có ID để ổn định thứ tự. Sai sort/filter trả 400.

- Kho: search, sort, page, pageSize. W/Q chỉ thấy kho được cấp; Admin thấy tất cả. GET kho ngoài quyền trả 404, nhất quán với quy ước resource-by-ID trong đặc tả; GET auth/me vẫn cung cấp quyền hiệu lực.
- Đối tác: thêm kind và country.
- Vaccine: thêm manufacturerId.
- TotalItems và TotalPages tính sau filter/quyền, trước phân trang. Không nhúng tồn kho vào response danh mục.

## Validation và khóa dữ liệu đã dùng

- Mã/tên bắt buộc, trim, không chỉ khoảng trắng, tối đa 200 ký tự. Mã unique theo từng bảng và collation SQL Server, trùng trả 409 DUPLICATE_CODE. Không đổi hoa/thường của mã ngầm; khác biệt case theo collation có thể vẫn bị coi trùng.
- ManufacturerId phải trỏ Organization loại Manufacturer, nếu không trả 400 INVALID_MANUFACTURER.
- Quy cách là số nguyên >0. StorageMin/Max bắt buộc, min < max, đúng precision SQL decimal(18,2); không âm thầm làm tròn quá hai chữ số thập phân.
- Nếu có tham chiếu, khóa đổi code và DELETE trả 409 RESOURCE_IN_USE. Tham chiếu gồm cả assignment hoặc phiếu nháp, không chỉ phiếu Posted.
- Đối tác đã dùng khóa đổi kind để không làm sai loại nhà sản xuất/nhà cung cấp của dữ liệu trước đó.
- Vaccine đã có lô khóa đổi manufacturerId, dosesPerVial, vialsPerPack. Vẫn đổi được name và khoảng bảo quản có audit/cờ rà soát.
- Kho được kiểm tra assignment/receipt/issue/segment/incident/disposition; đối tác được kiểm tra vaccine/receipt/issue/disposition/shipment; vaccine được kiểm tra batch. FK Restrict là lớp bảo vệ bổ sung. Các module mới phải bổ sung kiểm tra khi thêm quan hệ mới.

## Giao dịch, quyền và audit

Mutation dùng cùng SQL application lock quản trị với API cấp quyền/đổi role để tránh tranh chấp danh mục và assignment; actor Admin/AuthVersion được kiểm tra lại sau khi lấy khóa. Đây là lựa chọn đơn giản cho khối lượng quản trị của MVP, không phải khóa riêng cho nghiệp vụ tồn sau này.

Thay đổi entity và audit cùng transaction; đọc kết quả trước commit. RowVersion bảo vệ stale version, kể cả no-op PUT cũng sinh ETag mới. Audit có Create/Update/DeleteWarehouse, Organization, Vaccine và before/after; không chứa password/hash/token.

Chưa có Idempotency-Key replay bền vững cho toàn hệ thống. Unique code chống tạo trùng nhưng không thay thế replay response; client không tự retry mù POST khi mất kết nối. ETag bảo vệ PUT/DELETE.

## Migration và chạy

Migration MasterDataConcurrency thêm RowVersion cho ba bảng và CK_Organization_Kind. Không xóa/reset dữ liệu. Trước khi áp vào DB cũ phải rà kind ngoài danh sách; không tự đổi loại đối tác để vượt constraint. Dữ liệu VaxStockDev đã được kiểm tra và migration đã áp dụng.

Nếu API đang chạy giữ DLL Debug, dừng bằng terminal của cậu rồi build/start lại để cập nhật code:

```powershell
dotnet build backend/VaxStock.sln -m:1
dotnet run --project backend/VaxStock.Api --launch-profile http
```

Trong phiên triển khai, bản Debug đang chạy nên đã dùng cấu hình CatalogVerification riêng để build/test, không dừng process của người dùng:

```powershell
dotnet build backend/VaxStock.Tests/VaxStock.Tests.csproj -c CatalogVerification -m:1
./backend/scripts/test-auth.ps1 -Suite catalog -BuildConfiguration CatalogVerification
./backend/scripts/test-auth.ps1 -Suite admin -BuildConfiguration CatalogVerification
./backend/scripts/test-auth.ps1 -Suite auth -BuildConfiguration CatalogVerification
```

Mỗi suite dùng database test GUID riêng, tự dọn. Catalog fixture SQL tạo dữ liệu có tham chiếu để kiểm tra khóa sửa/xóa, không phải API nhập/lô đã được triển khai. Suite kiểm tra CRUD ba resource, quyền, filter/page, duplicate đồng thời, ETag, nhà sản xuất, precision, khóa dữ liệu đã dùng, cờ rà soát và audit.

## Bước tiếp theo

API lô/hạn dùng/truy xuất đã có ở mục 7. Các thao tác nhập sau này cần phối hợp khóa/transaction với cập nhật metadata danh mục để không tạo tham chiếu đồng thời với một thay đổi bị cấm. Flutter hiện nối Kho, Đối tác và Vaccine; [lô/truy xuất cũng đã nối](flutter-batch-trace-integration.md). Các màn hình local cũ không nằm trong shell server.

