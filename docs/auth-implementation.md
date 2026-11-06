# Auth BE + Flutter — đã triển khai

## Phạm vi

- BE tách thành API → Business → DataAccess; test nằm trong project riêng.
- Login, me, đổi mật khẩu, logout mọi phiên; đọc kho được cấp và kiểm tra quyền kho ở server.
- Flutter entrypoint `lib/main.dart` chạy luồng auth qua API, không dùng tài khoản/mật khẩu từ JSON local.
- Sau login vào shell Tài khoản/Kho, có role, refresh, đổi password và logout. [Danh mục Kho đã nối API](flutter-shell-warehouse-integration.md); các màn hình nghiệp vụ local khác chưa được đưa vào phiên server.
- Đã có API quản trị user/assignment ở [mục 5.2](user-management-implementation.md); chưa có UI quản trị, refresh token, đăng ký, quên mật khẩu hoặc SSO. `/warehouses` mới là truy vấn phục vụ auth, chưa CRUD danh mục đầy đủ.

## Cấu trúc

```text
VaxStock.Api/Contracts, Controllers, Security, Infrastructure
VaxStock.Business/Interfaces, Models, Services, Exceptions
VaxStock.DataAccess/Entities, Data, Interfaces, Repositories, Migrations
VaxStock.Tests/AuthServiceTests.cs
lib/core/network, core/storage
lib/features/auth/data, models, state, server_auth_page.dart
lib/app/auth_app.dart
```

API chỉ map request/response; Business dùng LoginCommand/Result, không biết HTTP hoặc DTO API. DataAccess đọc/ghi EF; revoke/password dùng compare-and-swap theo AuthVersion, ghi audit cùng transaction. Hai migration cũ giữ ID và chuyển sang DataAccess; migration mới `AuthSessionVersion` chỉ thêm AuthVersion và RowVersion của AppUser. Không reset DB.

## API

| Method / route | Đầu vào | Kết quả |
|---|---|---|
| POST `/api/v1/auth/login` | `{username,password}` | `{accessToken,tokenType:"Bearer",expiresIn:900,user:{id,username,fullName,role,warehouses:[{id,code,name}]}}` |
| GET `/api/v1/auth/me` | Bearer | User hiện tại cùng warehouses từ DB |
| POST `/api/v1/auth/change-password` | Bearer + `{currentPassword,newPassword}` | `{reauthenticationRequired:true}`, thu hồi mọi token cũ |
| POST `/api/v1/auth/logout` | Bearer, body có thể `{}` | `{loggedOut:true}`, thu hồi mọi token cũ |
| GET `/api/v1/warehouses` | Bearer | Danh sách kho được phép, có search/sort/page/pageSize; CRUD danh mục hiện theo mục 6 |
| GET `/api/v1/warehouses/{id}` | Bearer | WarehouseResponse + ETag hoặc 404 ngoài phạm vi |
| GET `/health` | Không cần token | Liveness, không kiểm tra DB |

Username được trim/lowercase khi tìm; password không trim. Password mới 12–128 ký tự, không chỉ khoảng trắng và khác password hiện tại. Hasher dùng ASP.NET Core Identity PasswordHasher. Token HS256 có sub, role, authVersion, jti, issuer/audience/nbf/exp; kiểm tra chữ ký, thuật toán, issuer, audience, thời hạn và session/role trong DB mỗi request.

401 thiếu/hết hạn/bị thu hồi token; 403 thiếu quyền kho; 400 sai validation/password hiện tại; 429 vượt 10 login/phút/IP (Retry-After); 500 lỗi hệ thống. Login user không tồn tại và sai password có cùng lỗi; unknown user vẫn qua dummy password verification. Validation từ chối JSON fields không khai báo. Error body có status/title/code/traceId/fieldErrors, không trả exception hoặc thông tin SQL.

Chưa có ETag/Idempotency-Key chung: auth không phụ thuộc nền nghiệp vụ Post. Nếu đổi password/logout commit nhưng mất response, đăng nhập lại; không retry POST mù. AuthVersion thu hồi phiên và quyền kho được truy vấn DB; không dựa riêng vào role/kho client gửi.

## Cấu hình và chạy BE

Không sửa connection string người dùng đã đặt trong appsettings.json. Development có thể dùng `backend/VaxStock.Api/appsettings.Local.json` (được gitignore), lấy mẫu từ appsettings.Example.json. File local trong phiên triển khai đã được tạo với signing key và seed password ngẫu nhiên; không in secret vào log/chat. Đọc `Seed:Password` trong file local nếu cần đăng nhập demo.

- `Jwt:SigningKey`: tối thiểu 32 byte, ngẫu nhiên; thiếu cấu hình thì server không khởi động.
- `ConnectionStrings:Warehouse`: SQL Server phát triển, Windows auth hoặc cấu hình riêng qua secret/env.
- `Seed:Password`: mật khẩu phát triển 12–128 ký tự, chỉ dùng khi chạy seed chủ động.
- `Cors:Origins`: origin Flutter Web cụ thể, mặc định ví dụ localhost:5173; không wildcard credential.
- Biến môi trường như `Jwt__SigningKey`, `ConnectionStrings__Warehouse` ghi đè file local.

Tại thư mục `backend`:

```powershell
dotnet restore VaxStock.sln
dotnet build VaxStock.sln -m:1
dotnet ef database update --project VaxStock.DataAccess --startup-project VaxStock.Api
dotnet run --project VaxStock.Api --launch-profile http -- --seed-auth true
dotnet run --project VaxStock.Api --launch-profile http
```

Seed chỉ Development, chạy theo lệnh riêng, không tự seed/migrate khi server khởi động. Tạo admin/Admin, staff.hcm/WarehouseStaff (AUTH-HCM), quality.hn/QualityManager (AUTH-HN); admin xem mọi kho. Seed không đổi password/role của tài khoản đã tồn tại. Normal startup không ghi secret mẫu vào DB hoặc tạo tài khoản tự động.

HTTP profile: localhost:5109, HTTPS profile: localhost:7215. Local TrustServerCertificate chỉ cho dev; production dùng TLS/chứng chỉ và signing key riêng. Khi không Development, API có HTTPS redirection; hệ thống triển khai reverse proxy phải cấu hình TLS/forwarding đúng môi trường.

## Chạy Flutter

Tại root project:

```powershell
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5109/api/v1/
```

Android emulator dùng mặc định `http://10.0.2.2:5109/api/v1/`; Windows/Web mặc định localhost:5109. Máy Android thật phải dùng địa chỉ LAN truy cập được và BE bind/firewall phù hợp. Android debug cho phép cleartext phục vụ localhost dev; release bắt buộc API_BASE_URL HTTPS. Không đưa secret BE vào dart-define.

Web demo (đã cấu hình CORS origin tương ứng):

```powershell
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:5109/api/v1/
```

Native token dùng flutter_secure_storage; Web chỉ giữ trong memory, reload phải login lại. Không lưu token/password vào SharedPreferences. Native mở lại app đọc token rồi gọi me; 401 xóa phiên, 5xx/mất mạng hiện thử lại và không xóa token. Access token hết hạn thì cần login, chưa tự refresh. Parsing exp ở client chỉ để điều hướng UI, không phải kiểm tra tính hợp lệ JWT.

API client gắn Bearer, timeout 15 giây, không tự retry request ghi. 401 của token cũ không làm mất token mới; 403 không logout. Storage writes/clears tuần tự để tránh clear trễ ghi đè phiên mới. Logout thất bại kết nối vẫn thoát cục bộ và hiển thị chưa xác nhận thu hồi phiên khác. Storage lỗi có thông báo, không fallback lưu token dạng rõ.

## Kiểm thử

```powershell
dotnet test backend/VaxStock.Tests -m:1
./backend/scripts/test-auth.ps1
flutter test
flutter analyze
```

Unit BE: lỗi login thống nhất, thu hồi AuthVersion, password policy, password cũ, quyền kho thay đổi và stale change. Flutter: khôi phục 401/5xx, 403, logout lỗi mạng, đổi password, token cũ và widget login.

Smoke test tạo **database SQL Server riêng có GUID**, áp toàn bộ migration và seed, chạy API local ẩn, kiểm tra HTTP auth/JWT/quyền/rate limit; cuối cùng dừng đúng process và xóa đúng database test đã tạo. Không reset/drop VaxStockDev. Log nằm backend/test-results (gitignore), không in token/password. Cần quyền SQL tạo/xóa DB test; build trước khi chạy script vì script dùng no-build.

Các test kho local cũ vẫn được giữ cho phần chưa migrate; chúng không chứng minh nghiệp vụ kho đã được BE bảo vệ. Chưa có kiểm thử thiết bị native thực tế hoặc triển khai production trong phạm vi smoke HTTP.

Kết quả xác minh trong phiên triển khai: 8 test BE và 25 kiểm tra HTTP/SQL auth đã đạt; toàn bộ 30 Flutter tests, analyzer không có lỗi và build Web đã đạt. Build Windows đã được thử nhưng thiếu Visual Studio C++ toolchain; cần cài toolchain Flutter Windows trước khi chạy bản native. Windows desktop đã được bật trong Flutter config. Chưa xác nhận hoạt động secure storage trên thiết bị native bằng chạy app thực tế.

## Cập nhật response mục 5.1/5.2

User trong login/me hiện có thêm `warehouseIds` và `version`, giữ `warehouses` chi tiết cho Flutter. GET me trả ETag tài khoản. Admin PUT/reset user và DELETE assignment yêu cầu If-Match; chi tiết endpoint, migration và kiểm thử tại [quản trị người dùng](user-management-implementation.md). Seed/password/token vẫn theo hướng dẫn trên.

## Bước tiếp theo

Triển khai danh mục rồi nhập kho. Service nghiệp vụ mới phải gọi kiểm tra quyền kho, không tin quyền UI; không đưa shell local trở lại phiên server cho đến khi chuyển dữ liệu tương ứng sang API.
