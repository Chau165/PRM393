# Database theo flow nhập → sự cố → xuất

Trạng thái: schema và migration đã triển khai. Auth đã tách 3 tầng API → Business → Data Access, bổ sung AuthVersion/RowVersion tài khoản; xem [auth implementation](auth-implementation.md). Service/API nghiệp vụ kho chưa triển khai. Hợp đồng API đang được đề xuất tại [đặc tả API](vaccine-api-specification.md).

## Phạm vi

Database `VaxStockDev` có 21 bảng nghiệp vụ sau migration `IncidentAndDispositionFlow` (17 bảng gốc + 4 bảng mới). Các bảng SQL có hậu tố `Records`. Toàn bộ bảng có `Id int identity` làm khóa chính.

Giữ phạm vi lọ nguyên chưa mở, số lượng nguyên lọ. Chưa quản lý lọ dùng dở, IoT, vị trí tủ lạnh chi tiết, chuyển kho, thu hồi hàng đã giao, kiểm kê hoặc chứng từ đảo. Sự cố loại Recall chỉ ghi nhận/chặn hàng còn ở kho, chưa phải module thu hồi đầy đủ.

## Bốn bảng bổ sung

| Bảng | Property chính | Vai trò |
|---|---|---|
| IncidentRecords | Code, WarehouseId, Kind, Description, Status, OccurredAt, ReportedAt, ReportedById, ClosedAt?, ClosedById?, Resolution?, RowVersion | Hồ sơ sự cố, người báo, thời điểm và kết quả xử lý |
| IncidentStockSegmentRecords | IncidentId, StockSegmentId, BlockedAt, ReleasedAt?, ReleasedById?, ReleaseReason? | Phạm vi phần hàng bị chặn bởi từng sự cố và lịch sử gỡ chặn |
| StockDispositionRecords | DocumentNo, WarehouseId, Kind, SupplierId?, IncidentId?, Reason, DocumentDate, Status, CreatedById, ApprovedById?, ApprovedAt?, PostedAt?, RowVersion | Phiếu xuất trả nhà cung cấp hoặc tiêu hủy, có phê duyệt |
| StockDispositionDetailRecords | StockDispositionId, StockSegmentId, Quantity | Phần hàng và số lượng lọ được xử lý |

`int` dùng cho ID/số lượng; các thời điểm dùng `datetimeoffset`, ngày chứng từ dùng `date`, RowVersion do SQL Server sinh. Chuỗi dài tối đa 200 ký tự; Description, Resolution, ReleaseReason và Reason tối đa 2000. `?` là nullable.

Khóa ngoại nối Incident với Warehouse và người báo/đóng; bảng phạm vi nối Incident với StockSegment và người gỡ chặn; chứng từ xử lý nối Warehouse, Supplier, Incident và người tạo/duyệt; chi tiết nối chứng từ với StockSegment. Tất cả khóa ngoại dùng Restrict/No Action, không xóa cascade.

Hai bảng hiện có được mở rộng:

- `QualityDecisionRecords.IncidentId?`: quyết định chất lượng có thể gắn với sự cố cụ thể, vẫn hỗ trợ đánh giá tiếp nhận không có sự cố.
- `StockMovementRecords.StockDispositionDetailId?`: ghi giảm tồn từ phiếu xử lý. Mỗi movement có đúng một nguồn: ReceiptDetail (+), IssueDetail (-) hoặc StockDispositionDetail (-). Mỗi dòng nguồn có tối đa một movement.

## Trạng thái và ý nghĩa

| Đối tượng | Trạng thái |
|---|---|
| Phiếu nhập | Draft → Posted |
| Chất lượng phần hàng | Pending, Released, Quarantined, Rejected |
| Sự cố | Open → Investigating → Closed; được đóng trực tiếp từ Open nếu quy trình cho phép |
| Phiếu xử lý | Draft → Approved → Posted; Draft có thể Cancelled |
| Loại xử lý | ReturnToSupplier hoặc Destroy |

DB ràng buộc các giá trị/trường liên quan, không tự thi hành thứ tự chuyển trạng thái. Việc mở lại sự cố nên tạo sự cố mới để giữ lịch sử lượt chặn; schema hiện chỉ có một liên kết cho mỗi cặp sự cố–segment.

Closed bắt buộc có người, thời điểm và kết luận; thời gian đóng không trước báo cáo. Gỡ chặn bắt buộc có người, thời điểm và lý do, không trước thời điểm chặn. Phiếu Posted phải có phê duyệt và thời điểm Post không trước duyệt. ReturnToSupplier bắt buộc SupplierId; Destroy không dùng SupplierId. Lý do xử lý không được chỉ có khoảng trắng.

## Cách ghi dữ liệu theo nghiệp vụ

### 1. Nhập kho

Post nhập sau này cần thực hiện nguyên tử: đổi Receipt sang Posted, tạo StockSegment Pending và StockMovement dương. Hàng Pending có tồn vật lý nhưng chưa đủ điều kiện xuất. QualityDecision lưu quyết định; cập nhật QualityStatus cùng giao dịch khi giải phóng/cách ly.

### 2. Phát hiện sự cố

Trong cùng giao dịch ứng dụng: tạo Incident, liên kết các StockSegment liên quan vào IncidentStockSegment, chuyển chất lượng sang Quarantined và ghi quyết định/nhật ký. Các lượt giữ trên phiếu xuất liên quan chưa bị trừ tồn; phải hiển thị bị chặn và phân bổ lại trước Post.

Một sự cố có thể ảnh hưởng nhiều segment. Một segment có thể bị nhiều sự cố độc lập. Quy ước an toàn của MVP là chặn toàn bộ segment; nếu chỉ một phần hàng bị nghi ngờ, vẫn cách ly toàn bộ segment để đánh giá. Chia nhỏ segment chưa thuộc phạm vi hiện tại.

### 3. Đánh giá và gỡ chặn

Ghi QualityDecision, người quyết định và lý do. Chỉ gỡ lượt chặn của sự cố đã xử lý. Đóng hồ sơ không tự gỡ chặn; gỡ chặn không tự biến phần hàng thành Released. Muốn xuất phải đồng thời thỏa chất lượng Released và không còn liên kết sự cố chưa ReleasedAt.

Nếu không đủ điều kiện phân phối, giữ Rejected/Quarantined và lập phiếu xử lý. Không xóa segment hoặc giảm tồn chỉ bằng đổi trạng thái.

### 4. Xuất trả/tiêu hủy

Tạo phiếu Draft và các chi tiết số lượng dương. Người có thẩm quyền duyệt thành Approved. Khi thực hiện xử lý, Post tạo movement âm liên kết từng chi tiết; đổi trạng thái Posted trong cùng giao dịch. Đây là lối ra cho hàng không đủ điều kiện xuất thông thường, nên không yêu cầu Released như phiếu giao hàng.

Vẫn phải kiểm tra tồn vật lý còn lại, lượng giữ/xử lý cạnh tranh, kho và quyết định phê duyệt. Phiếu Approved không tự giữ hàng trong schema hiện tại; khi Post phải khóa/kiểm tra lại lượng hàng. Để chỉnh sửa phiếu đã duyệt cần luồng hủy phê duyệt tại service sau này; chưa cho sửa/xóa trực tiếp phiếu Posted.

### 5. Xuất thông thường

FEFO phân bổ trong tập hàng Released, chưa hết hạn theo ngày xuất dự kiến, không có sự cố đang chặn và còn lượng khả dụng. Nháp tạo reservation; Post kiểm tra lại, ghi movement âm, kết thúc reservation và cập nhật phiếu trong một giao dịch.

## Công thức và các giới hạn của DB

- Tồn thực tế segment = SUM(StockMovement.QuantityDelta), gồm cả hàng hết hạn/cách ly chưa được xử lý.
- Lượng giữ = tổng reservation Active của các dòng xuất nháp tương ứng.
- Khả dụng segment = 0 nếu chưa đủ điều kiện; nếu đủ điều kiện, lấy tồn thực tế trừ lượng giữ. Giá trị âm phải được coi là lỗi dữ liệu, không âm thầm dùng clamp để che lỗi.
- Tổng tồn vaccine–kho là tổng các segment có cùng vaccine và kho; không cộng số lượng ReceiptDetail lần nữa vì đã có movement.
- Index được thêm cho hạn dùng, kho–chất lượng, kho–trạng thái sự cố, segment–lượt chặn và các khóa chống Post lặp.

Schema bảo vệ khóa ngoại, uniqueness, dấu movement, số lượng dương và tính đầy đủ của dữ liệu trạng thái. Những điều sau **chưa được DB tự bảo đảm**, cần service/giao dịch khi chốt kiến trúc:

1. Cùng kho giữa sự cố, segment, phiếu và các nguồn; nguồn movement đúng segment và số lượng khớp dòng chứng từ.
2. Chỉ tạo movement cho phiếu Posted, đủ quyền và có đủ tồn; không phát sinh movement bằng CRUD tùy ý.
3. Không xuất vượt tồn khi hai request đồng thời; RowVersion chỉ có tác dụng khi code thực sự cập nhật/kiểm tra nó, không phải cơ chế khóa tồn tự động.
4. Không gỡ chặn nhầm sự cố, không xuất hàng hết hạn hoặc chưa Released, không bỏ qua reservation.
5. Nhật ký/decision bất biến, quyền phê duyệt, và quy tắc chuyển trạng thái.

Không bổ sung trigger tự Post hoặc tự tính chất lượng để tránh chia logic nghiệp vụ giữa SQL và kiến trúc BE chưa chốt.

## Migration và kiểm tra

Migration mới nâng cấp nối tiếp migration cũ, không reset/drop database hoặc bảng nghiệp vụ. File `backend/schema.sql` được xuất lại gồm cả hai migration để cài mới hoặc nâng cấp idempotent.

Tại thư mục `backend`:

```powershell
dotnet build VaxStock.sln
dotnet ef database update --project VaxStock.DataAccess --startup-project VaxStock.Api
dotnet ef migrations has-pending-model-changes --project VaxStock.DataAccess --startup-project VaxStock.Api
sqlcmd -S localhost -E -C -d VaxStockDev -b -i verify-schema.sql
sqlcmd -S localhost -E -C -d VaxStockDev -b -i test-database-flow.sql
```

Test flow dùng transaction và rollback fixture: tạo dữ liệu nhập, hai sự cố độc lập, gỡ một lượt chặn, tạo xử lý tiêu hủy và đối chiếu tồn; kiểm tra từ chối Post lặp, nhiều nguồn movement, xuất trả thiếu nhà cung cấp và đóng sự cố thiếu kết luận. Test kiểm tra tính lưu trữ/ràng buộc, không thay thế test API hoặc kiểm thử cạnh tranh của service chưa triển khai.
