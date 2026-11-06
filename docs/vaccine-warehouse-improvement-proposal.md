# Đề xuất cải tiến: Ứng dụng quản lý kho vaccine

Ngày lập: 24/10/2026. Trạng thái: đề xuất thiết kế, chưa triển khai.

## 1. Định hướng và tên đề tài

**Tên gợi ý: VaxStock — Quản lý kho vaccine theo lô và hạn sử dụng.**

Tên đề tài có thể dùng khi trình bày: **“Xây dựng ứng dụng quản lý nhập, xuất, tồn kho vaccine, theo dõi hạn sử dụng và hồ sơ xuất nhập khẩu bằng Flutter”.**

Mục tiêu là phát triển project Warehouse Management Demo hiện tại thành một hệ thống có thể trả lời: vaccine nào đang ở kho nào, thuộc lô nào, còn bao nhiêu, hạn dùng khi nào, có được phép xuất không và đã giao cho đơn vị nào.

Trong tài liệu này, “nhập/xuất kho” là biến động hàng vật lý; “nhập khẩu/xuất khẩu” là nghiệp vụ giao nhận quốc tế có hồ sơ riêng. Không đồng nhất hai khái niệm này. Phạm vi xuất nhập khẩu của đồ án là quản lý thông tin và tiến độ hồ sơ nội bộ; chưa tích hợp khai báo hải quan hoặc kết luận hồ sơ đáp ứng quy định pháp luật.

## 2. Hiện trạng có thể kế thừa

| Thành phần hiện có | Hướng sử dụng tiếp |
|---|---|
| Flutter, giao diện thích ứng Android/Web/Windows | Giữ nền tảng và cách tổ chức màn hình |
| Danh mục kho, sản phẩm, loại sản phẩm, đơn vị tính, nhà cung cấp | Mở rộng thành danh mục vaccine và đối tác |
| Phiếu nhập/xuất với trạng thái draft/posted | Bổ sung chi tiết theo lô và kiểm tra điều kiện xuất |
| Tồn thực tế, hàng đang giữ, khả dụng | Chuyển từ cấp kho–sản phẩm xuống kho–vị trí–lô |
| Báo cáo nhập–xuất–tồn theo khoảng ngày | Bổ sung chiều lô, hạn dùng và tình trạng chất lượng |
| Phân quyền admin/user và quyền theo kho | Giữ phạm vi kho, bổ sung quyền nghiệp vụ |
| SharedPreferences lưu toàn bộ dữ liệu JSON | Dùng cho demo ban đầu; thay bằng cơ sở dữ liệu khi mở rộng |

Các khoảng trống chính: chưa có lô, hạn sử dụng, nhà sản xuất, nơi nhận, điều kiện bảo quản, theo dõi nhiệt độ, cách ly, thu hồi, hồ sơ quốc tế và lịch sử thao tác. Tài khoản hiện chứa mật khẩu trong dữ liệu ứng dụng, cần thay cơ chế này nếu chuyển sang hệ thống nhiều người dùng.

## 3. Phạm vi và mức ưu tiên

Nên hoàn thành một luồng nghiệp vụ có chiều sâu trước khi bổ sung tích hợp bên ngoài.

| Mức | Nhóm chức năng | Kết quả cần có |
|---|---|---|
| P0 — cốt lõi | Vaccine, lô, hạn dùng, nhập/xuất theo lô, FEFO, tồn và phân quyền | Demo được toàn bộ luồng từ tiếp nhận đến xuất hàng |
| P0 — cốt lõi | Cách ly, giải phóng hàng, kiểm tra lại khi Post, nhật ký | Không xuất nhầm lô hết hạn hoặc không đủ điều kiện |
| P1 — mở rộng | Hồ sơ nhập khẩu/xuất khẩu, đơn vị nhận, tệp chứng từ | Theo dõi lô hàng quốc tế và liên kết phiếu kho |
| P1 — mở rộng | Nhật ký nhiệt độ nhập tay, cảnh báo và xử lý sự cố | Minh họa bảo quản vaccine trong chuỗi lạnh |
| P2 — nâng cao | Chuyển kho, kiểm kê, thu hồi, hoàn trả, tiêu hủy | Hoàn chỉnh quản lý vòng đời hàng hóa |
| P2 — tích hợp | QR/barcode, cảm biến IoT, thông báo nền, đồng bộ máy chủ | Cải thiện vận hành sau khi nghiệp vụ ổn định |

Nếu thời gian đồ án hạn chế, chọn P0 và một luồng hồ sơ nhập khẩu đơn giản ở P1. Không cần triển khai quản lý lịch tiêm, bệnh nhân hoặc bệnh án vì khác phạm vi kho.

## 4. Các chức năng đề xuất

### 4.1. Danh mục vaccine và quy cách đóng gói

- Mã, tên thương mại, nhóm vaccine, nhà sản xuất, nước sản xuất, nhà cung cấp.
- Quy cách: số lọ/hộp, số liều/lọ; đơn vị tồn cơ sở và hệ số quy đổi rõ ràng.
- Khoảng nhiệt độ bảo quản, yêu cầu tránh đông băng và ghi chú theo tài liệu sản phẩm.
- Ngưỡng tồn tối thiểu theo vaccine–kho; ngưỡng cảnh báo gần hết hạn có thể cấu hình.

Đề xuất MVP quản lý **lọ nguyên, chưa mở** và lưu tồn bằng số nguyên lọ. Liều chỉ là số quy đổi tham khảo; không dùng số liều này để biểu diễn liều thực sự còn sử dụng được sau mở lọ. Nếu bổ sung quản lý sau mở/rã đông, cần lưu thời điểm và quy tắc riêng theo sản phẩm, không suy ra từ hạn dùng gốc.

### 4.2. Quản lý lô và hạn sử dụng

- Mỗi vaccine có nhiều lô: số lô, ngày sản xuất nếu có, ngày hết hạn, tài liệu liên quan.
- Một lô có thể tồn tại ở nhiều kho/vị trí và được nhập nhiều lần.
- Hiển thị hạn dùng theo từng dòng tồn; lọc còn hạn, gần hết hạn, hết hạn.
- Các mốc 30/60/90 ngày là gợi ý giao diện, cho phép cấu hình; đây không phải ngưỡng bắt buộc chung cho mọi vaccine.
- Tra cứu lịch sử nhập, xuất và đơn vị đã nhận theo số lô.

Số lô không nên duy nhất trên toàn hệ thống: dùng khóa nghiệp vụ kết hợp vaccine/nhà sản xuất/số lô. Khi nhập lại cùng lô, thông tin ngày sản xuất và hạn dùng phải nhất quán; không âm thầm sửa hạn dùng qua một phiếu nhập mới.

### 4.3. Tiếp nhận và nhập kho

1. Chọn nguồn nhập: mua trong nước, nhập khẩu, hoàn trả hoặc chuyển kho (tùy giai đoạn).
2. Chọn nhà cung cấp, kho/vị trí, ngày tiếp nhận và hồ sơ liên quan.
3. Nhập từng dòng vaccine–lô–số lượng–đơn giá; kiểm tra hạn dùng và tình trạng tiếp nhận.
4. Ghi nhận kiểm tra chứng từ, bao bì, thông tin nhiệt độ vận chuyển và kết quả kiểm tra.
5. Post phiếu để ghi nhận hàng vật lý. Hàng chưa được giải phóng ở trạng thái chờ kiểm tra/cách ly và chưa khả dụng để xuất.
6. Người có quyền chất lượng ghi nhận quyết định giải phóng hoặc từ chối, kèm lý do và thời điểm.

Cho phép ghi nhận hàng thực tế đã đến dù bị nghi ngờ chất lượng, nhưng phải đưa vào vùng cách ly. Không biến việc nhập được hàng thành việc hàng tự động được phép phân phối.

### 4.4. Xuất kho và gợi ý FEFO

FEFO (First Expiry, First Out) nghĩa là ưu tiên lô hết hạn sớm nhất trong số các lô đủ điều kiện.

1. Chọn đơn vị nhận, mục đích xuất, kho, ngày giao dự kiến và vaccine.
2. Hệ thống lọc lô đã giải phóng, còn hạn tại ngày giao dự kiến, đủ điều kiện bảo quản và còn khả dụng.
3. Sắp xếp theo hạn dùng tăng dần; nếu bằng nhau dùng ngày nhập và ID để có thứ tự ổn định.
4. Tự gợi ý phân bổ từ một hoặc nhiều lô; hiển thị lý do khi không đủ hàng hợp lệ.
5. Lưu nháp để giữ hàng ở từng lô; sửa/hủy nháp phải cập nhật hoặc giải phóng phần giữ.
6. Khi Post, kiểm tra lại quyền, hạn dùng, chất lượng và lượng khả dụng; sau đó ghi giảm tồn và giải phóng giữ hàng trong cùng giao dịch.

Cho phép thay lô gợi ý chỉ khi người dùng có quyền và nhập lý do; vẫn không được vượt kiểm tra điều kiện xuất. Có thể cấu hình yêu cầu hạn dùng còn lại tối thiểu của bên nhận.

Ví dụ: lô A còn 100 lọ, hết hạn 30/11/2026; lô B còn 200 lọ, hết hạn 31/01/2027. Cả hai đã giải phóng. Phiếu giao ngày 01/11/2026 cần 150 lọ sẽ được gợi ý 100 lọ A + 50 lọ B. Nếu A bị cách ly thì lấy 150 lọ B; nếu B chỉ còn 40 lọ khả dụng thì báo thiếu 110 lọ hợp lệ.

### 4.5. Tồn kho, cảnh báo và báo cáo

Mỗi dòng tồn cần có kho, vị trí, vaccine, số lô, hạn dùng, tình trạng chất lượng, số lượng thực tế, số lượng giữ và số lượng khả dụng.

- Tồn thực tế: lượng còn nằm trong kho, bao gồm cả hàng cách ly/hết hạn chưa xử lý.
- Khả dụng: tổng lượng còn hạn và đã giải phóng, trừ lượng đang giữ tương ứng.
- Hàng cách ly, bị từ chối, hết hạn hoặc thu hồi không được tính khả dụng.
- Không cộng các nhóm bị chặn một cách máy móc: một lượng hàng có thể vừa hết hạn vừa bị cách ly; tính theo điều kiện đủ xuất để tránh trừ hai lần.

Bổ sung dashboard gần hết hạn, đã hết hạn, dưới tồn tối thiểu, chờ kiểm tra, sự cố nhiệt độ chưa xử lý. MVP tính cảnh báo khi mở/làm mới app; chỉ hứa gửi cảnh báo khi app đóng sau khi có tác vụ nền hoặc dịch vụ máy chủ.

Báo cáo cần có nhập–xuất–tồn theo lô, danh sách gần hết hạn, hàng bị chặn, lịch sử phân phối theo lô và tổng hợp hồ sơ xuất nhập khẩu. Giai đoạn sau thêm báo cáo hao hụt/tiêu hủy và xuất CSV/PDF.

### 4.6. Hồ sơ nhập khẩu và xuất khẩu

Tạo module hồ sơ riêng thay vì thêm toàn bộ trường quốc tế vào mọi phiếu kho.

| Hồ sơ | Thông tin đề xuất |
|---|---|
| Chung | Mã hồ sơ, loại nhập khẩu/xuất khẩu, đối tác, nước đi/đến, ngày dự kiến/thực tế, người phụ trách |
| Vận chuyển | Đơn vị vận chuyển, vận đơn, điểm đi/đến, ghi chú điều kiện vận chuyển |
| Thương mại | Số hợp đồng, hóa đơn, tiền tệ, giá trị; chưa triển khai kế toán đa tiền tệ trong MVP |
| Chứng từ | Danh sách tài liệu theo checklist cấu hình, mã tham chiếu và tệp đính kèm |
| Liên kết | Vaccine/lô/số lượng dự kiến và các phiếu kho đã thực hiện |

Trạng thái theo dõi nội bộ gợi ý: nháp → đang bổ sung hồ sơ → sẵn sàng giao nhận → đang vận chuyển → đã nhận/giao → hoàn tất; có trạng thái hủy và trường ghi nhận tiến độ thông quan riêng. Trạng thái hồ sơ không tự tăng/giảm tồn.

Một hồ sơ có thể giao nhận nhiều đợt và liên kết nhiều phiếu. So sánh dự kiến với thực nhận/thực xuất, ghi nhận thiếu, thừa, hư hỏng. Những giấy tờ như hóa đơn, packing list, vận đơn hoặc chứng từ chất lượng là trường quản lý tham khảo; checklist thực tế phải được xác nhận riêng theo sản phẩm và thị trường áp dụng.

### 4.7. Chuỗi lạnh và xử lý sự cố

- Quản lý vị trí bảo quản: phòng lạnh, tủ lạnh hoặc tủ đông thuộc kho.
- Ghi nhiệt độ theo vị trí, thời điểm đo, người nhập, nguồn đo và thiết bị.
- Đối chiếu khoảng bảo quản của vaccine với cấu hình vị trí; không mặc định mọi vaccine đều dùng cùng một khoảng nhiệt độ.
- Khi có giá trị ngoài ngưỡng, tạo sự cố và chặn xuất phần hàng liên quan để chờ đánh giá; lưu diễn biến và quyết định của người có thẩm quyền.
- Nếu chưa có lịch sử di chuyển đủ chi tiết để xác định phạm vi ảnh hưởng, khoanh vùng thận trọng và yêu cầu rà soát; không tự kết luận vaccine còn sử dụng được hoặc phải tiêu hủy chỉ bằng một lần đo.

MVP dùng dữ liệu nhập tay và sự cố giả lập để demo. IoT là giai đoạn sau. Khung theo dõi nhiệt độ và tồn kho tham khảo hướng dẫn WHO/CDC ở cuối tài liệu; ngưỡng và cách xử lý cụ thể phải dựa trên tài liệu sản phẩm cùng quy trình được phê duyệt.

### 4.8. Thu hồi, hoàn trả và tiêu hủy

Giai đoạn mở rộng: tạo quyết định thu hồi theo lô; chặn xuất lô bị thu hồi; tra danh sách bên nhận, số lượng đã giao và số lượng thu hồi về. Hàng hoàn trả vào cách ly trước khi được đánh giá. Tiêu hủy phải có chứng từ, lý do, người duyệt và bút toán giảm tồn; không xóa lô để làm mất số dư.

## 5. Vai trò và kiểm soát thao tác

| Vai trò đề xuất | Quyền chính |
|---|---|
| Quản trị hệ thống | Quản lý người dùng, danh mục, cấu hình và quyền theo kho |
| Nhân viên kho | Lập phiếu, xem tồn và ghi nhận tiếp nhận trong kho được giao |
| Quản lý kho | Duyệt/Post theo quyền được cấp, kiểm kê và theo dõi báo cáo |
| Nhân sự chất lượng | Cách ly, giải phóng, xử lý sự cố và quyết định chất lượng |
| Nhân viên xuất nhập khẩu | Quản lý hồ sơ quốc tế và liên kết chứng từ |
| Người xem báo cáo | Chỉ xem dữ liệu trong phạm vi cho phép |

MVP có thể gộp thành ba vai trò admin, nhân viên kho và quản lý/chất lượng. Quyền Post và quyền giải phóng chất lượng nên là quyền riêng; quyền quản trị tài khoản không mặc nhiên thay thế thẩm quyền chất lượng. Kiểm tra quyền ở service/backend, không chỉ ẩn nút.

Nhật ký cần lưu người thao tác, hành động, đối tượng, thời điểm, dữ liệu thay đổi và lý do đối với: Post, đảo phiếu, cách ly/giải phóng, thay đổi hạn dùng, thay lô FEFO và thay quyền. Phiếu đã Post không sửa/xóa trực tiếp; sửa sai bằng chứng từ đảo hoặc điều chỉnh có liên kết.

## 6. Mô hình dữ liệu đề xuất

| Entity | Trường chính / trách nhiệm |
|---|---|
| Vaccine | Kế thừa Product; manufacturerId, countryOfOrigin, dosesPerVial, vialsPerPack, baseUnit, storageMin/Max |
| VaccineBatch | vaccineId, batchNo, manufacturedAt?, expiresAt, tài liệu tham chiếu |
| StorageLocation | warehouseId, code, loại vị trí, khoảng nhiệt độ hỗ trợ |
| StockSegment | batchId, locationId, nguồn tiếp nhận và tình trạng chất lượng; phân tách phần cùng lô có tình trạng khác nhau |
| ReceiptDetail / IssueDetail | batchId/stockSegmentId, số lượng lọ, đơn giá; lưu quy cách áp dụng tại lúc lập phiếu |
| StockMovement | Chiều tăng/giảm, segment, số lượng, loại nghiệp vụ, chứng từ nguồn, thời điểm hiệu lực/Post |
| StockReservation | issueId, segmentId, số lượng giữ, trạng thái; không ghi giảm tồn vật lý |
| Organization | Nhà cung cấp, nhà sản xuất, đơn vị nhận, đơn vị vận chuyển và quốc gia |
| TradeShipment / ShipmentLine | Hồ sơ quốc tế, danh sách hàng dự kiến, liên kết các dòng phiếu kho |
| Attachment | Hồ sơ/chứng từ sở hữu, tên tệp, đường dẫn lưu, loại, người tải và thời điểm |
| TemperatureReading / Excursion | Vị trí, thời gian, giá trị, thiết bị, phạm vi ảnh hưởng, trạng thái xử lý |
| QualityDecision / Recall | Quyết định chất lượng, đối tượng ảnh hưởng, người quyết định, lý do |
| AuditLog | Nhật ký nghiệp vụ không cho sửa từ giao diện thông thường |

Quan hệ chính: Vaccine 1–n Batch; Warehouse 1–n StorageLocation; Batch có nhiều StockSegment; phiếu có nhiều chi tiết; mỗi lần Post sinh các StockMovement tương ứng. Một Batch không mang một trạng thái chất lượng duy nhất cho tất cả kho: hai lần giao cùng lô có thể có điều kiện vận chuyển khác nhau.

Hạn dùng là thuộc tính lô, không đặt trên Vaccine. Trạng thái chất lượng như pending/released/quarantined/rejected được lưu riêng; trạng thái còn hạn/gần hết hạn/hết hạn tính từ ngày hiện tại. Thu hồi cấp lô có thể chặn toàn bộ các segment liên quan.

StockMovement là nguồn biến động; số dư là kết quả tổng hợp hoặc projection có thể dựng lại. Không duy trì hai nguồn sự thật độc lập giữa “tổng phiếu” và “bảng tồn”. Mỗi Post phải có khóa chống ghi nhận lặp.

## 7. Quy tắc nghiệp vụ quan trọng

1. Không xuất số lượng vượt khả dụng của từng segment/lô, kể cả khi tổng vaccine ở kho vẫn đủ.
2. Kiểm tra điều kiện xuất cả khi lưu nháp và khi Post; lô có thể hết hạn hoặc bị cách ly trong thời gian chờ.
3. Xác định ngày hết hạn theo quy ước nghiệp vụ thống nhất, múi giờ kho và định dạng nguồn; nếu nhãn chỉ có tháng/năm phải chuẩn hóa có ghi nhận quy tắc. Không dùng giờ UTC ngẫu nhiên để đổi ngày hạn dùng.
4. Đối với MVP, có thể chặn ngay từ ngày hết hạn theo chính sách nội bộ đã thống nhất; đây là lựa chọn thiết kế bảo thủ cần hiển thị rõ, không tuyên bố là quy định chung.
5. Hết hạn không tự làm giảm tồn thực tế; chỉ giảm khi có xuất trả/tiêu hủy/điều chỉnh hợp lệ.
6. Khi cách ly lô đang được giữ, chặn Post phiếu liên quan và yêu cầu phân bổ lại. Không cho phần giữ cũ tiếp tục hợp thức hóa việc xuất.
7. Hủy nháp giải phóng giữ hàng. MVP có thể giữ đến khi hủy; nếu thêm thời hạn giữ phải có tác vụ hết hạn và thông báo rõ.
8. Số lượng lọ là số nguyên dương; quy đổi hộp sang lọ theo hệ số đã lưu. Giá tiền dùng kiểu decimal hoặc số nguyên đơn vị tiền nhỏ nhất khi chuyển backend.
9. Chuyển kho phải có nơi đi, nơi đến và hàng đang vận chuyển; tránh cộng tồn nơi nhận ngay lúc xuất nơi đi nếu chưa nhận thực tế.
10. Khi có nhiều người dùng, kiểm tra tồn, ghi movement, cập nhật reservation và Post phải là một giao dịch nguyên tử; hai thiết bị không được cùng xuất phần hàng cuối.
11. Chốt quy tắc báo cáo cho chứng từ ghi lùi ngày: lưu cả ngày nghiệp vụ và thời điểm Post, chỉ người có quyền được ghi lùi; có thể khóa kỳ ở giai đoạn sau.

## 8. Các màn hình cần điều chỉnh

| Màn hình | Nội dung cải tiến |
|---|---|
| Dashboard | Hàng khả dụng, lô gần hết hạn, hàng cách ly, hồ sơ chờ nhận, sự cố chưa xử lý |
| Danh mục vaccine | Thông tin sản phẩm, quy cách, nhà sản xuất, điều kiện bảo quản |
| Danh sách lô | Tìm số lô, lọc hạn dùng, xem tồn từng vị trí và lịch sử |
| Chi tiết lô | Thông tin lô, chứng từ nhập/xuất, bên nhận, quyết định chất lượng |
| Phiếu nhập | Chọn/tạo lô, hạn dùng, vị trí tiếp nhận, kiểm tra tiếp nhận |
| Phiếu xuất | Đơn vị nhận, phân bổ FEFO, giữ hàng, lý do thay lô |
| Tồn kho | Bảng theo vị trí–lô, tách vật lý/khả dụng, lý do bị chặn |
| Hồ sơ xuất nhập khẩu | Danh sách, tiến độ, chi tiết lô hàng, tài liệu và các đợt giao nhận |
| Nhiệt độ và sự cố | Nhật ký, nhập đo, cảnh báo, khoanh vùng và xử lý |
| Báo cáo | Nhập–xuất–tồn theo lô, hạn dùng, phân phối, hàng bị chặn |
| Phân quyền | Quyền nghiệp vụ kết hợp phạm vi kho |

## 9. Hướng cải tiến kiến trúc project

### 9.1. Các file hiện tại cần thay đổi

| File / thư mục | Thay đổi dự kiến |
|---|---|
| `lib/domain/models/warehouse_app_data.dart` | Tách model theo nghiệp vụ; bổ sung batch, segment, movement, reservation và hồ sơ |
| `lib/domain/services/warehouse_inventory_service.dart` | Tính tồn theo lô/vị trí, lọc hàng đủ điều kiện, báo cáo và phân bổ FEFO |
| `lib/domain/services/warehouse_app_state.dart` | Giảm logic tập trung; chuyển các nghiệp vụ sang service chuyên biệt |
| `lib/domain/services/warehouse_permission_service.dart` | Bổ sung quyền Post, chất lượng, hồ sơ và xem báo cáo |
| `lib/features/documents/` | Nhập theo lô, phân bổ xuất, đơn vị nhận và kiểm tra khi Post |
| `lib/features/master_data/` | Danh mục vaccine, đối tác và vị trí bảo quản |
| `lib/features/inventory/`, `reports/`, `dashboard/` | Hiển thị số liệu theo lô và trạng thái |
| `lib/data/local/seed_data.dart` | Bộ dữ liệu vaccine giả lập, hạn dùng tương đối theo ngày demo |
| `lib/data/local/local_data_store.dart` | Thêm version dữ liệu/migration; thay lớp lưu trữ theo giai đoạn |
| `lib/features/app_shell.dart` | Bổ sung điều hướng lô, chất lượng, nhiệt độ, xuất nhập khẩu |
| `test/` | Mở rộng kiểm thử FEFO, hạn dùng, cách ly, giữ hàng và phân quyền |

Các module mới gợi ý: `features/batches`, `features/quality`, `features/temperature`, `features/trade_shipments`; các service tương ứng `BatchService`, `AllocationService`, `QualityService`, `TradeShipmentService`. Giữ UI gọi service thông qua state/repository, tránh đặt công thức tồn hoặc quyền trực tiếp trong widget.

### 9.2. Lưu trữ và triển khai

- **Demo một thiết bị:** có thể giữ SharedPreferences trong bước chuyển đổi ngắn; bổ sung schemaVersion và migration, không âm thầm reset dữ liệu cũ. Sau đó chuyển SQLite qua thư viện hỗ trợ các nền tảng mục tiêu, kiểm tra riêng cấu hình Web.
- **Nhiều người dùng:** Flutter → API backend → cơ sở dữ liệu quan hệ, ví dụ PostgreSQL. Backend thực thi quyền, giao dịch tồn kho, xác thực và nhật ký; tệp lưu trong kho tệp riêng có kiểm soát truy cập.
- Backend phải băm mật khẩu bằng cơ chế phù hợp; không đồng bộ trường mật khẩu rõ hiện có. Khi di chuyển dữ liệu thật cần luồng đặt lại mật khẩu.
- Đồ án có thể chọn một hướng lưu trữ nhất quán trước. Chưa cần hỗ trợ xuất kho offline đồng thời với online vì giải quyết xung đột tồn và giữ hàng phức tạp.

Dữ liệu cũ không có số lô/hạn dùng phải vào khu vực chờ bổ sung, chưa được coi là tồn đủ điều kiện xuất. Không tự tạo hạn dùng giả để vượt migration. Dữ liệu demo có thể được thay bằng bộ seed mới sau khi người dùng chủ động chọn reset.

## 10. Lộ trình triển khai gợi ý

Ước lượng dưới đây dành cho đồ án nhóm nhỏ, cần điều chỉnh theo thời lượng môn học và số người; mỗi giai đoạn kết thúc bằng một luồng demo chạy được.

| Giai đoạn | Đầu việc | Điều kiện hoàn thành |
|---|---|---|
| 1 — khoảng 1 tuần | Chốt phạm vi, model, đơn vị và quy tắc ngày; thiết kế màn hình | Thống nhất schema, quy tắc tồn và kịch bản demo |
| 2 — khoảng 1–2 tuần | Vaccine, lô, nhập theo lô, migration và dữ liệu mẫu | Nhập hai lô cùng vaccine, tồn được tách đúng |
| 3 — khoảng 1–2 tuần | FEFO, giữ hàng, kiểm tra khi Post, chất lượng và nhật ký | Chặn đúng lô hết hạn/cách ly và không xuất vượt |
| 4 — khoảng 1 tuần | Dashboard, cảnh báo và báo cáo theo lô | Số liệu chi tiết đối chiếu được với báo cáo |
| 5 — khoảng 1–2 tuần | Hồ sơ quốc tế đơn giản, nhật ký nhiệt độ | Hồ sơ liên kết nhiều đợt nhận; sự cố chặn được hàng |
| 6 — khoảng 1 tuần | Kiểm thử tích hợp, hoàn thiện giao diện và tài liệu demo | Chạy trọn các tiêu chí nghiệm thu bên dưới |

Nếu ít thời gian hơn, dừng ở giai đoạn 4 và ghi rõ hồ sơ quốc tế/chuỗi lạnh là hướng mở rộng. Nếu dùng backend từ đầu, dành thêm thời gian cho API, xác thực và kiểm thử giao dịch.

## 11. Tiêu chí nghiệm thu và kiểm thử

| Tình huống | Kết quả mong đợi |
|---|---|
| Hai lô cùng vaccine có hạn khác nhau | FEFO chọn lô gần hết hạn trước |
| Một lô không đủ số lượng | Chia sang lô hợp lệ tiếp theo, không vượt khả dụng |
| Lô hết hạn hoặc bị cách ly còn tồn vật lý | Vẫn thấy trong tồn, không được phân bổ xuất |
| Nháp giữ 30/100 lọ | Khả dụng còn 70; hủy nháp trả về 100 |
| Lô hợp lệ lúc lưu nhưng hết hạn trước Post | Post bị chặn, yêu cầu phân bổ lại |
| Cách ly một phần hàng cùng lô ở một vị trí | Chỉ phần bị ảnh hưởng bị chặn, trừ khi thu hồi toàn lô |
| Nhập khẩu hai đợt cho một hồ sơ | Hai phiếu độc lập; tổng thực nhận và phần còn chờ đúng |
| Sự cố nhiệt độ | Có nhật ký, phạm vi ảnh hưởng và hàng chờ đánh giá; không tự giải phóng |
| Người dùng ngoài phạm vi kho | Không xem hoặc thao tác được kể cả qua service/API |
| Hai yêu cầu xuất đồng thời phần hàng cuối | Nếu có backend, chỉ yêu cầu đủ tồn được thành công |
| Nhấn Post lặp / gửi lại request | Không tạo hai lần biến động |
| Lưu thất bại giữa chừng | Không tồn tại phiếu đã Post nhưng thiếu movement hoặc giữ hàng chưa giải phóng |
| Qua ngày mới, đúng ngày hết hạn | Trạng thái và khả dụng cập nhật theo quy tắc ngày đã chốt |
| Dữ liệu cũ thiếu lô/hạn dùng | Migration giữ dữ liệu và chặn xuất cho đến khi được bổ sung |

Ưu tiên unit test cho FEFO, tồn, chuyển trạng thái, ngày và quyền; widget test cho nhập lô/cảnh báo; integration test cho luồng nhập → giải phóng → giữ hàng → xuất → báo cáo. Chỉ thêm kiểm thử cạnh tranh thực tế khi có backend nhiều người dùng.

## 12. Kịch bản trình bày đề tài

1. Đăng nhập quản trị, tạo vaccine mẫu và quy cách lọ/hộp.
2. Lập hồ sơ nhập khẩu mẫu và nhận hàng vào hai lô có hạn khác nhau.
3. Mở tồn kho: hàng mới nhận đang chờ kiểm tra, chưa khả dụng.
4. Giải phóng chất lượng, tạo phiếu xuất và xem gợi ý FEFO tự chia lô.
5. Lưu nháp để minh họa hàng đang giữ; mở báo cáo đối chiếu số lượng.
6. Giả lập sự cố ở vị trí có một phần hàng; Post bị chặn và yêu cầu phân bổ lại.
7. Xuất từ phần hàng hợp lệ, xem truy vết đơn vị nhận theo lô và nhật ký thao tác.

Giá trị nổi bật của đề tài: **quản lý vaccine ở cấp lô, kiểm soát điều kiện được xuất và truy xuất lịch sử**, thay vì chỉ đổi tên sản phẩm và thêm trường hạn sử dụng.

## 13. Nguồn tham khảo và giới hạn áp dụng

Các lựa chọn kiến trúc, mức ưu tiên, schema và lộ trình trong tài liệu là đề xuất cho project. Những nguyên tắc về FEFO, theo dõi hạn dùng, quản lý tồn và giám sát nhiệt độ được tham khảo từ:

1. [WHO — Hướng dẫn và công cụ chuỗi cung ứng tiêm chủng](https://www.who.int/teams/immunization-vaccines-and-biologicals/essential-programme-on-immunization/supply-chain/guidanceandtools): tài liệu quản lý tồn và theo dõi nhiệt độ.
2. [WHO — How to monitor temperatures in the vaccine supply chain](https://www.who.int/publications/i/item/WHO-IVB-15.04): nền tảng tham khảo cho nhật ký nhiệt độ và thiết bị giám sát.
3. [WHO — Warehouse and Stock Management](https://emanual.who.int/p17new/s09/Pages/9-3-4-Warehouse-and-Stock-Management.aspx): nguyên tắc FEFO cho hàng có hạn dùng.
4. [CDC — Vaccine Storage and Handling](https://www.cdc.gov/pinkbook/hcp/table-of-contents/chapter-5-vaccine-storage-and-handling.html): quản lý tồn, luân chuyển hàng, kiểm tra tiếp nhận và bảo quản.

Tài liệu là thiết kế phần mềm phục vụ đồ án, không xác nhận đáp ứng đầy đủ tiêu chuẩn vận hành kho vaccine hoặc thủ tục xuất nhập khẩu. Trước khi dùng thực tế cần xác nhận yêu cầu theo từng sản phẩm, thị trường và quy trình của đơn vị; bổ sung đánh giá chuyên môn và quy định hiện hành tương ứng.
