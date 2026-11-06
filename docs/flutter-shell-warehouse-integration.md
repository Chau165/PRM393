# Flutter B1/B2 — Shell đăng nhập và danh mục Kho

## Phần đã nối

- Sau đăng nhập/khôi phục phiên, mở shell dùng SessionUser từ BE. Menu có Tài khoản, Kho, Đối tác và Vaccine; phần B3/B4 được mô tả tại [tài liệu Đối tác/Vaccine](flutter-partner-vaccine-integration.md).
- Desktop có thanh điều hướng bên trái; màn hình nhỏ dùng drawer. Tài khoản, cập nhật thông tin, đổi mật khẩu và logout tiếp tục dùng auth API.
- Danh mục Kho gọi `/api/v1/warehouses`: tìm mã/tên, sort code/name, page/pageSize, đọc chi tiết, tạo/sửa/xóa theo quyền.
- Admin có thêm/sửa/xóa; W/Q chỉ xem. BE vẫn là nơi thực thi quyền, UI không thay thế kiểm tra của server.
- Không gọi WarehouseAppState hoặc SharedPreferences để đọc/ghi danh mục này. State danh sách chỉ nằm trong bộ nhớ của phiên, được hủy khi kết thúc phiên.

## Luồng sử dụng

1. Đăng nhập bằng tài khoản BE.
2. Mở Kho trong menu.
3. Chọn tìm kiếm/sắp xếp/số dòng hoặc chuyển trang; dữ liệu và tổng lấy từ BE, không lọc riêng một trang ở client.
4. Xem chi tiết để lấy thông tin mới nhất. Admin có thể mở form sửa hoặc hộp xác nhận xóa; mỗi lần đều tải detail trước khi thực hiện.
5. Tạo/sửa thành công hoặc xác nhận xóa xong sẽ tải lại danh sách và cập nhật kho hiệu lực trong thông tin tài khoản. Xóa dòng cuối trang cuối tự quay về trang còn dữ liệu.

Danh sách có trạng thái loading, rỗng, lỗi và thử lại. Search debounce 350 ms, Enter tìm ngay; query được URL-encode, không nối chuỗi input vào URL. Response cũ đến chậm không được ghi đè tìm kiếm mới.

## ETag và lỗi nghiệp vụ

- API client có response metadata để repository đọc header ETag, đồng thời giữ method request trả JSON tương thích auth cũ.
- Khi PUT/DELETE, gửi nguyên strong ETag của GET detail trong If-Match. Body chỉ có code/name; không gửi version/status/quyền từ UI.
- 412: giữ form nhưng khóa lưu, cho người dùng chọn tải lại và bỏ thay đổi chưa lưu. Sau đó hiển thị bản mới để xem lại và lưu rõ ràng; không tự dùng ETag mới để ghi đè bản nháp cũ.
- 409 DUPLICATE_CODE: hiện hướng dẫn sửa mã; RESOURCE_IN_USE: giải thích kho đã có phân quyền/chứng từ, không thể xóa hay đổi mã, vẫn có thể sửa tên.
- 404: không tìm thấy hoặc ngoài quyền; tải lại danh sách khi đóng trường hợp phù hợp.
- 403: báo thiếu quyền, không tự logout. 401: auth kết thúc phiên và đưa về login.
- Không tự retry POST/PUT/DELETE. Nếu kết quả tạo chưa xác định do mất kết nối/5xx, yêu cầu đóng và tải lại danh sách; PUT/DELETE yêu cầu đọc lại phiên bản trước khi tiếp tục.

Dialogs nằm trong Navigator riêng của phiên. Khi token hết hạn/bị thu hồi hoặc logout, cả shell lẫn form/xác nhận đang mở bị tháo bỏ; không để form của phiên cũ nằm trên màn hình login.

## File chính

| File | Trách nhiệm |
|---|---|
| lib/features/server_shell.dart | Điều hướng theo phiên và layout desktop/mobile |
| lib/features/warehouses/data/warehouse_repository.dart | HTTP và map DTO kho/phân trang/ETag |
| lib/features/warehouses/state/warehouse_controller.dart | State truy vấn, latest-response-wins và xử lý trang cuối |
| lib/features/warehouses/server_warehouses_page.dart | Danh sách, toolbar, quyền và mở detail/form |
| lib/features/warehouses/warehouse_dialogs.dart | Form, xác nhận xóa, reload 412 và lỗi nghiệp vụ |
| lib/core/network/api_client.dart | Bearer, timeout, response headers, query và If-Match |

## Chạy

API phải chạy bản code mới nhất đã có CRUD Kho và CORS expose ETag. Nếu đang chạy BE cũ, dừng bằng terminal của cậu rồi chạy lại:

```powershell
dotnet run --project backend/VaxStock.Api --launch-profile http
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:5109/api/v1/
```

Hai lệnh chạy ở hai terminal tại root project. Local CORS phải có đúng origin localhost:5173; BE đã expose ETag/Location và cho phép If-Match trong preflight. Không bật CORS wildcard để khắc phục sai port.

## Kiểm thử

```powershell
flutter test
flutter analyze
flutter build web --debug
./backend/scripts/test-auth.ps1 -Suite warehouse-fe -BuildConfiguration CatalogVerification
```

Suite warehouse-fe cần BE build CatalogVerification trước; tạo SQL database GUID riêng, migrate/seed, start API ẩn, chạy **repository Flutter bằng HTTP thật**, rồi dọn DB/process của test. Không sửa/xóa dữ liệu VaxStockDev. Kiểm tra CRUD/ETag/stale write, role/quyền kho, kho đang được tham chiếu và header CORS cần cho Web.

Trong lần chạy flutter test thông thường, live test được skip nếu không có WAREHOUSE_LIVE_API_URL; script trên thiết lập biến môi trường và chạy test đó riêng. Không cần đưa password/token thật vào source hoặc dart-define.

Widget tests có Admin CRUD, W read-only trên mobile, stale 412 bắt buộc reload, 409 không xóa dữ liệu tham chiếu và 401 khi đang mở form. Repository/controller tests kiểm tra encode filter/If-Match/204, response chậm và fallback trang cuối.

Kết quả xác minh: toàn bộ 38 Flutter tests đạt; live API test được skip trong lượt thường rồi chạy riêng qua harness và đạt, gồm CORS expose ETag/preflight If-Match. Analyzer không có issue và build Web debug thành công. Chưa kiểm thử thao tác trên thiết bị Windows/Android thực tế.

## Giới hạn

Tài liệu này mô tả B1/B2. Shell hiện đã nối thêm [Đối tác/Vaccine B3/B4](flutter-partner-vaccine-integration.md) và [Lô/truy xuất B5/B6](flutter-batch-trace-integration.md); nhập/xuất chưa nối. Màn hình local cũ vẫn được giữ trong source/tests cho bước chuyển đổi tiếp theo, không nằm trong điều hướng server hiện tại. Bản Web reload trang vẫn yêu cầu login lại vì token giữ trong bộ nhớ; Windows native chưa kiểm thử do thiếu C++ toolchain.

