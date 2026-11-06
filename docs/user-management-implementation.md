# Mục 5.2 — Quản trị người dùng và quyền kho

Đã triển khai BE theo API → Business → DataAccess. Chỉ tài khoản Admin còn phiên hợp lệ được gọi các API trong tài liệu này. Chưa có màn hình quản trị Flutter; dùng HTTP client/collection để thao tác. Flutter auth vẫn tương thích response đã bổ sung.

## Các endpoint

Base: `/api/v1`. Tất cả request có `Authorization: Bearer <accessToken>`.

| Method / route | Request | Response |
|---|---|---|
| GET `/users` | page=1, pageSize=20 (1–100), search?, role?, sort=username hoặc id | Page<UserResponse> |
| GET `/users/{id}` | ID | UserResponse + ETag |
| POST `/users` | username, password, fullName, role | 201 UserResponse + Location + ETag |
| PUT `/users/{id}` | If-Match; fullName, role | UserResponse + ETag mới |
| POST `/users/{id}/reset-password` | If-Match; newPassword, reason | id, reauthenticationRequired=true, version; ETag mới |
| GET `/warehouse-assignments` | page/pageSize, userId?, warehouseId? | Page<AssignmentResponse> |
| GET `/warehouse-assignments/{id}` | ID | AssignmentResponse + ETag; endpoint bổ sung để đọc lại version/Location |
| POST `/warehouse-assignments` | userId, warehouseId | 201 AssignmentResponse + Location + ETag |
| DELETE `/warehouse-assignments/{id}` | If-Match | 204 |

UserResponse dùng chung với auth/me và login.user:

```json
{
  "id": 7,
  "username": "staff.hcm",
  "fullName": "Nhân viên HCM",
  "role": "WarehouseStaff",
  "warehouses": [{ "id": 1, "code": "HCM", "name": "Kho HCM" }],
  "warehouseIds": [1],
  "version": "AAAAAAAAAAE="
}
```

`warehouses` giữ tương thích Flutter, `warehouseIds` và `version` thống nhất với đặc tả. WarehouseIds là **quyền hiệu lực**; Admin thấy tất cả kho dù không có assignment tương ứng. Tạo user không tự tạo assignment. PasswordHash và AuthVersion không xuất hiện trong response.

AssignmentResponse: id, userId, username, warehouseId, warehouseName, version. Page: items, page, pageSize, totalItems, totalPages. Tìm kiếm username/fullName không phân biệt theo cách collation SQL Server đã cấu hình; username khi tạo được trim/lowercase và không chứa khoảng trắng. Username không sửa qua PUT.

## Cách cập nhật bằng ETag

1. GET user hoặc assignment, lấy header ETag.
2. Gửi nguyên header đó trong If-Match của request PUT/reset/DELETE.
3. Nếu nhận 412, tải lại dữ liệu và để người dùng quyết định; không ghi đè tự động.

Ví dụ tạo tài khoản:

```http
POST /api/v1/users
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "username": "staff.new",
  "password": "<password-do-nguoi-quan-tri-dat>",
  "fullName": "Nhân viên mới",
  "role": "WarehouseStaff"
}
```

Ví dụ cập nhật:

```http
PUT /api/v1/users/7
Authorization: Bearer <admin-token>
If-Match: "AAAAAAAAAAE="
Content-Type: application/json

{"fullName":"Tên mới","role":"QualityManager"}
```

ETag minh họa không dùng được trên DB thực; lấy version thực tế từ GET. Strong ETag có dấu ngoặc kép, đúng rowversion 8 bytes encode Base64. Không nhận wildcard `*`, weak ETag hoặc danh sách nhiều ETag.

## Logic bảo vệ

- Mọi role khác Admin bị 403, thiếu/hết hạn/thu hồi token bị 401. Revalidate actor sau khi lấy khóa SQL cho thao tác ghi, để request không dùng quyền Admin đã bị thay đổi trong lúc chờ.
- Password tạo/reset 12–128 ký tự, không chỉ khoảng trắng; băm bằng cùng password service của auth. Không trim password, không ghi password/hash vào audit.
- Role chỉ Admin/WarehouseStaff/QualityManager. Tạo user trùng username trả 409; thiếu user/kho khi cấp quyền trả 400; user/assignment theo ID không tồn tại trả 404.
- Thiếu If-Match trả 428; sai định dạng trả 400; version cũ trả 412. Sửa fullname/role và cấp/gỡ assignment đều làm đổi RowVersion của user aggregate.
- Đổi role tăng AuthVersion, token cũ mất hiệu lực ở request tiếp theo. Chỉ đổi fullname không thu hồi token. Admin reset mật khẩu tăng AuthVersion và thu hồi mọi phiên của user đó; reset chính mình cũng yêu cầu login lại.
- Cấp/gỡ assignment không tăng AuthVersion: token hiện có vẫn xác thực nhưng quyền kho được đọc lại từ DB ở request sau, có hiệu lực ngay.
- Không cho hạ quyền Admin cuối cùng. Các admin mutations dùng SQL application lock có owner Transaction để bảo vệ cả trường hợp nhiều instance và hai Admin tự hạ quyền đồng thời. Role-changing code mới sau này phải dùng cùng cơ chế này.
- Audit cùng transaction với mutation: CreateUser, UpdateUser, ResetPassword, GrantWarehouse, RevokeWarehouse. Lỗi concurrency hoặc audit làm rollback toàn bộ, không để thay đổi quyền thành công nhưng thiếu lịch sử.
- Không có DELETE user hoặc PUT assignment. Gỡ quyền không xóa phiếu kho/lịch sử. Không có disable user vì chưa có IsActive.

## Migration

`UserManagementConcurrency` thêm RowVersion cho WarehouseAssignment và mở rộng AuditLog.Details sang nvarchar(max). Lý do: một reason 2000 ký tự có thể dài hơn 2000 khi encode JSON; giữ nguyên toàn bộ lý do thay vì cắt hoặc làm request reset thất bại. Input lý do vẫn giới hạn 2000; người dùng không có API ghi audit tùy ý.

Migration Up không xóa/reset bảng hoặc dữ liệu. Down thu hẹp Details về 2000 nên có nguy cơ cắt dữ liệu dài; không chạy rollback migration này trên dữ liệu thật nếu chưa rà soát/backup.

```powershell
# Tại backend/
dotnet build VaxStock.sln -m:1
dotnet ef database update --project VaxStock.DataAccess --startup-project VaxStock.Api
dotnet run --project VaxStock.Api --launch-profile http
```

## Kiểm thử

```powershell
./backend/scripts/test-auth.ps1 -Suite admin
./backend/scripts/test-auth.ps1 -Suite auth
dotnet test backend/VaxStock.Tests -m:1
```

Suite admin dùng DB GUID riêng, gồm kiểm tra vai trò, validation/filter/page, strong ETag, stale version, create/read/update user, reset mật khẩu và token cũ, cấp/gỡ quyền với cùng token, duplicate grant đồng thời, hai Admin hạ quyền đồng thời và audit đầy đủ. Suite auth giữ regression login/JWT/logout. Script dọn đúng database test sau khi hoàn thành, không reset VaxStockDev.

Đã xác minh 65 HTTP checks suite admin, kiểm tra audit bằng SQL và 25 HTTP checks regression auth. Flutter auth vẫn chạy với response mới, analyzer không có lỗi. SDK .NET 10.0.401 cũ không còn được dotnet nhận diện trong phiên này; global.json đã đổi sang baseline 10.0.100 + latestFeature để dùng SDK 10.0.102 hiện có, không đổi target net10.0.

## Phạm vi còn lại

Đã có đủ tám endpoint nêu trong mục 5.2 và thêm GET assignment detail. Chưa có UI quản trị Flutter. Nền Idempotency-Key lưu trữ bền vững ở mục 2.3 của đặc tả vẫn chưa triển khai cho toàn hệ thống; POST tạo user/assignment được bảo vệ bởi unique constraint, nhưng reset-password không được client tự retry mù khi mất response. ETag kiểm soát ghi đè, không thay thế idempotency replay. Đây là giới hạn chung được ghi rõ, không coi là đã hoàn thành toàn bộ đặc tả API.
