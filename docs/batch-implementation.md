# Mục 7 — Lô vaccine và truy xuất

Đã triển khai BE theo API → Business → DataAccess. Đã nối [Flutter B5/B6 — lô và truy xuất](flutter-batch-trace-integration.md); chưa có API tạo/Post phiếu nhập/xuất ở mục 8 trở đi. Trace đọc dữ liệu hiện có trong DB; khi chưa có movement thì trả danh sách rỗng, không tạo số dư giả.

## Sáu endpoint

Base `/api/v1`, Bearer token bắt buộc.

| Method / route | Quyền | Request | Response |
|---|---|---|---|
| GET `/batches` | A/W/Q | page/pageSize, vaccineId?, search?, expiryStatus?, expiresBefore?, sort | Page<BatchResponse> |
| GET `/batches/{id}` | A/W/Q | ID | BatchResponse + ETag |
| POST `/batches` | A/W/Q | vaccineId, batchNo, manufacturedAt?, expiresAt | 201 BatchResponse + ETag + Location |
| PUT `/batches/{id}` | A | If-Match; manufacturedAt (ngày hoặc null), expiresAt | BatchResponse + ETag mới |
| DELETE `/batches/{id}` | A | If-Match | 204 |
| GET `/batches/{id}/trace` | A/W/Q | warehouseId?, page/pageSize | batch, warehouses[], movements: Page<MovementResponse> |

Tạo lô:

```json
{
  "vaccineId":1,
  "batchNo":"LOT-2026-001",
  "manufacturedAt":null,
  "expiresAt":"2027-01-31"
}
```

BatchResponse gồm id, vaccineId, vaccineCode, vaccineName, batchNo, manufacturedAt, expiresAt, expiryStatus, daysToExpiry, version. Danh mục lô là metadata chung cho các kho, không nhúng số dư hoặc phiếu của kho khác.

PUT không cho đổi vaccineId/batchNo; phải gửi đủ hai trường ngày, gồm null rõ ràng nếu xóa ngày sản xuất. Trường JSON ngoài contract bị từ chối. ExpiresAt bắt buộc, khác ngày mặc định 0001-01-01; manufacturedAt nếu có phải <= expiresAt. Có thể tạo lô hết hạn để ghi nhận/xử lý, không đồng nghĩa được xuất.

## Hạn dùng và filter

- Ngày nghiệp vụ theo Việt Nam UTC+7; không lấy ngày local của máy server một cách ngẫu nhiên.
- Expired: expiresAt <= hôm nay; NearExpiry: còn 1–30 ngày; Valid: còn hơn 30 ngày. daysToExpiry có thể âm.
- Đây là quy tắc vận hành phần mềm của MVP, không phải kết luận bảo quản/sử dụng áp dụng chung cho mọi vaccine.
- Filter expiryStatus chỉ nhận ba giá trị trên. ExpiresBefore là **nhỏ hơn nghiêm ngặt** ngày truyền vào, không bao gồm đúng ngày đó.
- Search tìm số lô, mã hoặc tên vaccine; tối đa 200 ký tự. Sort expiresAt/batchNo/id, có ID tie-break. Page từ 1, pageSize 1–100, tổng tính trước phân trang.

## Trùng lô và khóa metadata

- Unique vaccineId + batchNo theo collation DB; batchNo trim và tối đa 200 ký tự, không chỉ khoảng trắng. Vaccine phải tồn tại.
- Trùng cùng metadata trả 409 DUPLICATE_CODE và existingBatchId để UI chọn lô cũ.
- Trùng số lô cùng vaccine nhưng khác ngày sản xuất/hạn dùng trả 409 BATCH_METADATA_CONFLICT và existingBatchId; không ghi đè tự động, kể cả khác giữa null và một ngày cụ thể.
- Cùng batchNo ở hai vaccine khác nhau được phép.
- Lô đã có bất kỳ ReceiptDetail nào, kể cả thuộc phiếu nháp, bị chặn PUT/DELETE với 409 RESOURCE_IN_USE.
- Thiếu If-Match trả 428; sai strong ETag 400; version cũ 412; Admin-only mutation bị chặn cho W/Q. No-op PUT vẫn làm mới version và ghi audit.
- Tạo/sửa/xóa và audit cùng transaction. Batch creation dùng cùng application lock với catalog metadata edits để không tạo lô đồng thời với sửa quy cách/nhà sản xuất mà vượt kiểm tra “đã dùng”. Module nhập tương lai cũng phải phối hợp cơ chế khóa khi tạo chi tiết tham chiếu.

## Trace và công thức tồn

```json
{
  "batch":{"id":10,"batchNo":"LOT-2026-001"},
  "warehouses":[{"warehouseId":1,"warehouseName":"Kho HCM","onHand":100,"reserved":15,"available":85}],
  "movements":{"items":[{"id":1,"quantityDelta":100,"sourceType":"Receipt"}],"page":1,"pageSize":20,"totalItems":1,"totalPages":1}
}
```

Ví dụ rút gọn chỉ minh họa shape; response thực tế batch đủ fields và movements chứa dữ liệu nếu có. Warehouse rows chỉ xuất hiện khi batch có segment tại kho đó; lô chưa nhận có warehouses=[]/movements rỗng, không tự tạo dòng tồn.

- OnHand segment = tổng signed QuantityDelta; nhập tăng, xuất và xử lý hàng giảm. Không cộng ReceiptDetail.Quantity lần nữa.
- Reserved chỉ tính reservation Active gắn Issue Draft cùng kho. Không tính reservation inactive hoặc cờ active còn sót trên phiếu Posted.
- Available segment = onHand − reserved nếu Released, còn hạn theo ngày nghiệp vụ và không có IncidentStockSegment chưa ReleasedAt. Nếu không đủ điều kiện thì available=0 nhưng giữ nguyên onHand/reserved.
- Tổng theo warehouse được cộng từ các segment riêng. Một segment vừa cách ly vừa có hai sự cố vẫn chỉ bị loại khỏi khả dụng một lần, không trừ chồng.
- Nếu tồn âm hoặc giữ vượt tồn, trả 409 INVENTORY_INTEGRITY_ERROR; không clamp về 0 để che sai số liệu.
- Trước khi trả movement, kiểm tra nguồn là chứng từ Posted cùng segment/kho và delta khớp dòng nguồn. Không nhất quán trả lỗi 409 chung, không trả tên/số phiếu thuộc kho khác.

MovementResponse: id, stockSegmentId, batchId, vaccineId, warehouseId, quantityDelta, sourceType (Receipt/Issue/StockDisposition), sourceId, sourceDetailId, documentNo, effectiveDate, postedAt. Chưa có tên người nhận vì contract mục 7 không yêu cầu trường đó; sourceId dẫn đến chứng từ khi API tương ứng được triển khai.

## Phạm vi dữ liệu và tính nhất quán

- Admin thấy tất cả kho; W/Q chỉ thấy warehouse assignments hiện tại. Không truyền warehouseId nghĩa là tất cả kho **được phép**.
- Chọn warehouseId không được phép trả 403. Metadata batch vẫn đọc được như danh mục chung; không suy diễn việc đọc metadata cho phép xem số dư toàn hệ thống.
- Áp quyền trước khi tổng hợp, đếm và phân trang movements. Warehouse totals không đổi theo trang movement; movements sort postedAt desc, id desc.
- Trace dùng transaction Serializable để các lần đọc trong response nhất quán; có thể chờ writer trong lúc truy xuất. Chưa thay thế cơ chế khóa tồn/transaction Post của module nghiệp vụ sau này.

## Migration và chạy

Migration VaccineBatchConcurrency chỉ thêm RowVersion vào VaccineBatchRecords, không reset/xóa dữ liệu. Schema SQL đã xuất lại.

```powershell
# Sau khi dừng API Debug đang chạy, tại root project:
dotnet build backend/VaxStock.sln -m:1
dotnet run --project backend/VaxStock.Api --launch-profile http
```

Trong phiên triển khai dùng cấu hình CatalogVerification để không dừng process Debug của người dùng. Test:

```powershell
dotnet build backend/VaxStock.Tests/VaxStock.Tests.csproj -c CatalogVerification -m:1
dotnet test backend/VaxStock.Tests -c CatalogVerification --no-build
./backend/scripts/test-auth.ps1 -Suite batch -BuildConfiguration CatalogVerification
```

Suite batch tạo DB test GUID riêng, chạy migrations, seed A/W/Q rồi nạp fixture hai kho; sau đó dọn đúng DB test. Fixture SQL tạo movement/giữ/cách ly để kiểm tra trace, không có nghĩa API nhập/xuất đã được triển khai. Kiểm thử gồm ranh giới hạn dùng, trùng metadata, ETag, khóa lô đã dùng, scope/count/paging, ba loại nguồn movement, cách ly/holds, expired availability và dữ liệu không nhất quán. Unit test có ranh giới UTC+7 lúc 17:00 UTC.

Đã xác minh 59 kiểm tra HTTP batch/trace và SQL audit; 22 test BE đạt, build không có warning/error. Kiểm thử dữ liệu sai kho trả lỗi chung thay vì số phiếu bí mật; tồn không hợp lệ không bị che bằng clamp.

Giới hạn còn lại: chưa có Idempotency-Key replay bền vững; unique pair bảo vệ duplicate create nhưng không replay kết quả POST. Đã có UI Flutter cho lô/truy xuất; chưa có API nghiệp vụ tạo biến động. Chưa có truy xuất người nhận trực tiếp hoặc thu hồi hàng đã giao.
