# Phân công phát triển VaxStock trong 1,5 tuần

Tài liệu gốc: [Đề xuất cải tiến quản lý kho vaccine](vaccine-warehouse-improvement-proposal.md).

## Phạm vi và cách tính thời gian

Kế hoạch dùng **10 ngày lịch liên tiếp**, tương đương khoảng 1,5 tuần; nhóm cần thống nhất ngày nghỉ và số giờ thực tế trước khi bắt đầu. D1 là ngày khởi động, không gắn ngày cố định. D1–D8 phát triển và tích hợp, D9 kiểm thử/sửa lỗi, D10 dự phòng và demo. Nếu chỉ làm các ngày trong tuần, khối lượng phải giảm theo số ngày làm việc thực tế.

**Mục tiêu bàn giao:** Flutter gọi API ASP.NET Core để đăng nhập, quản lý vaccine/lô, nhập kho, giải phóng chất lượng, xuất theo FEFO, xem tồn và cảnh báo hạn dùng. Có một màn hình hồ sơ xuất nhập khẩu cơ bản liên kết phiếu kho.

**Stack đề xuất:** ASP.NET Core Web API, EF Core, SQL Server, JWT; Flutter tiếp tục dùng giao diện hiện có. Chọn phiên bản SDK tương thích với môi trường nhóm trong D1 và khóa phiên bản chung. BE là nguồn dữ liệu chính; Flutter thay các thao tác trên dữ liệu SharedPreferences bằng gọi API trong phạm vi đã chuyển đổi.

**Giới hạn để kịp thời gian:**

- Ba nhóm quyền: admin, nhân viên kho, quản lý/chất lượng; vẫn kiểm tra quyền theo kho tại API.
- Quản lý lọ nguyên, số lượng nguyên; mỗi lô có thể ở nhiều kho. MVP phân biệt phần hàng theo lần tiếp nhận để cách ly một đợt nhận mà không khóa nhầm toàn bộ lô.
- Hồ sơ quốc tế chỉ có mã, loại nhập/xuất khẩu, đối tác, nước đi/đến, ngày, trạng thái và liên kết phiếu. Chưa tải tệp, khai hải quan hay kế toán đa tiền tệ.
- Cảnh báo hạn dùng tính khi gọi API/làm mới màn hình; chưa thông báo nền.
- Chưa làm IoT, chuyển kho, kiểm kê, hoàn trả, thu hồi đầy đủ, tiêu hủy và quản lý sau mở lọ.
- Nhập nhiệt độ và xử lý sự cố là việc bổ sung nếu còn thời gian, không thuộc tiêu chí bắt buộc của đợt này.

## Bảng 1 — Nhóm 4 người

Phân bổ **2 BE + 2 Flutter**. TV1 sở hữu nền tảng, danh mục và nhập kho; TV2 sở hữu xuất kho, tồn và chất lượng. Hai người BE thống nhất schema trước khi code và chỉ một người tạo migration tại một thời điểm.

| Thành viên | Vai trò / phần sở hữu | D1–D2: nền tảng | D3–D5: nghiệp vụ chính | D6–D8: tích hợp và hoàn thiện | D9–D10: kiểm thử và bàn giao | Sản phẩm / tiêu chí hoàn thành |
|---|---|---|---|---|---|---|
| **TV1** | **BE 1 — API nền tảng, danh mục, nhập kho** | Khởi tạo solution ASP.NET Core, EF Core/SQL Server; thống nhất schema cùng TV2; JWT, băm mật khẩu, seed ba vai trò; phân quyền theo kho; công bố hợp đồng API | API kho/vaccine/đối tác/lô; tạo và sửa phiếu nhập nháp; Post nhập tạo biến động và phần hàng chờ kiểm tra; kiểm tra số lô/hạn dùng | API hồ sơ xuất nhập khẩu tối giản và liên kết phiếu; seed demo; chủ trì migration và hướng dẫn chạy BE; hỗ trợ TV3 nối API | Kiểm thử auth/quyền và nhập kho; sửa lỗi tích hợp; chuẩn bị database demo, cấu hình mẫu và API collection | Đăng nhập trả token; người ngoài kho bị chặn; nhập hai lô được; Post nhập không làm hàng tự khả dụng; hồ sơ liên kết được phiếu |
| **TV2** | **BE 2 — Tồn, chất lượng, FEFO và xuất kho** | Thiết kế cùng TV1 các bảng movement, reservation, phần hàng tiếp nhận; chốt quy tắc ngày và trạng thái; định nghĩa API tồn/FEFO/quality | API tồn theo kho–lô; quyết định giải phóng/cách ly; phân bổ FEFO; lưu/sửa/hủy nháp xuất và giữ hàng; Post xuất nguyên tử, chống lặp, kiểm tra lại tồn/hạn/quyền | API cảnh báo và báo cáo XNT cơ bản theo lô; nhật ký cho Post/quyết định chất lượng; xử lý giữ hàng bị cách ly; phối hợp TV4 kiểm tra số liệu | Kiểm thử FEFO, hạn dùng, cách ly, hủy giữ hàng và hai request tranh tồn; sửa lỗi; đối chiếu tồn với movements | Không xuất lô bị chặn/hết hạn; nháp giữ đúng; Post lặp không trừ hai lần; hai request không xuất vượt; báo cáo khớp tồn |
| **TV3** | **Flutter 1 — Auth, danh mục, nhập và hồ sơ** | Kiểm tra app hiện tại; tạo API client, cấu hình base URL, token và xử lý 401; thống nhất DTO với TV1; dựng login bằng API | Chuyển kho/vaccine/đối tác sang API; màn hình danh sách/chi tiết lô; sửa form nhập có số lô, hạn dùng, số lượng lọ; tích hợp nháp/Post nhập | Màn hình hồ sơ quốc tế tối giản, liên kết phiếu; hoàn thiện validation/loading/error; bỏ đường ghi dữ liệu local trong các module đã chuyển; nối API thật | Kiểm tra luồng đăng nhập → tạo vaccine/lô → nhập → hồ sơ; sửa lỗi UI; build Flutter trên nền tảng demo đã chọn | Thao tác được trên API thật; mở lại màn hình vẫn thấy dữ liệu BE; lỗi quyền/validation hiển thị rõ; không tạo dữ liệu local song song |
| **TV4** | **Flutter 2 — Tồn, xuất, chất lượng và báo cáo** | Chốt UI với TV3, tận dụng shell và bảng hiện có; dựng DTO/màn hình bằng dữ liệu mock đúng hợp đồng API; không sửa API client chung nếu chưa thống nhất | Tích hợp tồn theo lô và cảnh báo hạn dùng; màn hình chờ kiểm tra/giải phóng/cách ly; form xuất chọn nơi nhận, xem và chấp nhận phân bổ FEFO | Tích hợp lưu/sửa/hủy/Post xuất; báo cáo XNT cơ bản và dashboard; hiện lý do bị chặn; làm mới tồn sau thao tác; phối hợp TV2 kiểm tra giữ hàng | Chạy demo đầu cuối, kiểm tra giao diện nhỏ/lớn; sửa lỗi; chuẩn bị kịch bản và ảnh minh họa | Demo nhập → giải phóng → xuất FEFO → báo cáo chạy được; lô cách ly/hết hạn không chọn xuất; số dư cập nhật sau Post |

**Phụ thuộc chính:** TV3 cần API nền tảng của TV1 từ D2; TV4 cần API tồn/chất lượng của TV2 từ D4 và xuất từ D5. Trước khi API xong, Flutter dùng mock theo DTO đã chốt, sau đó thay bằng API thật. Tích hợp sớm từng module, không chờ D8 mới ghép.

## Bảng 2 — Nhóm 3 người

Phân bổ **1 BE chính + 1 Flutter chính + 1 người làm BE/Flutter theo module**. Giảm phạm vi: giữ dashboard và báo cáo ở mức bảng tổng hợp, tái sử dụng giao diện hiện có, hồ sơ quốc tế chỉ một form và danh sách. TV3 nhận trọn module chất lượng và hồ sơ để giảm tải cho hai người còn lại.

| Thành viên | Vai trò / phần sở hữu | D1–D2: nền tảng | D3–D5: nghiệp vụ chính | D6–D8: tích hợp và hoàn thiện | D9–D10: kiểm thử và bàn giao | Sản phẩm / tiêu chí hoàn thành |
|---|---|---|---|---|---|---|
| **TV1** | **BE chính — Nền tảng và giao dịch kho** | Tạo ASP.NET Core/EF Core/SQL Server, JWT và seed; cùng TV3 chốt schema/API; quyền theo kho; giữ quyền sở hữu migration | API vaccine/kho/đối tác/lô với trường tối thiểu; nhập nháp/Post; movement, tồn theo lô, FEFO, giữ hàng và nháp/Post xuất; tái sử dụng service tính điều kiện đủ xuất | Hoàn thiện giao dịch nguyên tử và chống Post lặp; kiểm tra lại chất lượng/hạn dùng; API cảnh báo và báo cáo bảng cơ bản; hỗ trợ TV2 nối API | Kiểm thử trọng yếu tồn/FEFO/cạnh tranh/Post lặp; sửa lỗi; bàn giao cấu hình, seed và API collection | API chạy toàn bộ vòng nhập–xuất; không vượt tồn hoặc xuất hàng bị chặn; dữ liệu tồn khớp giao dịch |
| **TV2** | **Flutter chính — Luồng kho đầu cuối** | API client, token, auth, base URL; dùng lại shell và danh mục hiện có; chốt DTO cùng TV1, dựng form bằng mock | Nối login và danh mục tối giản; danh sách lô; form nhập theo lô; màn hình tồn; form xuất và hiển thị phân bổ FEFO; tích hợp từng API khi sẵn sàng | Hoàn thiện nháp/hủy/Post, cảnh báo, bảng báo cáo đơn giản; xử lý loading/error/401; nhận module từ TV3 vào shell; loại bỏ ghi local ở luồng đã chuyển | Chạy luồng đầu cuối, sửa UI, build và chuẩn bị demo cùng nhóm | Flutter gọi API thật xuyên suốt, giữ/giải phóng tồn hiển thị đúng; lỗi nghiệp vụ được giải thích trên giao diện |
| **TV3** | **BE + Flutter — Chất lượng, hồ sơ và tích hợp** | Cùng TV1 thiết kế trạng thái chất lượng/phần hàng và DTO hồ sơ; thiết lập API collection và checklist demo; thống nhất ranh giới file | Làm API + UI danh sách chờ kiểm tra, giải phóng/cách ly; nhật ký quyết định; kiểm tra quyền quản lý/chất lượng; hỗ trợ TV1 kiểm thử điều kiện đủ xuất | Làm API + UI hồ sơ quốc tế tối giản, liên kết phiếu; seed các tình huống hết hạn/cách ly; chủ trì smoke test và đối chiếu báo cáo; hỗ trợ lỗi tích hợp | Chạy checklist nghiệm thu, sửa lỗi module sở hữu; viết hướng dẫn chạy, kịch bản demo và danh sách giới hạn | Nhập hàng xong phải giải phóng mới xuất được; quyết định có người/lý do/thời điểm; hồ sơ liên kết được phiếu; một bản chạy tích hợp có hướng dẫn |

**Lưu ý khối lượng:** TV1 là điểm nghẽn trong phương án 3 người. Ưu tiên hoàn thành nhập–tồn–xuất trước. Nếu đến cuối D5 chưa có luồng Post nhập → giải phóng → xuất chạy được qua API, hoãn hồ sơ quốc tế sang sau D10; TV3 hỗ trợ TV1 kiểm thử và hoàn thiện giao dịch, TV2 tập trung nối luồng chính. Không cắt kiểm tra hạn dùng, chất lượng, quyền hoặc chống xuất vượt để giữ chức năng phụ.

## Mốc chung và phối hợp

| Mốc | Đầu ra bắt buộc |
|---|---|
| Cuối D1 | Chốt schema, đơn vị lọ, trạng thái, quy tắc ngày, người sở hữu file và nền tảng demo |
| Cuối D2 | BE chạy được, login và kiểm tra quyền; OpenAPI/DTO thống nhất; Flutter gọi được một API thật |
| Cuối D4 | Nhập theo lô và xem tồn từ BE; nhập mới vẫn chờ giải phóng chất lượng |
| Cuối D5 | Luồng nghiệp vụ cốt lõi chạy qua API: nhập → giải phóng → phân bổ xuất → Post |
| Cuối D7 | Flutter chạy được luồng chính trên dữ liệu BE; giữ hàng, hủy nháp và chặn lô hoạt động |
| Cuối D8 | Đóng phạm vi thêm tính năng; ghép bản tích hợp với hồ sơ/báo cáo theo mức hoàn thành |
| D9 | Kiểm thử đầu cuối và xử lý lỗi ảnh hưởng nghiệp vụ |
| D10 | Dự phòng sửa lỗi, build, kiểm tra máy demo và diễn tập |

- Mỗi ngày đồng bộ ngắn: đã xong gì, API nào thay đổi, đang bị chặn ở đâu. Cuối ngày đưa thay đổi đã chạy được vào nhánh tích hợp.
- Mỗi task giao kèm route/DTO, ví dụ request/response, quyền truy cập và lỗi mong đợi. Flutter không tự suy đoán công thức tồn.
- Dùng chung quy ước JSON, ngày giờ, phân trang/tìm kiếm và lỗi `{ code, message, fieldErrors }`; không trả mật khẩu trong response.
- Khóa ranh giới chỉnh sửa: một người sở hữu migration; một người sở hữu API client; người thêm màn hình gửi yêu cầu cập nhật shell cho người sở hữu.
- Ghi chú API thay đổi ngay khi sửa. Trước khi bàn giao module phải thử ít nhất một trường hợp thành công và một lỗi nghiệp vụ bằng API thật.

## Checklist bàn giao cuối đợt

1. Source BE/Flutter, cấu hình mẫu không chứa bí mật, migration và dữ liệu seed chạy được từ máy khác.
2. Đăng nhập được ba nhóm quyền; tài khoản ngoài kho không truy cập được dữ liệu kho đó qua API.
3. Nhập hai lô cùng vaccine; hàng chờ kiểm tra chưa khả dụng; giải phóng/cách ly có nhật ký.
4. FEFO chọn đúng lô, chia nhiều lô khi cần; không xuất lô hết hạn/cách ly.
5. Phiếu nháp giữ đúng lượng hàng; hủy trả giữ; Post kiểm tra lại và không trừ tồn hai lần.
6. Có kiểm thử BE cho FEFO, hạn dùng, chất lượng, giữ hàng, quyền và Post đồng thời/lặp; có kiểm thử đầu cuối thủ công trên Flutter.
7. Tồn và báo cáo đơn giản đối chiếu được với phiếu đã Post; lô hết hạn vẫn còn tồn vật lý nếu chưa xử lý.
8. Hồ sơ xuất nhập khẩu tối giản có liên kết phiếu nếu không kích hoạt phương án giảm phạm vi; phần hoãn được ghi rõ.
9. Có hướng dẫn chạy, tài khoản demo, kịch bản 5–7 phút và danh sách chức năng chưa triển khai.

**Khuyến nghị:** chọn phương án 4 người nếu muốn hoàn thiện hồ sơ quốc tế trong cùng đợt. Phương án 3 người phù hợp khi ưu tiên chiều sâu nghiệp vụ lô/hạn dùng và chấp nhận cắt chức năng phụ theo mốc D5.
