# Đề xuất API VaxStock — kiến trúc 3 tầng

Trạng thái: **đặc tả đề xuất, chưa triển khai endpoint nghiệp vụ**. Hiện code chỉ có `GET /health`. Tài liệu bám schema 21 bảng tại [database flow](vaccine-database-flow.md); những phần cần migration thêm được ghi ở cuối.

Mục tiêu: dùng làm hợp đồng để BE và Flutter chia việc, bao phủ đăng nhập, danh mục, nhập, chất lượng, sự cố, giữ hàng, xuất, xuất trả/tiêu hủy, hồ sơ quốc tế, báo cáo và nhật ký.

## 1. Ranh giới 3 tầng

```text
Flutter → Controller + API Request/Response
        → Business Command/Query/Result + Service
        → Repository/DbContext + Entity → SQL Server
```

- API nhận request, kiểm tra định dạng, lấy danh tính đã xác thực, map sang Business model; chuyển kết quả/lỗi thành HTTP response. Không truyền HttpContext hoặc API DTO xuống service.
- Business kiểm tra quyền kho, trạng thái, hạn dùng, FEFO, số lượng và điều phối một giao dịch cho toàn bộ nghiệp vụ.
- Data Access thực hiện truy vấn/khóa/lưu theo giao dịch của nghiệp vụ; không tự commit từng repository trong một lần Post.
- API không nhận/trả Entity. Các model trong tài liệu là API contract; Business dùng command/result riêng, không phụ thuộc project API.
- Không tạo CRUD công khai cho StockMovement, StockReservation, AuditLog hoặc sửa trực tiếp QualityStatus. Chúng chỉ thay đổi qua hành động nghiệp vụ được kiểm soát.

## 2. Quy ước chung

### 2.1. Địa chỉ, dữ liệu và phân trang

- Base URL: `/api/v1`. Các route bên dưới đều tương đối với base này, trừ `/health`.
- JSON camelCase, UTF-8. ID: số nguyên dương. Quantity: số nguyên lọ, không nhận số thập phân.
- Ngày nghiệp vụ: `YYYY-MM-DD`. Thời điểm: ISO 8601 có offset; response thời điểm chuẩn hóa UTC, Flutter hiển thị Asia/Ho_Chi_Minh.
- Filter fromDate/toDate của phiếu và báo cáo dùng ngày nghiệp vụ; của incident dùng ReportedAt, của audit dùng OccurredAt, quy đổi ranh giới ngày theo múi giờ nghiệp vụ. Movement endpoint dùng EffectiveDate; postedAt chỉ dùng sort khi được khai báo. Khoảng ngày inclusive được chuyển thành [đầu ngày bắt đầu, đầu ngày sau ngày kết thúc) cho trường thời điểm.
- Đề xuất MVP dùng múi giờ nghiệp vụ Asia/Ho_Chi_Minh cho mọi kho. Chỉ đủ xuất nếu `expiresAt > eligibilityDate`; chặn từ ngày hết hạn. Đây là chính sách thiết kế cần nhóm chốt, không phải quy định áp dụng chung cho mọi sản phẩm.
- Giá tiền request/response là chuỗi decimal, ví dụ `"125000.00"`, tối đa hai chữ số thập phân; Business parse thành decimal, không dùng float. MVP một loại tiền VND; không cộng giá trị đa tiền tệ.
- Mọi chuỗi trim; không chấp nhận chuỗi chỉ khoảng trắng. Mã/tên/số phiếu tối đa 200 ký tự; lý do/mô tả tối đa 2000 theo DB. Username chuẩn hóa thống nhất khi tạo/tìm; unique theo collation DB, kiểm tra cả tại service.
- Trường request không được định nghĩa nên bị từ chối để phát hiện client gửi nhầm trường đặc quyền. PUT là thay thế toàn bộ các trường cho phép sửa, không phải PATCH; nullable muốn xóa phải gửi null.
- Trường response dẫn xuất như tên vaccine, số dư, blockReasons không nhất thiết có cột DB tương ứng.
- Danh sách dùng `page=1&pageSize=20`, pageSize 1–100; `search` tối đa 200 ký tự. Chỉ cho sort theo whitelist ghi tại từng module, luôn thêm ID làm tie-break. Sai filter/sort trả 400, không bỏ qua âm thầm.
- Không truyền kho nghĩa là tổng hợp **các kho người gọi được phép**, không phải tất cả kho hệ thống. Filter kho không có quyền bị từ chối; không trả dữ liệu kho khác qua joins, counts hoặc trace.

Response danh sách thống nhất `Page<T>`:

```json
{
  "items": [],
  "page": 1,
  "pageSize": 20,
  "totalItems": 0,
  "totalPages": 0
}
```

### 2.2. Mã HTTP, lỗi và dữ liệu bảo vệ

| HTTP | Trường hợp |
|---|---|
| 200 | Đọc, cập nhật, hành động nghiệp vụ thành công |
| 201 | Tạo resource mới, kèm Location trỏ endpoint chi tiết |
| 204 | Xóa thành công, không có response body |
| 400 | Sai định dạng, trường bắt buộc, filter, enum hoặc validation đầu vào |
| 401 | Thiếu/hết hạn token, token đã thu hồi hoặc tài khoản không hợp lệ |
| 403 | Có danh tính nhưng thiếu vai trò hoặc cố lọc kho không được phép |
| 404 | Resource không tồn tại hoặc resource theo ID nằm ngoài kho được phép, để tránh lộ dữ liệu |
| 409 | Sai trạng thái, trùng mã, thiếu tồn, hàng bị chặn, khóa idempotency dùng khác payload |
| 412 | If-Match không còn khớp phiên bản hiện tại |
| 428 | Thiếu If-Match ở endpoint bắt buộc |
| 429 | Quá giới hạn request, đặc biệt login; kèm Retry-After |
| 500 | Lỗi hệ thống; không lộ SQL, stack trace, mật khẩu hoặc token |
| 503 | Readiness không đạt hoặc dependency tạm không sẵn sàng |

Lỗi dùng một định dạng thống nhất:

```json
{
  "type": "about:blank",
  "title": "Không đủ hàng khả dụng",
  "status": 409,
  "code": "INSUFFICIENT_AVAILABLE_STOCK",
  "detail": "Vaccine được yêu cầu chưa đủ lượng đủ điều kiện xuất.",
  "traceId": "request-trace-id",
  "fieldErrors": {},
  "conflicts": [
    { "vaccineId": 12, "requested": 50, "available": 30, "shortage": 20 }
  ]
}
```

`fieldErrors` là map field → array thông báo. `conflicts` chỉ có khi cần; dữ liệu lỗi cũng phải lọc theo quyền. Mã nghiệp vụ chính: `DUPLICATE_CODE`, `RESOURCE_IN_USE`, `INVALID_STATE`, `BATCH_METADATA_CONFLICT`, `BATCH_EXPIRED`, `QUALITY_NOT_RELEASED`, `ACTIVE_INCIDENT_HOLD`, `INSUFFICIENT_AVAILABLE_STOCK`, `INSUFFICIENT_PHYSICAL_STOCK`, `CONCURRENCY_CONFLICT`, `IDEMPOTENCY_CONFLICT`, `INVENTORY_INTEGRITY_ERROR`.

Không nhận các giá trị do server quyết định: createdById, decidedById, approvedById, postedAt, reportedAt, closedById, tổng tiền, onHand, reserved, available. Request truyền status chỉ tại hành động rõ ràng như quyết định chất lượng hoặc tiến độ hồ sơ.

### 2.3. Phiên bản và gửi lại request

Đề xuất contract dùng ETag cho aggregate và If-Match cho cập nhật/hành động lên resource đã tồn tại. Ví dụ response header `ETag: "AAAAAAAAB9E="`; client gửi lại `If-Match: "AAAAAAAAB9E="`. Body resource có `version` tương ứng để Flutter lưu. Thiếu header trả 428; phiên bản cũ trả 412 và client phải tải lại, không tự ghi đè.

**DB hiện mới có RowVersion ở StockSegment, Incident và StockDisposition.** Muốn áp dụng quy ước đồng nhất phải bổ sung version cho các aggregate còn lại. Với child như chi tiết phiếu/hold/link, dùng phiên bản của aggregate cha; mọi thay đổi child phải làm thay đổi version cha trong cùng transaction. Không lấy rowversion segment thay cho version phiếu.

Lệnh tạo mới và POST hành động có ghi dữ liệu yêu cầu `Idempotency-Key` là UUID (login và preview FEFO được miễn). Khóa scoped theo người gọi + method + route + key, lưu request hash, If-Match gốc và kết quả cùng giao dịch. Gửi lại đúng request trả cùng kết quả/Location; khác request trả 409. Kiểm tra xác thực/quyền hiện tại trước khi replay, replay cùng khóa trước khi kiểm tra lại ETag đã thay đổi. Response có thể giữ snapshot kết quả gốc; muốn số liệu mới gọi GET.

**Cần bảng IdempotencyRequest trước khi triển khai cơ chế này.** Đề xuất giữ record tối thiểu 24 giờ, không hứa chống tạo trùng vô thời hạn. Unique DocumentNo/Code vẫn là hàng rào lâu dài. POST một phiếu đã Posted bằng khóa khác trả 409 `INVALID_STATE`, không tạo movement mới. Unique nguồn movement vẫn phải được giữ.

## 3. Quyền đề xuất

Ký hiệu: **A** Admin; **W** WarehouseStaff; **Q** QualityManager. Tất cả nghiệp vụ theo kho đều cần assignment tương ứng, riêng A đọc được toàn bộ theo quyền hiện có. Danh mục chung không mang số dư và không bị gắn kho.

| Nhóm API | A | W | Q |
|---|---|---|---|
| Tài khoản, danh mục, quyền kho | Quản lý | Đọc danh mục | Đọc danh mục |
| Lô | Đọc/tạo/sửa theo ràng buộc | Đọc/tạo để nhập | Đọc/tạo để nhập |
| Nhập/xuất thông thường | Đọc | Lập/Post trong kho được giao | Lập/Post trong kho được giao |
| Quyết định chất lượng/gỡ chặn | Đọc | Đọc | Thực hiện trong kho được giao |
| Báo sự cố/thêm phạm vi cách ly | Đọc | Thực hiện trong kho được giao | Thực hiện trong kho được giao |
| Điều tra/đóng sự cố | Đọc | Đọc | Thực hiện trong kho được giao |
| Phiếu xử lý | Đọc | Lập/Post sau duyệt | Lập/duyệt/Post |
| Hồ sơ quốc tế | Quản lý | Quản lý trong phạm vi quy tắc dưới đây | Quản lý trong phạm vi quy tắc dưới đây |
| Tồn/báo cáo | Toàn bộ | Kho được giao | Kho được giao |
| Audit | Toàn bộ | Không đọc trực tiếp | Chỉ lịch sử resource trong kho được giao |

Admin không mặc nhiên có thẩm quyền chất lượng hoặc Post kho trong đề xuất này. Hiện Role chỉ có một giá trị; nếu một người phải kiêm Admin và Q cần thêm multi-role/permission, không âm thầm bypass. Các ký hiệu trong endpoint luôn chịu ma trận này.

## 4. Bộ response dùng chung

Định nghĩa sau ghi đủ fields; các endpoint tham chiếu tên model để tránh lặp JSON. Dấu `?` = nullable. Các ID là int, quantity/count là int, thời điểm ISO; tiền là chuỗi decimal. `version` là chuỗi token, không phải ngày giờ.

| Model | Fields |
|---|---|
| UserResponse | id, username, fullName, role, warehouseIds[], version |
| WarehouseResponse | id, code, name, version |
| AssignmentResponse | id, userId, username, warehouseId, warehouseName, version |
| OrganizationResponse | id, code, name, country, kind, version |
| VaccineResponse | id, code, name, manufacturerId, manufacturerName, dosesPerVial, vialsPerPack, storageMin, storageMax, version |
| BatchResponse | id, vaccineId, vaccineCode, vaccineName, batchNo, manufacturedAt?, expiresAt, expiryStatus, daysToExpiry, version |
| ReceiptLineResponse | id, batchId, vaccineId, vaccineCode, vaccineName, batchNo, expiresAt, quantity, unitPrice, lineTotal, stockSegmentId? |
| ReceiptResponse | id, documentNo, warehouseId, warehouseName, supplierId, supplierName, documentDate, status, createdBy{id,fullName}, postedAt?, lines: ReceiptLineResponse[], totalQuantity, totalAmount, version |
| SegmentResponse | id, receiptDetailId, receiptId, warehouseId, warehouseName, batchId, batchNo, vaccineId, vaccineCode, vaccineName, expiresAt, qualityStatus, onHand, reserved, available, activeHoldCount, blockReasons[], version |
| IssueLineResponse | id, stockSegmentId, vaccineId, vaccineName, batchId, batchNo, expiresAt, quantity, unitPrice, lineTotal, reservationActive |
| IssueResponse | id, documentNo, warehouseId, warehouseName, recipientId, recipientName, documentDate, status, createdBy{id,fullName}, postedAt?, lines: IssueLineResponse[], totalQuantity, totalAmount, canPost, blockReasons[], version |
| QualityDecisionResponse | id, stockSegmentId, incidentId?, status, reason, decidedBy{id,fullName}, decidedAt |
| IncidentHoldResponse | id, incidentId, stockSegmentId, batchNo, vaccineName, blockedAt, releasedAt?, releasedById?, releaseReason? |
| IncidentResponse | id, code, warehouseId, kind, description, status, occurredAt, reportedAt, reportedBy{id,fullName}, closedAt?, closedById?, resolution?, holds: IncidentHoldResponse[], impactedDraftIssueIds[], version |
| DispositionLineResponse | id, stockSegmentId, batchId, batchNo, vaccineId, vaccineName, quantity |
| DispositionResponse | id, documentNo, warehouseId, kind, supplierId?, incidentId?, reason, documentDate, status, createdBy{id,fullName}, approvedById?, approvedAt?, postedAt?, lines: DispositionLineResponse[], totalQuantity, version |
| ShipmentLinkResponse | id, tradeShipmentId, receiptId?, issueId?, documentNo, documentStatus, quantity |
| TradeShipmentResponse | id, code, kind, partnerId, partnerName, originCountry, destinationCountry, status, expectedDate?, links: ShipmentLinkResponse[], receivedQuantity, issuedQuantity, version |
| MovementResponse | id, stockSegmentId, batchId, vaccineId, warehouseId, quantityDelta, sourceType, sourceId, sourceDetailId, documentNo, effectiveDate, postedAt |
| AuditResponse | id, actor{id,username}, action, entityType, entityId, details, occurredAt |

Danh sách phiếu dùng `ReceiptSummary`, `IssueSummary`, `DispositionSummary`: cùng các trường header, totalQuantity/totalAmount nếu có và version, **không nhúng lines**; chi tiết gọi GET theo ID. Danh sách IncidentSummary không nhúng holds mà trả activeHoldCount; TradeShipmentSummary không nhúng links. Điều này tránh response lớn; các số tổng được tính sau khi áp quyền.

`storageMin/storageMax` là JSON number biểu diễn decimal theo °C; khác với giá tiền đã quy định dùng chuỗi. `canPost` là gợi ý theo dữ liệu và quyền người gọi tại thời điểm GET, không thay thế kiểm tra trong POST. ID/tên của người thao tác trong response là thông tin hiển thị giới hạn, không nhúng cả UserResponse hoặc thông tin xác thực.

## 5. Auth, tài khoản và phân quyền kho

### 5.1. Auth

| Method + route | Quyền | Request | Response / mục đích |
|---|---|---|---|
| POST `/auth/login` | Public | `{username,password}` | 200 `{accessToken,tokenType:"Bearer",expiresIn:900,user:UserResponse}`; đăng nhập |
| GET `/auth/me` | Đã đăng nhập | Không body | 200 UserResponse; lấy vai trò/quyền kho mới nhất |
| POST `/auth/change-password` | Đã đăng nhập | `{currentPassword,newPassword}` | 200 `{reauthenticationRequired:true}`; đổi mật khẩu và vô hiệu token cũ |
| POST `/auth/logout` | Đã đăng nhập | `{}` | 200 `{loggedOut:true}`; thu hồi các token hiện có của tài khoản trong MVP |

Login không tiết lộ username tồn tại hay không, sai credentials trả 401 cùng thông báo. Mật khẩu không trim, không log; đề xuất độ dài 12–128 ký tự, dùng password hasher, không mã hóa đối xứng. Không có đăng ký public. User đầu tiên tạo bằng seed/CLI riêng, không tạo tài khoản qua API không bảo vệ.

Đề xuất access token 15 phút, chưa refresh token. JWT chỉ dùng để xác thực danh tính; quyền kho lấy từ DB. Đổi role/password/logout tăng `AuthVersion`, so sánh claim với DB mỗi request; cần thêm cột này. Logout ở contract này là đăng xuất mọi phiên, không hứa đăng xuất từng thiết bị; refresh token/session riêng là P2.

### 5.2. Người dùng và assignment

| Method + route | Quyền | Request | Response / lưu ý |
|---|---|---|---|
| GET `/users` | A | Query: page, pageSize, search, role; sort=username hoặc id | Page<UserResponse> |
| GET `/users/{id}` | A | ID | UserResponse |
| POST `/users` | A | `{username,password,fullName,role}` | 201 UserResponse; chưa tự cấp quyền kho |
| PUT `/users/{id}` | A | If-Match; `{fullName,role}` | 200 UserResponse; username bất biến, đổi role thu hồi token |
| POST `/users/{id}/reset-password` | A | If-Match; `{newPassword,reason}` | 200 `{id,reauthenticationRequired:true,version}`; audit, không trả mật khẩu |
| GET `/warehouse-assignments` | A | Query: userId?, warehouseId?, page/pageSize | Page<AssignmentResponse> |
| POST `/warehouse-assignments` | A | `{userId,warehouseId}` | 201 AssignmentResponse; trùng cặp trả 409 |
| DELETE `/warehouse-assignments/{id}` | A | If-Match; không body | 204; gỡ quyền, giữ nguyên lịch sử phiếu |

Không xóa tài khoản qua API vì liên kết nhật ký/chứng từ. Chưa có disable user; cần `IsActive` nếu triển khai sau. Không cho admin tự hạ role của tài khoản admin cuối cùng; reset mật khẩu tài khoản khác phải có lý do và audit. Không trả PasswordHash ở bất cứ response nào.

Assignment không sửa trực tiếp: gỡ cặp cũ và thêm cặp mới. Gỡ quyền phải có hiệu lực ở request tiếp theo, không chờ JWT hết hạn.

## 6. Danh mục

Tất cả GET yêu cầu đăng nhập; POST/PUT/DELETE yêu cầu A, riêng tạo lô xem mục 7. API danh mục không chứa số tồn kho.

| Resource | List/detail | POST body | PUT body | Response |
|---|---|---|---|---|
| Kho | GET `/warehouses`, GET `/warehouses/{id}` | `/warehouses`: `{code,name}` | `/warehouses/{id}`: `{code,name}` | WarehouseResponse |
| Đối tác | GET `/organizations`, GET `/organizations/{id}` | `/organizations`: `{code,name,country,kind}` | `/organizations/{id}`: cùng fields | OrganizationResponse |
| Vaccine | GET `/vaccines`, GET `/vaccines/{id}` | `/vaccines`: `{code,name,manufacturerId,dosesPerVial,vialsPerPack,storageMin,storageMax}` | `/vaccines/{id}`: cùng fields | VaccineResponse |

POST trả 201; PUT cần If-Match và trả 200. DELETE tương ứng `/warehouses/{id}`, `/organizations/{id}`, `/vaccines/{id}` cần If-Match, trả 204; nếu có bất kỳ tham chiếu nào trả 409 `RESOURCE_IN_USE`, không cascade delete. List trả Page<Model>.

Filter:

- Warehouses: search, page/pageSize, sort=code/name/id; W/Q chỉ thấy kho được giao.
- Organizations: search, kind?, country?, page/pageSize, sort=code/name/id.
- Vaccines: search, manufacturerId?, page/pageSize, sort=code/name/id.

Đề xuất `Organization.kind` trong MVP là một trong Manufacturer/Supplier/Recipient/Carrier; mỗi row một vai trò. Một đơn vị thực tế kiêm nhiều vai trò tạm dùng các mã riêng, cần bảng OrganizationRole nếu muốn một row có nhiều vai trò. Không tự thêm enum Combined mơ hồ. ManufacturerId phải trỏ đơn vị Manufacturer; supplier/recipient/partner kiểm tra theo vai trò trong nghiệp vụ.

Quy cách liều/lọ, lọ/hộp phải >0, storageMin < storageMax. Nếu vaccine đã có lô tham chiếu thì khóa sửa manufacturerId và quy cách để bảo toàn lịch sử. Đổi khoảng bảo quản chỉ A, audit và yêu cầu rà soát tác động; không tự kết luận hàng đang tồn còn đạt. Code có thể sửa khi chưa được dùng; đề xuất khóa sau khi có tham chiếu. Tên hiển thị không phải snapshot lịch sử trong DB hiện tại.

## 7. Lô và truy xuất

| Method + route | Quyền | Request | Response / mục đích |
|---|---|---|---|
| GET `/batches` | A/W/Q | Query: vaccineId?, search, expiryStatus?, expiresBefore?, page/pageSize; sort=expiresAt/batchNo/id | Page<BatchResponse>; tìm lô khi nhập |
| GET `/batches/{id}` | A/W/Q | ID | BatchResponse, không kèm tổng tồn ngoài quyền |
| POST `/batches` | A/W/Q | `{vaccineId,batchNo,manufacturedAt?,expiresAt}` | 201 BatchResponse |
| PUT `/batches/{id}` | A | If-Match; `{manufacturedAt?,expiresAt}` | 200 BatchResponse; chỉ lô chưa có chi tiết nhập |
| DELETE `/batches/{id}` | A | If-Match | 204; chỉ lô chưa được tham chiếu |
| GET `/batches/{id}/trace` | A/W/Q | Query warehouseId?, page/pageSize | 200 `{batch:BatchResponse,warehouses:[{warehouseId,onHand,reserved,available}],movements:Page<MovementResponse>}` |

Ngày sản xuất nếu có không sau hạn dùng. Có thể ghi nhận lô đã hết hạn để tiếp nhận/cách ly/xử lý, không vì tạo lô thành công mà cho xuất. expiryStatus: Expired nếu expiresAt <= ngày nghiệp vụ hôm nay; NearExpiry nếu còn 1–30 ngày; Valid nếu >30 ngày. Mốc 30 là mặc định UI đề xuất, không phải quy định bảo quản.

Trùng vaccineId–batchNo: trả 409 kèm existingBatchId nếu metadata trùng, `BATCH_METADATA_CONFLICT` nếu hạn dùng/ngày sản xuất khác; UI chọn lô đã có, không tự ghi đè. Lô đã dùng muốn sửa metadata phải có quy trình hiệu chỉnh/audit riêng sau này, không mở PUT để đổi hạn dùng của tồn đang có.

Trace chỉ trả movements/kho được phép; không lộ đơn vị nhận hoặc số phiếu ở kho khác. Các kho trong `warehouses[]` không phân trang riêng nhưng chỉ trong phạm vi quyền; movements phân trang theo postedAt,id.

## 8. Phiếu nhập

### 8.1. Request và response

`CreateReceiptRequest` và `UpdateReceiptRequest`:

```json
{
  "documentNo": "PN-2026-001",
  "warehouseId": 1,
  "supplierId": 5,
  "documentDate": "2026-11-06",
  "lines": [
    { "batchId": 10, "quantity": 100, "unitPrice": "125000.00" }
  ]
}
```

| Method + route | Quyền | Request | Response |
|---|---|---|---|
| GET `/receipts` | A/W/Q | warehouseId?, status?, supplierId?, search (documentNo), fromDate?, toDate?, page/pageSize; sort=documentDate/id | Page<ReceiptSummary> |
| GET `/receipts/{id}` | A/W/Q | ID | ReceiptResponse |
| POST `/receipts` | W/Q | CreateReceiptRequest | 201 ReceiptResponse, status Draft |
| PUT `/receipts/{id}` | W/Q | If-Match + UpdateReceiptRequest | 200 ReceiptResponse; chỉ Draft |
| DELETE `/receipts/{id}` | W/Q | If-Match | 204; chỉ Draft, xóa chi tiết cùng transaction |
| POST `/receipts/{id}/post` | W/Q | If-Match + `{}` | 200 ReceiptResponse; Posted, lines có stockSegmentId |

### 8.2. Logic chi tiết

- Draft đề xuất tối thiểu một dòng, tối đa 200 dòng; không có dòng batchId trùng trong cùng phiếu. Số lượng >0, giá >=0, mã phiếu unique. Ngày nhập không được ở tương lai khi Post; mặc định chỉ cho ngày hôm nay trong MVP để tránh ghi lùi thay đổi báo cáo. Khác chính sách cần quyền/kỳ riêng.
- Kiểm tra kho tồn tại, quyền người thao tác và supplier đúng loại. Khi sửa warehouse phải có quyền ở cả kho cũ và mới; MVP nên khóa warehouseId/documentNo sau tạo để giảm lỗi, request PUT phải giữ nguyên.
- PUT thay toàn bộ lines khi Draft; ID chi tiết có thể thay đổi, chưa có StockSegment/movement trước Post nên không ảnh hưởng tồn. Resource có link hồ sơ phải kiểm tra lại tương thích nhà cung cấp/loại hồ sơ.
- Post trong một transaction: khóa phiếu, kiểm tra Draft + không có movement cũ → mỗi line tạo một segment Pending tại đúng kho → tạo movement +quantity → cập nhật Posted/postedAt → audit → commit.
- Hạn đã qua hoặc nghi ngờ tiếp nhận không làm mất ghi nhận vật lý: segment Pending không khả dụng; tiếp theo Q đánh giá hoặc người báo tạo sự cố. Chưa lưu checklist tiếp nhận hoặc nhiệt độ vận chuyển dạng số trong schema hiện tại.
- Không sửa/xóa Posted. Chưa có đảo phiếu nên lỗi phiếu Posted phải báo quản lý, không sửa trực tiếp DB qua API.

Response rút gọn minh họa:

```json
{
  "id": 101,
  "documentNo": "PN-2026-001",
  "status": "Posted",
  "postedAt": "2026-11-06T08:00:00Z",
  "lines": [{"id": 201, "batchId": 10, "quantity": 100, "stockSegmentId": 301}],
  "version": "AAAAAAAAB9E="
}
```

Ví dụ trên bỏ các trường tên/giá cho dễ đọc; response đầy đủ theo ReceiptResponse ở mục 4.

## 9. Tồn và chất lượng

| Method + route | Quyền | Request | Response |
|---|---|---|---|
| GET `/inventory/segments` | A/W/Q | warehouseId?, vaccineId?, batchId?, qualityStatus?, hasActiveHold?, includeZero=false, search, page/pageSize; sort=expiresAt/id | Page<SegmentResponse> |
| GET `/inventory/segments/{id}` | A/W/Q | ID | SegmentResponse, ETag của segment |
| GET `/inventory/summary` | A/W/Q | warehouseId?, vaccineId?, search, page/pageSize | Page<{warehouseId,warehouseName,vaccineId,vaccineName,onHand,reserved,available}> |
| GET `/inventory/segments/{id}/movements` | A/W/Q | fromDate?, toDate?, page/pageSize; sort=postedAt/id | Page<MovementResponse> |
| GET `/inventory/segments/{id}/quality-decisions` | A/W/Q | page/pageSize | Page<QualityDecisionResponse>, mới nhất trước |
| POST `/inventory/segments/{id}/quality-decisions` | Q | If-Match của segment; `{status,reason,incidentId?}` | 201 `{decision:QualityDecisionResponse,segment:SegmentResponse}`; Location trỏ GET decision |
| GET `/quality-decisions/{id}` | A/W/Q | ID, scope từ segment | QualityDecisionResponse |

blockReasons là danh sách mã không loại trừ nhau: `PENDING_QUALITY`, `QUARANTINED`, `REJECTED`, `EXPIRED`, `INCIDENT_HOLD`, `NO_AVAILABLE_STOCK`. Không cộng các lý do như các lượng trừ độc lập vì dễ trừ hai lần.

Quality request chỉ nhận Released/Quarantined/Rejected, không cho đặt về Pending tùy ý. Reason bắt buộc. Initial Pending không nhất thiết có decision; các thay đổi sau đều append decision, không sửa/xóa lịch sử.

- Released chỉ khi còn hạn theo ngày nghiệp vụ và **không còn hold active**. Quarantined → Released sau đánh giá hợp lệ; Rejected là trạng thái cuối trong MVP, không giải phóng lại bằng endpoint thường.
- incidentId nếu có phải thuộc cùng kho và có liên kết segment; bỏ trống dành cho đánh giá tiếp nhận hoặc cách ly thủ công. Chất lượng thay đổi trong transaction, kiểm tra lại hold sau khi lấy khóa segment.
- Chuyển Quarantined/Rejected không giảm onHand và không tự hủy reservation; các phiếu nháp liên quan bị đánh dấu canPost=false trong response dẫn xuất.
- Xử lý chất lượng không tự bỏ hold; gọi hành động release của sự cố rồi mới giải phóng khi phù hợp. Nếu đồng thời có sự cố khác, vẫn không được Released.

## 10. Sự cố và phạm vi cách ly

### 10.1. Tạo sự cố

```json
{
  "code": "SC-2026-001",
  "warehouseId": 1,
  "kind": "TemperatureExcursion",
  "description": "Phát hiện thông tin bất thường, cần đánh giá.",
  "occurredAt": "2026-11-06T13:30:00+07:00",
  "stockSegmentIds": [301, 302]
}
```

Kind: TemperatureExcursion, PackagingDamage, Expiry, Recall, Other. Request không truyền reportedAt/reportedById/status. Schema chưa có readings nhiệt độ hoặc tệp minh chứng; description chỉ là mô tả, không giả lập hệ thống IoT.

| Method + route | Quyền | Request | Response |
|---|---|---|---|
| GET `/incidents` | A/W/Q | warehouseId?, kind?, status?, search, fromDate?, toDate?, page/pageSize; sort=reportedAt/id | Page<IncidentSummary> |
| GET `/incidents/{id}` | A/W/Q | ID | IncidentResponse |
| POST `/incidents` | W/Q | Body ở trên | 201 IncidentResponse |
| POST `/incidents/{id}/segments` | W/Q | If-Match của incident; `{stockSegmentIds:[303],reason}` | 200 IncidentResponse; mở rộng phạm vi |
| POST `/incidents/{id}/investigate` | Q | If-Match; `{}` | 200 IncidentResponse; Open → Investigating |
| POST `/incidents/{id}/holds/{holdId}/release` | Q | If-Match của incident; `{reason}` | 200 `{hold:IncidentHoldResponse,incidentVersion,segment:SegmentResponse}` |
| POST `/incidents/{id}/close` | Q | If-Match; `{resolution}` | 200 IncidentResponse |

### 10.2. Logic và các tình huống khó

- Tạo yêu cầu ít nhất một segment, tối đa 200; IDs không trùng, cùng warehouse, có nguồn từ phiếu nhập Posted. OccurredAt không ở tương lai; ReportedAt do server tạo, không trước OccurredAt.
- Transaction tạo Incident Open + các IncidentStockSegment chưa released + QualityDecision Quarantined theo từng segment + cập nhật QualityStatus + audit. Nếu segment đã Rejected, giữ Rejected; không hạ thành Quarantined. Nếu một ID sai, rollback toàn bộ, không tạo một phần.
- Chặn toàn segment, kể cả nghi ngờ chỉ một phần. Có thể thêm segment tồn 0 để phục vụ truy vết; không làm phát sinh tồn hoặc tự thu hồi hàng đã giao.
- Thêm phạm vi chỉ khi Open/Investigating, không được thêm cặp đã tồn tại, kể cả cặp đã gỡ. Muốn chặn lại tạo sự cố mới. Không có DELETE link: giữ lịch sử, thêm nhầm dùng release kèm lý do.
- Release chỉ cập nhật lượt chặn thuộc đúng incident; không tác động các incident khác. Không tự đổi QualityStatus thành Released. Không giải phóng hàng chỉ vì hồ sơ Closed.
- Đề xuất chỉ close khi mọi hold của incident đã được giải quyết bằng release có lý do. Đối với hàng không dùng được, lý do release là đã chuyển kiểm soát sang Rejected/xử lý hoặc đã xuất trả/tiêu hủy; QualityStatus vẫn Rejected, không coi release hold là cho phép sử dụng. Service phải kiểm tra điều kiện đóng, không chỉ thấy ReleasedAt khác null.
- Không mở lại/sửa mô tả/xóa sự cố trong MVP. Tạo mới nếu có sự kiện mới; lịch sử không bị mất.
- impactedDraftIssueIds chỉ liệt kê phiếu trong cùng kho có reservation active trên segment bị ảnh hưởng. Client thông báo cần phân bổ lại, không tự Post tiếp.
- Các command phải khóa segment theo thứ tự ID giống luồng Post xuất để tránh Post và cách ly vượt nhau. Sự cố commit trước thì Post sau phải bị chặn; nếu Post đã commit trước thì ghi rõ hàng đã xuất và chuyển xử lý ngoài kho, không sửa ngược lịch sử.

## 11. Phiếu xuất và FEFO

### 11.1. Preview phân bổ

`POST /issues/allocations/preview` — W/Q, chỉ đọc, không giữ hàng, không cần If-Match/Idempotency-Key.

```json
{
  "warehouseId": 1,
  "documentDate": "2026-11-07",
  "excludingIssueId": null,
  "items": [{ "vaccineId": 12, "quantity": 150 }]
}
```

```json
{
  "calculatedAt": "2026-11-06T08:00:00Z",
  "eligibilityDate": "2026-11-07",
  "canFulfill": true,
  "items": [{
    "vaccineId": 12,
    "requested": 150,
    "allocated": 150,
    "shortage": 0,
    "allocations": [
      {"stockSegmentId":301,"batchId":10,"batchNo":"LOT-A","expiresAt":"2026-11-30","quantity":100},
      {"stockSegmentId":302,"batchId":11,"batchNo":"LOT-B","expiresAt":"2027-01-31","quantity":50}
    ]
  }]
}
```

Thiếu hàng preview vẫn trả 200 với canFulfill=false/shortage, giúp UI hiển thị. Không nhận unitPrice từ tồn để tự tính giá xuất; người lập phiếu cung cấp giá tại bước tạo phiếu. Không mặc định giá xuất bằng giá nhập.

FEFO lọc đủ điều kiện ở ngày giao dự kiến, sắp expiresAt → ngày nhận/postedAt nhập → segmentId. excludingIssueId chỉ được dùng cho phiếu Draft mà người gọi có quyền, cùng kho; chỉ trừ reservation của phiếu đó khỏi lượng giữ, không loại reservation của người khác. Kết quả chỉ là gợi ý tại thời điểm tính, không bảo đảm lần lưu sau còn hàng.

### 11.2. Tạo/cập nhật phiếu

```json
{
  "documentNo": "PX-2026-001",
  "warehouseId": 1,
  "recipientId": 8,
  "documentDate": "2026-11-07",
  "lines": [
    {"stockSegmentId":301,"quantity":100,"unitPrice":"125000.00"},
    {"stockSegmentId":302,"quantity":50,"unitPrice":"125000.00"}
  ]
}
```

| Method + route | Quyền | Request | Response |
|---|---|---|---|
| GET `/issues` | A/W/Q | warehouseId?, status?, recipientId?, search, fromDate?, toDate?, blockedOnly?, page/pageSize; sort=documentDate/id | Page<IssueSummary> |
| GET `/issues/{id}` | A/W/Q | ID | IssueResponse; tính lại canPost/blockReasons |
| POST `/issues` | W/Q | Body trên | 201 IssueResponse; Draft, giữ hàng ngay |
| PUT `/issues/{id}` | W/Q | If-Match; body trên | 200 IssueResponse; thay toàn bộ lines và lượng giữ |
| POST `/issues/{id}/cancel` | W/Q | If-Match; `{reason}` | 200 IssueResponse; Cancelled, giải phóng giữ |
| POST `/issues/{id}/post` | W/Q | If-Match; `{}` | 200 IssueResponse; Posted |

Không DELETE phiếu xuất: cancel giữ lại lịch sử giữ hàng. Lý do cancel lưu audit vì Issue chưa có cột reason. Không có endpoint chỉnh reservation trực tiếp hoặc tự động hết hạn giữ hàng trong MVP.

### 11.3. Quy tắc khi lưu, sửa, cancel và Post

- Ít nhất 1, tối đa 200 dòng; không trùng segmentId; các segment cùng kho với phiếu. Quantity >0, giá >=0, recipient đúng loại. documentDate >= hôm nay khi lập nháp; không cho Post trước documentDate; nếu giao trễ dùng ngày kiểm tra `max(documentDate,hôm nay)` để không xuất lô đã hết hạn.
- Khóa warehouseId/documentNo sau tạo. Sửa recipient/date phải kiểm tra lại link hồ sơ nếu có. Phiếu ngoài Draft không được sửa.
- Đề xuất MVP bắt buộc phân bổ theo FEFO. Khi save, service tính lại kế hoạch FEFO cùng transaction; các dòng segment/quantity phải khớp kế hoạch theo tổng yêu cầu mỗi vaccine. Nếu lệch trả 409 `FEFO_ALLOCATION_CHANGED`, kèm gợi ý mới. Chưa cho override vì DB chưa lưu lý do và quyền ngoại lệ. Giá không tham gia lựa chọn lô.
- Save nháp kiểm tra Released, không hold, còn hạn và đủ lượng sau reservations khác. Đúng thì tạo IssueDetails + StockReservations active. Không giữ một phần khi thiếu hàng, rollback toàn bộ.
- PUT phải loại lượng giữ cũ của chính phiếu khỏi tính toán rồi thay reservation/lines nguyên tử. Nếu thay thất bại, giữ nguyên phiếu và reservation cũ. Không để khoảng trống commit giữa bỏ giữ cũ và giữ mới.
- Cancel chỉ từ Draft, tất cả reservations thành inactive và audit; không ghi movement.
- Post khóa phiếu và các segment theo ID, kiểm tra quyền/trạng thái/hạn/chất lượng/hold, tổng các dòng theo segment và tồn khả dụng **không trừ hai lần reservation của chính phiếu**. Không bắt buộc chuyển sang lô mới chỉ vì sau khi giữ có lô sớm hơn nhập thêm; giữ phân bổ đã cam kết nếu vẫn hợp lệ.
- Commit duy nhất cho movement -quantity, reservation inactive, Issue Posted/postedAt, audit và idempotency. Không có quy tắc “lưu phiếu thành công rồi trừ tồn sau”.
- Định nghĩa Post là hàng rời tồn kho. Chưa có trạng thái giao nhận/đang vận chuyển hoặc xác nhận bên nhận; nếu cần quản lý giao hàng thực tế phải mở rộng DB, không giả định Posted đồng nghĩa bên nhận đã nhận.

## 12. Xuất trả nhà cung cấp / tiêu hủy

### 12.1. Request chung

```json
{
  "documentNo": "XL-2026-001",
  "warehouseId": 1,
  "kind": "Destroy",
  "supplierId": null,
  "incidentId": 401,
  "reason": "Hàng bị từ chối sau đánh giá chất lượng.",
  "documentDate": "2026-11-06",
  "lines": [{ "stockSegmentId":301, "quantity":10 }]
}
```

| Method + route | Quyền | Request | Response |
|---|---|---|---|
| GET `/stock-dispositions` | A/W/Q | warehouseId?, kind?, status?, incidentId?, fromDate?, toDate?, search, page/pageSize; sort=documentDate/id | Page<DispositionSummary> |
| GET `/stock-dispositions/{id}` | A/W/Q | ID | DispositionResponse |
| POST `/stock-dispositions` | W/Q | Body trên | 201 DispositionResponse, Draft |
| PUT `/stock-dispositions/{id}` | W/Q | If-Match; body trên | 200 DispositionResponse, chỉ Draft |
| POST `/stock-dispositions/{id}/approve` | Q | If-Match; `{}` | 200 DispositionResponse, Approved |
| POST `/stock-dispositions/{id}/revoke-approval` | Q | If-Match; `{reason}` | 200 DispositionResponse, Draft; xóa trường phê duyệt hiện tại, giữ audit |
| POST `/stock-dispositions/{id}/cancel` | W/Q | If-Match; `{reason}` | 200 DispositionResponse, chỉ Draft → Cancelled |
| POST `/stock-dispositions/{id}/post` | W/Q | If-Match; `{}` | 200 DispositionResponse, chỉ Approved → Posted |

### 12.2. Logic cụ thể

- Loại ReturnToSupplier bắt buộc supplierId và từng segment phải có nguồn nhập từ chính supplier đó; Destroy bắt buộc supplierId=null. incidentId nếu có phải cùng kho và các segment phải thuộc phạm vi incident đó. Không bắt buộc có sự cố cho mọi xử lý, ví dụ hàng hết hạn theo kế hoạch.
- Tối đa 200 dòng, không trùng segment, quantity >0. Không sửa warehouse/documentNo sau tạo. Không có unitPrice/tổng tiền cho phiếu này vì schema chưa làm hoàn tiền/kế toán.
- Chỉ xử lý hàng Rejected, Quarantined hoặc hết hạn theo ngày xử lý; hàng Pending cần Q quyết định trước. Mặc định không cho tiêu hủy hàng Released còn hạn mà thiếu quy trình ngoại lệ.
- Draft không giữ hàng, Approved cũng chưa giữ hàng trong DB hiện tại. UI phải hiển thị “đã duyệt chưa bảo đảm số lượng”; kiểm tra lại toàn bộ tại Post. Không có hiệu lực giảm tồn khi approve.
- Post chỉ ngày hôm nay trong MVP; không ghi lùi. Khóa cùng cơ chế với xuất thường. Tồn vật lý trừ **mọi reservation active** phải >= lượng xử lý. Nếu hàng đang giữ cho phiếu xuất bị chặn, yêu cầu người phụ trách cancel/sửa phiếu đó trước; không tự lấy mất lượng giữ.
- Q có thể duyệt phiếu do mình lập trong MVP do nhân lực hạn chế, nhưng audit đầy đủ; nếu cần phân tách người lập/người duyệt, thêm quy tắc khác người mà không cần sửa schema.
- Post tạo movement âm theo StockDispositionDetail, cập nhật Posted/postedAt và audit trong một transaction. Không yêu cầu Released hoặc gỡ hold để tiêu hủy; quyền xử lý tách với điều kiện được phân phối.
- Hoàn tất xử lý không tự close incident hoặc release holds; Q đối chiếu lượng còn lại rồi xử lý hồ sơ. Không sửa/xóa Posted; chưa có chứng từ đảo.
- Revoke approval chỉ từ Approved, ghi lý do audit và reset approvedById/approvedAt về null theo constraint; muốn cancel Approved phải revoke trước. Cần khóa version để không revoke đồng thời Post.

## 13. Hồ sơ nhập khẩu/xuất khẩu

DB hiện có partner và links nhưng không có owner/warehouse trực tiếp trên hồ sơ. Để tránh lộ hồ sơ chưa có link, **đề xuất bổ sung WarehouseId** và giới hạn một hồ sơ thuộc một kho trong MVP. Hồ sơ nhiều kho là mở rộng sau.

Request tạo/cập nhật:

```json
{
  "code": "NK-2026-001",
  "warehouseId": 1,
  "kind": "Import",
  "partnerId": 5,
  "originCountry": "KR",
  "destinationCountry": "VN",
  "expectedDate": "2026-11-10"
}
```

TradeShipmentResponse cần bổ sung warehouseId/warehouseName từ migration đề xuất này.

| Method + route | Quyền | Request | Response |
|---|---|---|---|
| GET `/trade-shipments` | A/W/Q | warehouseId?, kind?, status?, partnerId?, search, page/pageSize; sort=expectedDate/id | Page<TradeShipmentSummary> |
| GET `/trade-shipments/{id}` | A/W/Q | ID | TradeShipmentResponse |
| POST `/trade-shipments` | A/W/Q | Body trên | 201 TradeShipmentResponse, Draft |
| PUT `/trade-shipments/{id}` | A/W/Q | If-Match; body trên | 200 TradeShipmentResponse; chỉ Draft |
| POST `/trade-shipments/{id}/transitions` | A/W/Q | If-Match; `{targetStatus,reason}` | 200 TradeShipmentResponse |
| POST `/trade-shipments/{id}/document-links` | A/W/Q | If-Match của shipment; `{receiptId:101,issueId:null}` hoặc ngược lại | 201 ShipmentLinkResponse; Location GET link |
| GET `/trade-shipments/{id}/document-links/{linkId}` | A/W/Q | IDs | ShipmentLinkResponse |
| DELETE `/trade-shipments/{id}/document-links/{linkId}` | A/W/Q | If-Match của shipment | 204; chỉ shipment Draft và chứng từ Draft |

Quy tắc:

- kind Import/Export; country dùng mã hai chữ cái theo danh sách nhóm chọn, không suy ra quốc gia chỉ từ tên đối tác. Import liên kết Receipt, Export liên kết Issue; chỉ một ID khác null mỗi link.
- partner Import phải là Supplier, Export là Recipient. Phiếu cùng kho và cùng đối tác với hồ sơ. Một phiếu thuộc tối đa một hồ sơ quốc tế, nhưng một hồ sơ có nhiều phiếu nhận/giao nhiều đợt. **Cần unique index receiptId/issueId trên ShipmentDocumentLink** để giữ quy tắc này khi request đồng thời.
- State đề xuất: Draft → Preparing → InTransit → Arrived → Completed; Draft/Preparing có thể Cancelled nếu chưa có phiếu Posted. Completed/Cancelled không chuyển tiếp. Không mở API sửa status tùy ý.
- Đóng Completed yêu cầu có ít nhất một link, mọi phiếu link đã Posted, không còn phiếu Cancelled. Không so sánh đủ số lượng kế hoạch vì DB chưa có shipment lines dự kiến; không hứa “đã nhận đủ theo hợp đồng”.
- Liên kết được thêm trước Completed/Cancelled, bao gồm đợt nhận thực tế vào Arrived; không gỡ link của phiếu Posted. Code/kind/warehouse/partner không đổi sau tạo; PUT giữ nguyên các giá trị này.
- receivedQuantity/issuedQuantity chỉ tổng phiếu Posted đúng loại; không tạo movement từ trạng thái hồ sơ. Với Import, lượng received ở kho có thể vẫn Pending/Quarantined, không đồng nghĩa đã giải phóng chất lượng.
- Chưa có tệp đính kèm, tờ khai, thanh toán, danh sách hàng kế hoạch hoặc thủ tục pháp lý tự động. Không đưa các trường đó vào DTO rồi bỏ dữ liệu khi save.

## 14. Dashboard, cảnh báo và báo cáo

Tất cả A/W/Q theo phạm vi kho; chỉ đọc, không cần If-Match hay Idempotency-Key.

| Method + route | Query | Response / mục đích |
|---|---|---|
| GET `/dashboard` | warehouseId? | `{asOf,scopeWarehouseIds[],counts:{warehouses,vaccines,draftReceipts,postedReceipts,draftIssues,postedIssues,openIncidents},stock:{onHandVials,reservedVials,availableVials},alerts:{nearExpirySegments,expiredSegments,activeIncidentHolds,pendingQualitySegments}}` |
| GET `/alerts/expiry` | warehouseId?, vaccineId?, mode=NearExpiry/Expired, withinDays=30 (1–365), page/pageSize | Page<{stockSegmentId,vaccineId,vaccineName,batchId,batchNo,warehouseId,expiresAt,daysToExpiry,onHand,qualityStatus}> |
| GET `/reports/inventory-period` | fromDate,toDate bắt buộc; warehouseId?, vaccineId?, batchId?, page/pageSize | `{fromDate,toDate,totals:{opening,received,issued,disposed,closing},rows:Page<InventoryPeriodRow>}` |
| GET `/reports/distributions` | fromDate,toDate, warehouseId?, batchId?, recipientId?, page/pageSize | Page<{issueId,documentNo,documentDate,recipientId,recipientName,warehouseId,vaccineId,batchId,batchNo,quantity}> |
| GET `/reports/dispositions` | fromDate,toDate, warehouseId?, kind?, batchId?, page/pageSize | Page<{dispositionId,documentNo,documentDate,kind,warehouseId,batchId,vaccineId,quantity,reason}> |

InventoryPeriodRow: warehouseId, vaccineId, vaccineName, batchId, batchNo, opening, received, issued, disposed, closing. Nhóm theo kho–lô, không nhóm qualityStatus hiện tại để chia lại số liệu lịch sử sai.

- Khoảng ngày inclusive, fromDate <= toDate, tối đa 366 ngày trong MVP. Report dựa movement.EffectiveDate; totals tính trên toàn bộ filter trước phân trang, không chỉ trang hiện tại.
- Opening = tổng delta trước fromDate. Received = movement nhập trong kỳ. Issued = số dương của lượng xuất thường trong kỳ. Disposed = số dương của lượng xuất trả/tiêu hủy trong kỳ. Closing = opening + received − issued − disposed.
- Giữ hàng và cách ly không làm thay đổi báo cáo tồn vật lý. Không dùng reservation hiện tại để suy ra reservation lịch sử; DB chưa có thời gian bắt đầu/kết thúc giữ nên chưa hỗ trợ báo cáo khả dụng tại một ngày quá khứ.
- Alert chỉ segment onHand >0, không bỏ hàng cách ly khỏi danh sách hết hạn. nearExpiry không bao gồm đã hết hạn; daysToExpiry có thể âm cho expired. Chỉ tính khi gọi API, chưa push/background.
- Tổng số lọ khác vaccine chỉ mang ý nghĩa số lượng vật lý, không phải tổng liều hoặc giá trị điều trị tương đương.
- Báo cáo phân phối chỉ Issue Posted, không tính Draft/Cancelled hoặc phiếu xử lý; báo cáo xử lý chỉ StockDisposition Posted.
- Chưa có ngưỡng tồn tối thiểu theo vaccine–kho nên chưa cung cấp API cảnh báo thiếu tồn có cấu hình. Muốn thêm cần bảng chính sách tồn.

## 15. Nhật ký

| Method + route | Quyền | Request | Response |
|---|---|---|---|
| GET `/audit-logs` | A | actorId?, entityType?, entityId?, action?, fromDate?, toDate?, page/pageSize; sort=occurredAt/id | Page<AuditResponse> |
| GET `/receipts/{id}/audit-logs` | A/Q | page/pageSize | Page<AuditResponse>, scope theo phiếu |
| GET `/issues/{id}/audit-logs` | A/Q | page/pageSize | Page<AuditResponse> |
| GET `/incidents/{id}/audit-logs` | A/Q | page/pageSize | Page<AuditResponse> |
| GET `/stock-dispositions/{id}/audit-logs` | A/Q | page/pageSize | Page<AuditResponse> |
| GET `/trade-shipments/{id}/audit-logs` | A/Q | page/pageSize | Page<AuditResponse> |

Audit append-only qua service, không có POST/PUT/DELETE công khai. Details dùng JSON đã lọc và tối đa 2000 ký tự, gồm lý do và thay đổi cần thiết; không nhét toàn bộ phiếu nhiều dòng vượt giới hạn. Không ghi password/hash/access token. Các action con phải ghi EntityType/EntityId của aggregate cha để truy vấn lịch sử theo quyền mà không parse thông tin nhạy cảm trong Details.

## 16. Health

| Route | Hiện trạng / response |
|---|---|
| GET `/health` | Đã có ngoài base URL; 200 `{status:"ok",service:"VaxStock.Api"}`. Chỉ liveness, không kiểm tra SQL |
| GET `/health/ready` | Đề xuất: 200 `{status:"ready"}` nếu SQL kết nối và migration đúng; 503 `{status:"notReady"}` khi chưa sẵn sàng. Không trả connection string/version máy |

## 17. Transaction, concurrency và kiểm thử bắt buộc

Một transaction nghiệp vụ bao gồm cả state, child rows, movement/reservation, audit và idempotency. Cùng một cơ chế khóa tồn phải được sử dụng cho Post nhập/xuất/xử lý, sửa giữ hàng, cách ly, gỡ chặn và quyết định chất lượng.

Đề xuất khóa aggregate trước rồi segment theo ID tăng dần, kết hợp isolation/SQL locks phù hợp. Với tạo mới reservation, chỉ đọc SUM rồi insert dưới ReadCommitted không đủ an toàn. Cần khóa segment làm điểm đồng bộ cho mọi request có thể thay đổi available; rowversion chỉ phát hiện xung đột nếu được cập nhật/kiểm tra đúng. Có timeout và xử lý deadlock, không retry lệnh tạo mới mù khi thiếu idempotency.

Các test bắt buộc trước khi nối Flutter:

1. Hai người giữ 80 lọ từ segment có 100: chỉ một yêu cầu thành công.
2. Hai request Post cùng phiếu: chỉ có một bộ movement; retry đúng khóa trả kết quả gốc.
3. Issue đang giữ 30/100, Post xuất 30 thành công, không bị trừ reservation hai lần.
4. Issue sửa phân bổ bị lỗi: giữ cũ và phiếu cũ vẫn nguyên.
5. Incident chặn segment đồng thời Post: kết quả tuần tự nhất quán, không lách hold đã commit.
6. Gỡ một trong hai hold không cho hàng xuất khi hold kia còn active.
7. Phiếu Approved không đủ tồn khi Post phải bị từ chối, không có movement một phần.
8. Lô đủ điều kiện khi nháp nhưng hết hạn khi Post bị chặn; kiểm tra sát ranh giới ngày nghiệp vụ.
9. Request thêm trường postedAt/createdById hoặc dùng ID kho khác bị từ chối.
10. Token của user đổi mật khẩu/role/logout không còn dùng được sau AuthVersion tăng.
11. Báo cáo có xử lý hàng: opening + received − issued − disposed đúng closing.
12. List/trace/errors/audit không lộ dữ liệu ngoài kho; các tổng không cộng dữ liệu kho bị ẩn.

## 18. Các migration bổ sung cần làm trước implementation

Đây là phần thiếu giữa schema hiện tại và contract đề xuất, **chưa được tạo bởi tài liệu này**:

| Thay đổi | Endpoint phụ thuộc / lý do |
|---|---|
| RowVersion cho AppUser, Warehouse, WarehouseAssignment, Organization, Vaccine, VaccineBatch, Receipt, Issue, TradeShipment | Đồng nhất version/ETag; bảo vệ sửa nháp, danh mục và phân quyền |
| AppUser.AuthVersion, default 0 | Thu hồi token sau reset/đổi password, đổi role và logout |
| Bảng IdempotencyRequest: actorId, method, route, key, requestHash, resultStatus, responseBody, responseHeaders, createdAt, expiresAt; unique scope | Retry an toàn cho tạo mới và hành động; dữ liệu lưu phải giới hạn kích thước và không chứa login/password |
| TradeShipment.WarehouseId + FK/index | Phạm vi quyền của hồ sơ ngay từ lúc chưa có link; dữ liệu cũ cần xác định kho trước khi chuyển NOT NULL |
| Unique filtered index ShipmentDocumentLink.ReceiptId / IssueId | Một phiếu không bị gắn vào hai hồ sơ quốc tế đồng thời; rà dữ liệu trùng trước migration |
| Check enum Organization.Kind, TradeShipment.Kind/Status theo contract đã chốt | Tránh tùy ý lưu trạng thái không hợp lệ; rà dữ liệu cũ trước khi siết |

Chưa cần thêm bảng chỉ để lưu tên response/tổng tiền/canPost; các giá trị đó dẫn xuất. Chưa triển khai API cho opened vial, cảm biến, file upload, transfer, recall ngoài kho, kiểm kê, đảo phiếu hoặc refresh token khi chưa có model lưu phù hợp.

## 19. Thứ tự triển khai và phân chia service

| Thứ tự | Module | Business service gợi ý |
|---|---|---|
| 1 | Migration nền hợp đồng, auth, user, assignment | AuthService, UserService, WarehousePermissionService |
| 2 | Danh mục, lô | MasterDataService, BatchService |
| 3 | Nhập và đọc tồn | ReceiptService, InventoryQueryService |
| 4 | Chất lượng, sự cố | QualityService, IncidentService |
| 5 | FEFO, giữ hàng, xuất | AllocationService, IssueService |
| 6 | Xuất trả/tiêu hủy | StockDispositionService |
| 7 | Hồ sơ quốc tế | TradeShipmentService |
| 8 | Dashboard/report/audit/ready | ReportService, AuditQueryService |

Tách API theo nghiệp vụ, không tạo một controller/service cho mỗi bảng một cách máy móc. Ví dụ ReceiptService quản lý Receipt + ReceiptDetail + Segment + Movement trong nghiệp vụ Post; StockReservation không có controller riêng.

## 20. Chuỗi gọi API để Flutter demo đầu cuối

```text
POST auth/login
→ GET auth/me
→ GET warehouses / vaccines / organizations
→ POST batches (hoặc chọn batch đã có)
→ POST receipts → POST receipts/{id}/post
→ GET inventory/segments
→ POST inventory/segments/{id}/quality-decisions (Released)
→ POST issues/allocations/preview
→ POST issues (giữ hàng)
→ POST incidents (nếu có sự cố)
→ GET issues/{id} (canPost=false khi bị chặn)
→ Q đánh giá: gỡ đúng hold + quyết định chất lượng, hoặc chọn xử lý hàng
→ PUT issues/{id} để phân bổ lại / cancel nếu không tiếp tục
→ POST issues/{id}/post khi hợp lệ
→ GET reports/inventory-period và batches/{id}/trace
```

Nhánh hàng không dùng được: Q quyết định Rejected → giải quyết lượng giữ liên quan → POST stock-dispositions → approve → post → đối chiếu tồn → hoàn tất các hold/hồ sơ sự cố theo quyết định.

Chưa viết implementation hoặc thay đổi schema trong đợt đặc tả API này. Các chính sách về ngày, vai trò, FEFO bắt buộc, quyền phê duyệt và phạm vi hồ sơ quốc tế là đề xuất để nhóm chốt cùng nhau trước khi code.
