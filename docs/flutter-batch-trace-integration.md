# Flutter B5/B6 — Lô vaccine và truy xuất

Đã nối giao diện Flutter vào các API mục 7, dùng cùng phiên đăng nhập và shell B1–B4. Sau đăng nhập, mở **Lô vaccine**; chọn biểu tượng lịch sử để xem chi tiết và truy xuất lô.

## B5 — Danh mục lô

- Danh sách `/api/v1/batches` tìm số lô hoặc mã/tên vaccine; lọc vaccine, trạng thái hạn và hạn dùng trước ngày; sắp xếp expiresAt/batchNo/id; phân trang trên server.
- Bộ chọn vaccine có tìm kiếm, chuyển trang; không giới hạn ở trang danh mục đầu tiên.
- Admin/W/Q đều tạo được lô. Form gồm vaccine, số lô, ngày sản xuất tùy chọn, hạn sử dụng bắt buộc.
- Chỉ Admin sửa ngày hoặc xóa. Vaccine và số lô của lô đã tạo luôn cố định. BE chặn sửa/xóa nếu lô đã được dùng trên phiếu nhập, kể cả phiếu nháp.
- Ngày giữ nguyên chuỗi DateOnly `YYYY-MM-DD`, không chuyển UTC/local gây lệch ngày. Kiểm tra ngày tồn tại và ngày sản xuất <= hạn dùng; bỏ trống NSX gửi null rõ ràng. PUT chỉ chứa manufacturedAt/expiresAt.
- Trạng thái và số ngày đến hạn lấy từ BE, dùng ngày nghiệp vụ UTC+7. Expired gồm ngày hết hạn hôm nay; NearExpiry là 1–30 ngày. Đây là quy tắc MVP; giao diện không suy luận vaccine còn dùng được chỉ từ nhãn hạn.
- `expiresBefore` là nhỏ hơn nghiêm ngặt ngày chọn, không gồm đúng ngày đó. Lô hết hạn vẫn có thể được ghi nhận; tạo metadata lô không làm tăng tồn.

## Xung đột và an toàn thao tác

- GET detail lấy ETag mới trước sửa/xóa; gửi If-Match. 412 khóa xác nhận đến khi người dùng chủ động tải lại, bỏ bản nháp và kiểm tra bản mới.
- Trùng vaccine/số lô: hiện DUPLICATE_CODE hoặc BATCH_METADATA_CONFLICT. API client giữ existingBatchId; nút **Mở lô hiện có** dẫn đến chi tiết/truy xuất để đối chiếu, không tự ghi đè metadata hoặc gửi lại POST.
- RESOURCE_IN_USE khóa sửa/xóa và giải thích phiếu nhập đang tham chiếu. 404 cho đóng để tải lại danh sách. 403 báo thiếu quyền. 401 gỡ cả phiên, kể cả route trace và dialog đang mở.
- Không tự retry ghi. Nếu mất kết nối/5xx khiến kết quả chưa xác định, tạo yêu cầu đóng và kiểm tra danh sách; sửa/xóa yêu cầu GET lại, xem kết quả rồi mới xác nhận tiếp.
- Truy vấn mới bỏ response cũ đến chậm; controller danh sách bị hủy khi logout. Đổi trang không dùng dữ liệu local cũ.

## B6 — Chi tiết và truy xuất

API `/api/v1/batches/{id}/trace` trả metadata batch đầy đủ, tồn theo kho và trang biến động. Màn hình hiển thị:

- Vaccine, số lô, NSX/HSD, trạng thái hạn và số ngày đến hạn từ BE.
- Từng kho: tồn vật lý, giữ chỗ, khả dụng; đơn vị là lọ. Không lấy tổng một trang movements để tự suy ra tồn.
- Biến động: số chứng từ, loại nhập/xuất/xử lý hàng, lượng tăng/giảm, kho, segment, ID chứng từ/dòng, ngày nghiệp vụ và thời điểm ghi sổ UTC+7.
- Tìm/chọn kho bằng danh mục phân trang đã áp quyền; mặc định tất cả kho được phép. Đổi hoặc bỏ lọc kho quay về trang 1. BE vẫn kiểm tra scope, kể cả khi quyền đã thay đổi từ lúc chọn kho.
- Tồn theo kho độc lập trang movements. Không có dữ liệu thì hiện thông báo rỗng, không tạo hàng tồn 0 giả. Lỗi integrity hiện thông báo cần kiểm tra dữ liệu; không clamp số âm hoặc cộng/trừ tại FE.

Chưa có API chứng từ nhập/xuất/xử lý nên các số chứng từ trong trace chỉ để xem, chưa mở chi tiết chứng từ. Không có thao tác Post/FEFO hoặc thay đổi chất lượng trong B5/B6.

## File và cách kiểm thử

| File | Vai trò |
|---|---|
| lib/features/batches/batch_repository.dart | DTO, DateOnly, CRUD, query, trace và ETag |
| lib/features/batches/batch_controller.dart | State danh sách theo phiên, bỏ response cũ và xử lý trang cuối |
| lib/features/batches/server_batches_page.dart | Danh sách, bộ lọc, quyền và điều hướng |
| lib/features/batches/batch_dialog.dart | Tạo/sửa/xóa, trùng metadata và tải lại phiên bản |
| lib/features/batches/reference_picker.dart | Tìm/chọn vaccine hoặc kho qua nhiều trang |
| lib/features/batches/batch_trace_page.dart | Chi tiết lô, tồn theo kho và phân trang lịch sử |

```powershell
flutter --no-version-check test --no-pub
flutter --no-version-check analyze --no-pub
flutter --no-version-check build web --no-pub
./backend/scripts/test-auth.ps1 -Suite batch-fe -BuildConfiguration CatalogVerification
```

Suite batch-fe tạo database GUID riêng, nạp batch-fixture SQL có nhập/xuất/xử lý, giữ chỗ, cách ly và nhiều kho; gọi repository Flutter với API thật rồi dọn đúng database tạm trong finally. Không tạo dữ liệu fixture trong database vận hành. Cấu hình CatalogVerification dùng binary BE đã build; nếu cần build lại:

```powershell
dotnet build backend/VaxStock.Tests/VaxStock.Tests.csproj -c CatalogVerification -m:1
```

Test widget kiểm tra desktop/mobile, quyền tạo so với sửa/xóa, ngày không hợp lệ, ETag cũ, lô đã dùng, mở lô trùng, lọc kho, phân trang trace, trạng thái rỗng và 401. Test live được skip khi chạy Flutter test thông thường mà chưa có URL/password do harness cấp.

Đã xác minh trong phiên triển khai: 57 test Flutter đạt (3 test live skip trong lần chạy thông thường), suite batch-fe chạy riêng với ASP.NET/SQL đạt, analyzer không có issue.
