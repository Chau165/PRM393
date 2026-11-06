# VaxStock backend — 3 tầng và auth

Backend nằm cùng repository với Flutter nhưng có solution riêng: `VaxStock.sln`.

Auth BE + Flutter và API [quản trị user/quyền kho](../docs/user-management-implementation.md) đã triển khai. Xem [hướng dẫn auth](../docs/auth-implementation.md) để cấu hình signing key, seed password, chạy Flutter và kiểm thử; file local có secret được gitignore.

API mục 6 đã có CRUD [kho/đối tác/vaccine](../docs/master-data-implementation.md), ETag và audit. Mục 7 đã có [lô vaccine và truy xuất](../docs/batch-implementation.md). Sau khi có thay đổi code, cần dừng/restart API đang chạy để tải DLL mới. Chưa có API nhập/xuất.

Flutter đã nối [shell theo phiên và danh mục Kho](../docs/flutter-shell-warehouse-integration.md); mở menu Kho sau login. [Đối tác/Vaccine](../docs/flutter-partner-vaccine-integration.md) đã có trong shell server; [Lô/truy xuất B5/B6](../docs/flutter-batch-trace-integration.md) đã nối Flutter.

## Môi trường đã kiểm tra

- Target **net10.0**; `global.json` dùng baseline SDK **10.0.100**, rollForward latestFeature để chọn SDK .NET 10 đã cài. Máy hiện nhận diện 10.0.102; 10.0.401 từng dùng lúc khởi tạo không còn hoạt động.
- SQL Server local: **2022 Developer Edition, 16.0.1000.6**, default instance `localhost`, dịch vụ `MSSQLSERVER`.
- EF Core SQL Server/Design: **10.0.12**.
- `System.Security.Cryptography.Pkcs` được tham chiếu trực tiếp bản **10.0.13** để xử lý cảnh báo NuGet từ dependency gián tiếp.
- Database phát triển: **VaxStockDev**, đăng nhập bằng Windows Authentication; không có mật khẩu trong cấu hình.

Thông tin trên là trạng thái máy khi khởi tạo, không phải yêu cầu mọi thành viên phải có cùng phiên bản SQL Server.

## Chạy từ PowerShell

Mở terminal tại `D:\FALL26\PRM393\Project\backend`:

```powershell
dotnet restore VaxStock.sln
dotnet build VaxStock.sln --no-restore -m:1
dotnet ef database update --project VaxStock.DataAccess --startup-project VaxStock.Api
dotnet run --project VaxStock.Api --launch-profile http -- --seed-auth true
dotnet run --project VaxStock.Api --launch-profile http
```

Nếu chưa có EF CLI, cài công cụ tương ứng:

```powershell
dotnet tool install --global dotnet-ef --version 10.0.12
```

Nếu máy đã có bản cũ, dùng `dotnet tool update --global dotnet-ef --version 10.0.12`. Máy khởi tạo hiện có CLI 10.0.10; CLI này đã tạo và áp dụng migration thành công nhưng có thông báo lệch phiên bản với EF runtime.

Mở `http://localhost:5109/health` hoặc gửi request trong `VaxStock.Api.http`. Health chỉ kiểm tra tiến trình API. Đã có auth, quản trị user/quyền kho, CRUD danh mục và lô/trace; chưa có API phiếu/FEFO/Post hoặc Swagger UI.

`TrustServerCertificate=True` chỉ dành cho SQL Server phát triển local; khi triển khai cần chứng chỉ được tin cậy và cấu hình kết nối phù hợp. Có thể ghi đè connection string bằng biến môi trường `ConnectionStrings__Warehouse`; không commit tài khoản/mật khẩu thật.

## Cấu trúc và schema

```text
VaxStock.Api/
  Contracts/, Controllers/          # HTTP request/response
  Security/, Infrastructure/        # JWT, hasher, errors, seed
VaxStock.Business/
  Models/, Interfaces/, Services/   # Auth use cases
VaxStock.DataAccess/
  Entities/, Data/, Repositories/   # EF, persistence
  Migrations/                       # Giữ migration IDs cũ + AuthSessionVersion
VaxStock.Tests/                     # Test auth business
schema.sql                          # SQL idempotent xuất từ migration
verify-schema.sql                   # Kiểm tra schema thực tế, không sửa dữ liệu
```

21 bảng nghiệp vụ, tên hiện tại theo DbSet và có hậu tố `Records`:

| Nhóm | Entity |
|---|---|
| Tài khoản/kho | AppUser, Warehouse, WarehouseAssignment |
| Danh mục/lô | Organization, Vaccine, VaccineBatch |
| Nhập | Receipt, ReceiptDetail |
| Tồn/chất lượng | StockSegment, StockMovement, StockReservation, QualityDecision |
| Xuất | Issue, IssueDetail |
| Hồ sơ và truy vết | TradeShipment, ShipmentDocumentLink, AuditLog |
| Sự cố và xử lý hàng | Incident, IncidentStockSegment, StockDisposition, StockDispositionDetail |

Chi tiết schema mới và quy tắc flow: [Database nhập–sự cố–xuất](../docs/vaccine-database-flow.md). Migration `IncidentAndDispositionFlow` bổ sung bốn bảng này, `QualityDecision.IncidentId` và nguồn movement từ xử lý hàng.

Các lựa chọn thiết kế:

- Số lượng là số nguyên lọ; liều/lọ và lọ/hộp là hệ số quy đổi. Hạn dùng dùng SQL `date`; thời điểm ghi nhận dùng `datetimeoffset`.
- Mỗi dòng nhập có một StockSegment tại một kho, trạng thái `Pending`, `Released`, `Quarantined` hoặc `Rejected`. MVP chưa chia một dòng nhập thành nhiều phần chất lượng/vị trí.
- StockMovement lưu tăng/giảm có dấu; mỗi dòng nhập/xuất/xử lý hàng có tối đa một movement tương ứng để hỗ trợ chống Post lặp. Tồn tính từ movement, không có bảng số dư độc lập.
- Mỗi dòng xuất gắn một segment và có tối đa một reservation. Muốn lấy nhiều lô thì tạo nhiều dòng.
- Các khóa ngoại không cascade delete; không xóa dây chuyền chứng từ hoặc lịch sử.
- Có unique index cho mã, số phiếu, vaccine–số lô và user–kho; check constraint cho số lượng, giá, ngày sản xuất/hạn dùng, trạng thái và chiều movement.
- RowVersion trên StockSegment là nền tảng kiểm soát cạnh tranh, chưa tự bảo đảm chống vượt tồn. Service Post sau này phải dùng giao dịch/khóa phù hợp và kiểm tra lại tồn.
- ShipmentDocumentLink liên kết đúng một phiếu nhập hoặc một phiếu xuất. Trạng thái hồ sơ không làm biến động tồn.

Schema không thay thế kiểm tra nghiệp vụ: kiểm tra cùng kho giữa segment và phiếu, nhất quán dòng movement, quyền, hạn dùng và số lượng khả dụng sẽ phải được thực thi trong service/giao dịch ở bước tiếp theo.

## Làm việc với migration

Sau khi sửa model/DbContext:

```powershell
dotnet ef migrations add TenThayDoi --project VaxStock.DataAccess --startup-project VaxStock.Api --output-dir Migrations
dotnet ef database update --project VaxStock.DataAccess --startup-project VaxStock.Api
dotnet ef migrations script --project VaxStock.DataAccess --startup-project VaxStock.Api --idempotent --output schema.sql
dotnet ef migrations has-pending-model-changes --project VaxStock.DataAccess --startup-project VaxStock.Api
```

`schema.sql` là bản xuất để xem xét/chạy trong database đích đã chọn, không tự tạo database. Ưu tiên `database update` khi phát triển; không chỉnh SQL riêng rồi bỏ quên migration.

Kiểm tra cấu trúc đã tạo:

```powershell
sqlcmd -S localhost -E -C -d VaxStockDev -b -i verify-schema.sql
sqlcmd -S localhost -E -C -d VaxStockDev -b -i test-database-flow.sql
```

AuthSessionVersion bổ sung AuthVersion và RowVersion của AppUser; các migration sau bổ sung version cho assignment/danh mục/lô. Seed auth là lệnh chủ động, chưa seed vaccine cho dữ liệu vận hành. Bước tiếp theo là API nhập kho; không trả entity hoặc PasswordHash ra API.

`test-database-flow.sql` tạo fixture trong transaction rồi rollback; kiểm tra quan hệ nhập/sự cố/tiêu hủy, số dư movement và một số dữ liệu không hợp lệ. Không thay thế kiểm thử service/giao dịch sau khi chốt kiến trúc.

Provider và cách cấu hình EF Core tham khảo [Microsoft Learn](https://learn.microsoft.com/ef/core/providers/sql-server/). Bản vá dependency theo [security advisory](https://github.com/advisories/GHSA-846f-f764-76mx).
