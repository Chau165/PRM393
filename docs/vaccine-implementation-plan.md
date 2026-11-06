# Kế hoạch triển khai VaxStock theo kiến trúc 3 tầng

Trạng thái: kế hoạch thực hiện; **chưa refactor hoặc code API trong bước lập kế hoạch này**.

Tài liệu đầu vào:

- [Đặc tả API](vaccine-api-specification.md).
- [Schema và flow database](vaccine-database-flow.md).
- [Hai phương án phân công nhóm](vaccine-warehouse-task-allocation.md).

## 1. Mục tiêu và thời gian

Tiếp tục mốc **1,5 tuần ≈ 10 ngày lịch**, D1 là ngày thực sự bắt đầu. Không gắn lịch cứng khi nhóm chưa chốt ngày bắt đầu/số giờ làm mỗi ngày. Đây là mục tiêu cho nhóm 3–4 người làm song song theo module, tái sử dụng Flutter hiện có; không phải cam kết toàn bộ đặc tả API hoàn thành trong 10 ngày hoặc khối lượng cho một người làm bán thời gian.

Mục tiêu cuối đợt là một bản chạy tích hợp:

```text
Đăng nhập → Danh mục/lô → Nhập → Chờ đánh giá → Giải phóng
→ FEFO/giữ hàng → Xuất → Đối chiếu tồn/báo cáo
                         ↓ khi có sự cố
                  Cách ly → Đánh giá
                  → Gỡ chặn hoặc xuất trả/tiêu hủy
```

Hồ sơ quốc tế tối giản làm sau khi vòng tồn kho đã ổn định. Không làm tất cả route trong đặc tả cùng một lúc.

## 2. Hiện trạng và phạm vi

Đã có: Flutter quản lý kho chạy local; solution ASP.NET Core .NET 10; EF Core/SQL Server; 21 bảng nghiệp vụ và hai migration; script kiểm tra DB. Code hiện chỉ có endpoint `/health`, chưa có JWT, phân lớp hoặc API nghiệp vụ.

| Mức | Nội dung trong đợt này |
|---|---|
| P0 — bắt buộc | Tách 3 tầng; migration cho hợp đồng; auth/quyền kho; danh mục và lô tối thiểu; nhập/Post; tồn; chất lượng; sự cố và các lượt chặn; FEFO; nháp giữ hàng/sửa/hủy/Post xuất; xử lý hàng có duyệt; báo cáo tồn cơ bản; Flutter nối luồng chính |
| P1 — khi P0 đạt | Hồ sơ quốc tế tối giản và liên kết phiếu; UI quản trị tài khoản/quyền đầy đủ; các bộ lọc nâng cao; trang xem audit; dashboard đầy đủ; reset password qua UI |
| Ngoài đợt | Lọ đã mở, IoT, file upload, thông báo nền, chuyển kho, kiểm kê, thu hồi hàng đã giao, đảo phiếu, refresh token và kế toán đa tiền tệ |

P0 vẫn ghi audit cho hành động quan trọng; chỉ **màn hình/API tra cứu audit tổng quát** có thể hoãn. API quản trị user/assignment tối thiểu cần để demo được cấp/gỡ quyền; có thể dùng API collection trước khi hoàn thiện UI quản trị.

Phạm vi mới ưu tiên sự cố và xử lý hàng theo các quyết định nghiệp vụ gần đây; thay thế giả định “sự cố/tiêu hủy để sau” trong bản phân công cũ. Không hoãn logic chặn xuất nhưng vẫn quảng bá đã quản lý sự cố.

## 3. Cấu trúc và phụ thuộc project

```text
backend/
  VaxStock.sln
  VaxStock.Api/
    Controllers/
    Contracts/Requests/
    Contracts/Responses/
    Mapping/
    Middleware/
    Program.cs
  VaxStock.Business/
    Interfaces/
    Services/
    Models/Commands/
    Models/Queries/
    Models/Results/
    Exceptions/
  VaxStock.DataAccess/
    Entities/
    Data/
    Configurations/
    Interfaces/
    Repositories/
    Transactions/
    Migrations/
  VaxStock.Tests/
    Unit/
    Integration/
```

Chọn kiến trúc phân lớp truyền thống để đơn giản trong đợt này:

- `Api → Business → DataAccess`. API cũng tham chiếu DataAccess **chỉ tại composition root** để đăng ký DI/provider.
- Interface service nằm trong Business; interface repository/transaction nằm trong DataAccess cùng implementation. Không tạo project tham chiếu ngược gây vòng lặp.
- Controller không dùng DbContext/repository/entity trực tiếp. Business không dùng API DTO, HttpContext, IActionResult hoặc truy vấn EF trực tiếp; truy vấn qua interface DataAccess.
- EF entity thuộc DataAccess; Business ánh xạ kết quả sang Business Result trước khi trả cho API. Request/Response mapping thủ công, không thêm thư viện chỉ để map vài field.
- Không thêm Generic Repository cho mọi bảng. Repository tập trung aggregate hoặc truy vấn thực tế; không expose IQueryable ra controller.
- Một transaction abstraction phục vụ toàn bộ Post/giữ hàng/cách ly. Repository không tự SaveChanges/commit rời rạc trong cùng nghiệp vụ.

Đây là quy ước triển khai 3-layer của đợt này, không đồng thời chuyển sang Clean Architecture/CQRS framework/microservices.

## 4. Backlog theo thứ tự phụ thuộc

Mã task có thể dùng làm tên issue/PR. “Đạt” nghĩa là đã chạy với API/database thật, không chỉ compile hoặc có màn hình mock.

| Mã | Công việc | Phụ thuộc | Đầu ra và tiêu chí đạt |
|---|---|---|---|
| BE-01 | Tạo Business/DataAccess; chuyển entity, DbContext và migration; nối DI | Hiện trạng | Solution build; migration IDs cũ giữ nguyên; DB đang có không bị tạo lại bảng hoặc mất dữ liệu |
| BE-02 | Migration RowVersion/AuthVersion/IdempotencyRequest; unique link; warehouse hồ sơ và enum theo contract | BE-01 | Cài mới và nâng cấp DB đều được; không có pending model changes; dữ liệu cũ không bị tự gán kho sai |
| BE-03 | Response lỗi, validation, paging, thời gian, current user, ETag và idempotency | BE-01/02 | Mã lỗi nhất quán; stale version 412; request replay đúng không tạo thêm dữ liệu; không log secret |
| BE-04 | Auth/login/me/logout/change password; user và quyền kho tối thiểu | BE-02/03 | Băm password; token có AuthVersion; gỡ kho/đổi mật khẩu có hiệu lực; không lộ hash |
| BE-05 | Danh mục kho/đối tác/vaccine, tạo/tìm lô và khóa sửa metadata đã dùng | BE-04 | CRUD được phép; unique và FK có lỗi dễ hiểu; chọn lô đã có khi trùng metadata |
| BE-06 | Transaction/locking cho tồn; query segment/summary/movement | BE-02/03 | Một cơ chế khóa chung, thứ tự khóa thống nhất; truy vấn chỉ kho được phép; không tính trùng lượng nhập |
| BE-07 | Phiếu nhập draft/update/delete/Post | BE-05/06 | Post tăng vật lý, tạo Pending, chưa khả dụng; retry không nhập hai lần |
| BE-08 | Quyết định chất lượng và lịch sử | BE-07 | Q giải phóng/cách ly/từ chối đúng quyền, có reason/audit; không giải phóng khi còn hold |
| BE-09 | Sự cố/tạo phạm vi/investigate/gỡ hold/close | BE-06/08 | Chặn segment nguyên tử; nhiều sự cố độc lập; đóng sự cố không tự cho xuất; không hạ Rejected thành Quarantined |
| BE-10 | Preview FEFO, nháp xuất và reservations | BE-05/06/08 | Preview không giữ; save mới giữ; thiếu hàng rollback; sửa lỗi giữ nguyên phân bổ cũ |
| BE-11 | Cancel/Post xuất và kiểm tra lại | BE-09/10 | Cancel trả giữ; Post giảm tồn đúng một lần; chặn hết hạn/cách ly/hold; xử lý cạnh tranh thật |
| BE-12 | Phiếu xử lý: draft, approve, revoke, cancel, Post | BE-06/09/11 | Không giảm tồn khi duyệt; Post có đủ tồn vật lý sau giữ; không cần Released để xử lý hàng bị chặn |
| BE-13 | Báo cáo XNT, trace và cảnh báo hạn dùng cơ bản | BE-07/11/12 | Có cột disposed; tổng trước phân trang; báo cáo đối chiếu movement, đúng ngày/kho |
| BE-14 | Hồ sơ quốc tế/link/transition | BE-02/05/07/11 | Một hồ sơ một kho, một phiếu tối đa một hồ sơ; status không làm biến động tồn |
| BE-15 | Dashboard, audit query đầy đủ, readiness | BE-13/14 | Không lộ kho khác; readiness kiểm tra SQL; dashboard tính theo quyền |
| FE-01 | API client, base URL, token, xử lý 401/403/error, version/idempotency | API contract + BE-04 | Login/me thật, secret không log; retry đúng quy tắc; không tự ghi đè khi 412 |
| FE-02 | Danh mục/lô và nhập | FE-01 + BE-05/07 | Tạo/chọn lô → nhập → Post → thấy Pending từ BE |
| FE-03 | Tồn, chất lượng và sự cố | FE-01 + BE-08/09 | Gỡ đúng hold, hiển thị blockReasons; không coi close là Released |
| FE-04 | FEFO, nháp/sửa/cancel/Post xuất | FE-01 + BE-10/11 | Preview → giữ → Post; lỗi phân bổ yêu cầu tải lại; không optimistic trừ tồn |
| FE-05 | Xử lý hàng, báo cáo và hồ sơ theo mức ưu tiên | FE-03/04 + BE-12/13/14 | Luồng duyệt xử lý và số liệu khớp; hồ sơ nếu làm được phải gọi API thật |

BE-06 phải có thiết kế cơ chế khóa trước khi các service kho bắt đầu ghi dữ liệu; không để mỗi người tự chọn một cách khóa khác nhau. Trước khi BE API sẵn sàng, Flutter được dựng UI bằng mock đúng contract nhưng chưa coi task hoàn thành.

## 5. Lịch thực hiện 10 ngày

| Ngày | BE ưu tiên | Flutter và tích hợp | Mốc kiểm tra |
|---|---|---|---|
| D1 | BE-01; chốt DTO/route/chính sách; bắt đầu BE-02/03 | FE-01, chọn nền tảng demo, kiểm tra kết nối mạng/dev URL | Build sau tách tầng, migration cũ vẫn nhận diện, tài liệu contract không còn mâu thuẫn quan trọng |
| D2 | Hoàn thành nền migration/auth/quyền; OpenAPI và seed demo | Login/me thật; model lỗi/ETag; API client dùng chung | Flutter gọi API đã xác thực; chặn được user ngoài kho |
| D3 | Danh mục/lô, transaction nền và nhập nháp | FE-02 danh mục/lô/nhập | Tạo phiếu thật trên SQL; không còn ghi local cho module này |
| D4 | Post nhập, tồn, chất lượng | Nhập → Post → Pending → Released trên Flutter | Đối chiếu tăng tồn, chưa Released thì available=0 |
| D5 | Sự cố, hold và preview FEFO; khởi động nháp xuất | FE-03, UI phân bổ FEFO | Một segment bị hai sự cố; giải quyết một vẫn bị chặn; preview không giữ hàng |
| D6 | Hoàn thiện save/update/cancel/Post xuất; test cạnh tranh | FE-04 gọi API thật; hoàn chỉnh lỗi canPost/412 | Luồng nhập → Released → giữ → xuất chạy được trên Flutter |
| D7 | Phiếu xử lý có duyệt; báo cáo cơ bản | FE-05 xử lý hàng, xem tồn/báo cáo | Nhánh Rejected → xử lý → Post giảm tồn đúng; xuất thường không vượt tồn |
| D8 | Chỉ làm BE-14/15 nếu P0 đạt; hoàn thiện contract/collection | Ghép màn hình, hồ sơ quốc tế nếu còn sức chứa | Đóng phạm vi thêm tính năng; tạo bản tích hợp dự kiến demo |
| D9 | Integration/security/regression test, sửa lỗi | Chạy mọi luồng bằng UI; kiểm tra mất mạng/retry/token hết hạn | Không còn lỗi sai tồn, sai quyền hoặc Post lặp; nếu có thì chưa đạt nghiệm thu |
| D10 | Dự phòng sửa lỗi, seed có kiểm soát, hướng dẫn chạy | Build và chạy máy demo; diễn tập 5–7 phút | Bản bàn giao tái lập được, công khai chức năng còn thiếu |

Các module P0 có thể cần thêm thời gian nếu tích hợp/test phát hiện lỗi. Không tuyên bố hoàn thành chỉ vì đến D10. Bảng là mục tiêu điều phối; mốc nghiệm thu quyết định phạm vi bàn giao.

## 6. Chia việc theo số người

### Phương án 4 người

| Người | Sở hữu chính | Phối hợp |
|---|---|---|
| TV1 — BE nền tảng/nhập | BE-01/02/03/04/05/07; BE-14 sau P0 | Sở hữu migration, auth, API convention; cùng TV2 chốt transaction trước D3 |
| TV2 — BE tồn/nghiệp vụ | BE-06/08/09/10/11/12/13; BE-15 sau P0 | Sở hữu khóa tồn, FEFO và test cạnh tranh; TV1 hỗ trợ test/query sau khi nhập ổn định |
| TV3 — Flutter nền tảng/nhập | FE-01/02; quản trị và hồ sơ tối giản nếu còn thời gian | Sở hữu API client, token, DTO dùng chung, shell; không chờ BE xong mới dựng form |
| TV4 — Flutter kho/xử lý | FE-03/04/05 | Sở hữu UI chất lượng, incident, xuất, xử lý và báo cáo |

TV2 có nhiều nghiệp vụ khó; TV1 chuyển sang hỗ trợ BE-12/13 khi BE-07 ổn, không dành toàn bộ D7–D8 cho hồ sơ P1. Mỗi người vẫn chịu trách nhiệm kiểm thử module mình, không giao tất cả kiểm thử cho Flutter hoặc một thành viên cuối đợt.

### Phương án 3 người

| Người | Sở hữu chính | Giảm tải |
|---|---|---|
| TV1 — BE chính | Nền tảng, migration, auth, danh mục, nhập, khóa tồn, FEFO/xuất | TV3 phụ trách trọn module chất lượng/sự cố/xử lý; hồ sơ P1 mặc định hoãn |
| TV2 — Flutter chính | API client và UI danh mục/nhập/tồn/xuất | Tái sử dụng layout hiện có; UI quản trị dùng tối thiểu; nhận UI chất lượng từ TV3 |
| TV3 — BE/Flutter theo module | Chất lượng, sự cố, xử lý hàng và UI tương ứng; báo cáo đơn giản | Chủ trì smoke test; không nhận thêm hồ sơ quốc tế trước khi P0 đạt |

Với 3 người, kế hoạch 10 ngày căng hơn rõ rệt. Chỉ nhận hồ sơ quốc tế nếu còn thời gian sau vòng P0; nếu nhánh xử lý hàng không kịp kiểm thử thì gia hạn hoặc ghi chưa hoàn thành, không dùng thao tác SQL thủ công làm chức năng demo.

## 7. Chính sách làm mặc định khi triển khai

Các điểm dưới đây kế thừa đề xuất trong API spec và sẽ được ghi thành quy tắc test. Nếu nhóm đổi quyết định, sửa contract trước khi code module liên quan.

| Chủ đề | Mặc định |
|---|---|
| Vai trò | A quản trị, W vận hành, Q vận hành/chất lượng; A không tự bypass quyền Q |
| Đơn vị | Lọ nguyên chưa mở; quantity nguyên; giá theo lọ, VND |
| Ngày hết hạn | Chặn từ ngày hết hạn, ngày nghiệp vụ Asia/Ho_Chi_Minh |
| Nhập/xử lý Post | Chỉ Post ngày hôm nay; chưa ghi lùi/khoá kỳ |
| FEFO | Preview không giữ; lưu nháp giữ; không override FEFO trong MVP |
| Post xuất | Kiểm tra lại theo ngày thực tế nếu giao trễ, không trừ reservation của chính phiếu hai lần |
| Sự cố | Chặn toàn segment; mỗi incident có hold riêng; đóng không tự giải phóng chất lượng |
| Xử lý hàng | Approved chưa giữ hàng; Post kiểm tra lại tồn sau reservations; lý do và phê duyệt bắt buộc |
| Lịch sử | Không sửa/xóa Posted; chưa hỗ trợ đảo chứng từ |
| Token | Access token ngắn hạn, AuthVersion thu hồi mọi phiên khi logout/đổi password; chưa refresh token |
| Quốc tế | Một hồ sơ một kho, không làm biến động tồn bằng status hồ sơ |

## 8. Di chuyển code và nâng cấp DB an toàn

1. Ghi nhận migration đã áp dụng và dữ liệu hiện có; không reset DB để làm refactor nhanh hơn.
2. Chuyển Entities/DbContext/Migrations sang DataAccess, cập nhật namespace và model snapshot nhất quán, giữ nguyên MigrationId. DbContext chỉ có một bản trong solution.
3. Cấu hình EF tooling: target project DataAccess, startup project Api; bảo đảm startup có package design cần thiết. Kiểm tra `migrations list` vẫn thấy hai migration cũ đã áp dụng.
4. Tạo migration bổ sung hợp đồng API: rowversion, AuthVersion, idempotency và các thay đổi scope/unique phù hợp. Rà dữ liệu trước khi siết enum/unique.
5. Với TradeShipment.WarehouseId: thêm nullable → xác định kho từ dữ liệu liên kết hoặc danh sách được rà soát → kiểm tra không còn ambiguous/null → mới chuyển NOT NULL. Không tự gán kho đầu tiên. Nếu hồ sơ cũ liên kết nhiều kho thì báo migration cần xử lý, không mất dữ liệu.
6. Chạy trên DB test riêng cả đường cài mới và nâng cấp từ schema hiện tại, rồi áp vào DB phát triển. Xuất lại schema.sql và cập nhật script verification cùng migration.

Lệnh sau khi đã tách project, chạy từ thư mục `backend`:

```powershell
dotnet build VaxStock.sln
dotnet ef migrations list --project VaxStock.DataAccess --startup-project VaxStock.Api
dotnet ef migrations has-pending-model-changes --project VaxStock.DataAccess --startup-project VaxStock.Api
dotnet ef database update --project VaxStock.DataAccess --startup-project VaxStock.Api
dotnet ef migrations script --project VaxStock.DataAccess --startup-project VaxStock.Api --idempotent --output schema.sql
```

Đây là lệnh mục tiêu sau refactor, chưa áp dụng được nguyên trạng khi project DataAccess chưa được tạo. Tránh để README chỉ dẫn lẫn đường dẫn EF cũ/mới.

## 9. Hợp đồng chung và định nghĩa hoàn thành mỗi module

Trước khi viết controller đầu tiên, chốt một bộ ví dụ chung cho Request/Response, lỗi nghiệp vụ, phân trang, If-Match/ETag, Idempotency-Key, date/time và tiền dạng chuỗi. Công bố bằng OpenAPI sinh từ code và API collection; đặc tả Markdown là tài liệu logic, không thay thế kiểm tra code chạy thực tế.

Một module chỉ được tính xong khi:

- Route/DTO và phân quyền khớp contract; không lộ entity hoặc trường đặc quyền.
- Chạy được đường thành công và lỗi nghiệp vụ quan trọng trên SQL Server thật.
- Transaction rollback đúng khi lỗi giữa chừng; hành động ghi tồn có kiểm thử gửi lặp/cạnh tranh phù hợp.
- Flutter tích hợp API thật cho module thuộc luồng demo, xử lý loading/error và làm mới số dư.
- Migration, API collection, hướng dẫn và example được cập nhật cùng thay đổi.
- Không để đường ghi SharedPreferences song song với API cho cùng dữ liệu nghiệp vụ. SharedPreferences chỉ còn dùng cho cấu hình không nhạy cảm; token dùng lưu trữ phù hợp nền tảng, không log.

Không viết test hình thức chỉ kiểm tra DTO có đúng property. Ưu tiên quy tắc nghiệp vụ và ranh giới transaction; không thêm test UI cho mọi thay đổi hiển thị nhỏ.

## 10. Chiến lược kiểm thử

| Loại | Trọng tâm | Dữ liệu/nền tảng |
|---|---|---|
| Unit | FEFO/tie-break, ngày hết hạn, state machine, quyền, công thức báo cáo | Clock giả lập, data nhỏ, không phụ thuộc giờ máy |
| Integration | EF mapping/constraint, transaction, idempotency, stale version, khóa tồn và quyền API | SQL Server thật với database test riêng, không SQLite/InMemory cho test khóa/rowversion |
| Flutter tích hợp | Login, form nhập, refresh tồn, hiển thị lý do bị chặn, reallocate/cancel/Post, 401/412 | API thật, tài khoản A/W/Q và hai kho |
| Nghiệm thu | Toàn luồng thường và sự cố/xử lý | Seed giả lập cố định theo clock hoặc ngày demo; không dùng thông tin người bệnh |

Bộ test tối thiểu:

1. Nhập 100 lọ Pending: onHand=100, available=0; Released thì available=100.
2. Giữ 30 lọ: reserved=30, available=70; hủy trả về 100; Post thành onHand=70, reserved=0.
3. Hai request cùng giữ 80/100: không thể cùng thành công.
4. Retry Post cùng khóa: không sinh movement thứ hai; khác payload cùng khóa trả 409.
5. Hai hold trên một segment, gỡ một vẫn bị chặn; Quality Released bị từ chối khi còn hold.
6. Lô hết hạn giữa nháp và Post bị chặn; kiểm thử đúng ranh giới ngày.
7. Update phiếu lỗi không mất reservation cũ; dữ liệu lỗi giữa Post không để trạng thái nửa chừng.
8. Xuất xử lý có duyệt giảm đúng lượng; không vượt tồn sau lượng giữ và không có phê duyệt thì không Post.
9. Báo cáo opening + received − issued − disposed = closing.
10. W/Q kho A không xem/sửa phiếu/trace/tổng/audit kho B; gỡ assignment có hiệu lực ngay.
11. If-Match cũ bị từ chối; sửa child phải làm version aggregate thay đổi.
12. Đổi mật khẩu/role/logout vô hiệu token cũ; response/log không có password/hash/token.

DB test dùng connection string riêng và xác minh tên database trước khi dọn fixture; không drop/reset VaxStockDev để chạy test. Script SQL rollback hiện có tiếp tục phục vụ kiểm tra schema, không thay integration test API mới.

## 11. Mốc quyết định giảm phạm vi

| Thời điểm | Nếu chưa đạt | Hành động |
|---|---|---|
| Cuối D2 | Login, quyền hoặc migration chưa ổn | Ngừng thêm route danh mục nâng cao; cả nhóm gỡ nền tảng trước |
| Cuối D4 | Chưa nhập → Post → Released qua API | Hoãn hồ sơ quốc tế/dashboard nâng cao; người BE thứ hai hỗ trợ luồng nhập |
| Cuối D6 | Chưa giữ/sửa/cancel/Post xuất đúng tồn | Tập trung FEFO/transaction/concurrency, không thêm module P1 |
| Cuối D8 | P0 còn lỗi sai tồn/sai quyền | Bỏ tính năng P1 khỏi bản bàn giao, D9–D10 sửa và test; gia hạn nếu lỗi cốt lõi còn tồn tại |

Không cắt: quyền kho, băm mật khẩu, validation, kiểm tra hạn/chất lượng/hold, atomic Post, chống vượt tồn và lưu lịch sử. Có thể cắt: filter/sort nâng cao, giao diện audit, dashboard trang trí, export file và hồ sơ quốc tế.

## 12. Gói bàn giao

- Solution 3 tầng build được; Flutter chạy trên nền tảng demo đã chọn.
- Migration, schema.sql, script kiểm tra và seed có kiểm soát; không có mật khẩu/JWT signing key thật trong Git.
- OpenAPI và collection có ví dụ thành công/lỗi, tài khoản demo lấy qua hướng dẫn/seed phát triển.
- README chạy BE/Flutter, cấu hình SQL, base URL, CORS theo origin cần dùng và cách chạy test.
- Danh sách test đã chạy/kết quả, chức năng hoàn thành và phần hoãn rõ ràng.
- Kịch bản demo: nhập → giải phóng → FEFO/giữ → sự cố chặn → phân bổ lại hoặc xử lý → xuất → đối chiếu tồn.

## 13. Đợt code đầu tiên đề xuất

Chỉ thực hiện **BE-01 đến nền BE-04** trong đợt đầu: tách project, bảo toàn migration, thêm nền hợp đồng cần thiết, thống nhất lỗi/transaction/current user, rồi login/me và quyền kho. Bàn giao một API được xác thực chạy thật trước khi làm nhập/xuất.

Sau đó triển khai từng lát cắt chạy được theo backlog, không tạo sẵn hàng loạt controller trả dữ liệu giả. Kế hoạch này chưa tự khởi động code hoặc tạo các migration mới.
