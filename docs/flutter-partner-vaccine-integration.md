# Flutter B3/B4 — Đối tác và Vaccine

Đã nối vào shell đăng nhập bằng API ASP.NET, cùng cơ chế phiên của B1/B2. Mở menu **Đối tác** hoặc **Vaccine** sau đăng nhập. Desktop dùng bảng cuộn ngang, màn hình nhỏ dùng danh sách thẻ.

## B3: Đối tác

- Danh sách gọi `/api/v1/organizations`, tìm mã/tên, lọc loại và quốc gia, sắp xếp mã/tên, phân trang trên server.
- Xem chi tiết; Admin thêm/sửa/xóa mã, tên, quốc gia hai chữ cái và loại: nhà sản xuất, nhà cung cấp, đơn vị nhận, đơn vị vận chuyển.
- Chuẩn hóa quốc gia thành chữ hoa. Đối tác đã được tham chiếu bị BE chặn xóa hoặc đổi mã/loại; UI giải thích lỗi và giữ bản nháp.

## B4: Vaccine

- Danh sách gọi `/api/v1/vaccines`, tìm mã/tên, lọc nhà sản xuất, sắp xếp và phân trang trên server.
- Admin thêm/sửa/xóa; form gồm mã, tên, nhà sản xuất, liều/lọ, lọ/hộp, nhiệt độ tối thiểu/tối đa.
- Bộ chọn nhà sản xuất gọi organizations với `kind=Manufacturer`, có tìm kiếm và chuyển trang; tải lại detail khi chọn để kiểm tra loại. Không dùng danh sách cố định hoặc chỉ lấy trang đầu.
- Quy cách là số nguyên dương; nhiệt độ nhận dấu âm, dấu phẩy hoặc dấu chấm, tối đa hai chữ số thập phân và min < max. Không tự điền một khoảng nhiệt độ chung cho mọi vaccine.
- Đổi điều kiện bảo quản có thông báo trước khi lưu. Khi response có `storageReviewRequired`, hiện cảnh báo cần rà soát các lô liên quan; thao tác này không tự đổi trạng thái chất lượng lô.

## Phiên, cạnh tranh và lỗi

- Admin có quyền ghi, W/Q chỉ xem; BE tiếp tục thực thi quyền. Dữ liệu không lưu vào kho local cũ.
- Sửa/xóa luôn GET detail trước, dùng ETag trong If-Match. Body chỉ gửi các trường nghiệp vụ.
- 412 yêu cầu người dùng chủ động tải lại, bỏ bản nháp cũ rồi xem lại trước khi lưu. Không tự lấy version mới để ghi đè.
- 409 hiện lỗi trùng mã hoặc dữ liệu đang được sử dụng; 403 báo thiếu quyền; 401 kết thúc toàn bộ phiên, kể cả các dialog lồng nhau.
- Không tự retry thao tác ghi khi lỗi mạng/5xx khiến kết quả chưa xác định. Tạo mới yêu cầu đóng và kiểm tra danh sách; sửa/xóa cần đọc lại dữ liệu.
- Tìm kiếm debounce 350 ms, bỏ response cũ đến chậm. Controller bị hủy khi logout.

## File và kiểm thử

- `lib/features/catalog/data/catalog_repository.dart`: DTO, truy vấn, CRUD, ETag.
- `lib/features/catalog/state/catalog_controller.dart`: state danh sách và phân trang.
- `lib/features/catalog/server_catalog_page.dart`: danh sách desktop/mobile, bộ lọc và phân quyền UI.
- `lib/features/catalog/catalog_dialogs.dart`: form, xác nhận xóa và xử lý xung đột.
- `lib/features/catalog/manufacturer_picker.dart`: chọn nhà sản xuất có phân trang.

```powershell
flutter --no-version-check test --no-pub
flutter --no-version-check analyze --no-pub
flutter --no-version-check build web --no-pub
./backend/scripts/test-auth.ps1 -Suite catalog-fe -BuildConfiguration CatalogVerification
```

Suite `catalog-fe` dùng database SQL tạm riêng và dọn trong finally; kiểm tra repository Flutter với API thật: tạo đối tác/vaccine, lọc, ETag, 412, 403, tham chiếu 409, nhà sản xuất không hợp lệ và cảnh báo đổi bảo quản. Khi chạy toàn bộ Flutter test thông thường, test live được skip vì chưa có URL/mật khẩu do harness cấp.

Phần lô vaccine/trace đã nối riêng tại [B5/B6](flutter-batch-trace-integration.md).
