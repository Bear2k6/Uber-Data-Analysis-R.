# Kịch bản demo — khoảng 6 phút 30 giây

## Chuẩn bị trước khi trình bày

Từ thư mục có `Main.R`, chạy `Rscript --vanilla tests/run_all_tests.R`. Khởi động Shiny bằng lệnh trong README; không chạy pipeline trong lúc demo. Mở trang Tổng quan, ngôn ngữ VI. Đặt lại bộ lọc các trang; tại Trợ lý chọn “Toàn bộ dữ liệu”, bật bộ lọc hiện tại hoặc tắt để dùng toàn bộ. Bật mạng nếu cần nền bản đồ; trợ lý dùng chế độ cục bộ. Không cần API key.

## 0:00–0:40 — Tổng quan dữ liệu

**Thao tác:** Mở Tổng quan.

“Đồ án phân tích hơn 4,5 triệu bản ghi lượt đón Uber tại New York từ tháng 4 đến tháng 9 năm 2014. Dữ liệu có thời gian, tọa độ và mã Base. Em gọi đây là bản ghi lượt đón vì không có mã chuyến để xác minh hành trình duy nhất. Các con số trên màn hình được tính từ bảng tổng hợp, không nhập cứng vào giao diện.”

Chỉ tổng 4.534.327 và 183 ngày. Không nói dữ liệu này mô tả Uber hiện nay.

## 0:40–1:25 — Mô hình nhu cầu

**Thao tác:** Mở Mô hình nhu cầu, giữ khoảng ngày đầy đủ; chọn tháng 9, Ngày thường, Thứ 5, 17:00, B02617.

“Các bộ lọc lấy giao đồng thời. Lựa chọn này có 4.170 lượt trên bốn ngày phù hợp. Bộ kiểm thử đã đối chiếu con số này với dữ liệu tháng 9 gốc. Trung bình ngày dùng số ngày phù hợp làm mẫu số, không đếm số dòng của bảng tổng hợp.”

Đổi EN rồi về VI, chỉ số giữ nguyên. Đặt lại trước khi rời trang.

## 1:25–2:00 — Địa lý và điểm tập trung

**Thao tác:** Phân bố địa lý → Mật độ lưới; chọn tháng 9, sau đó đặt lại.

“Phần địa lý dùng các lượt nằm trong khung tọa độ được công bố. Vòng tròn lớn hơn tương ứng nhiều lượt hơn. Chọn số ô đứng đầu chỉ đổi phần hiển thị; tỷ trọng vẫn tính trên toàn bộ dữ liệu đang lọc. Ô lưới không phải tên khu phố và không có diện tích chính xác một kilomet vuông.”

Nếu nền bản đồ không tải: giải thích nền cần internet; dùng bảng tọa độ và số lượt bên dưới, không mô tả đây là lỗi tính toán.

## 2:00–2:30 — Base

**Thao tác:** Phân tích Base → chọn B02617, giữ các bộ lọc thời gian Tất cả.

“B02617 có nhiều lượt nhất trong dữ liệu này. Khi chọn một Base, biểu đồ giữ các Base khác để đối chiếu, và tỷ trọng dùng cùng điều kiện lịch. Đây là tỷ trọng của dữ liệu quan sát, không phải thị phần toàn ngành hay năng suất tài xế.”

## 2:30–3:25 — Dự báo

**Thao tác:** Dự báo → chỉ bảng bốn mô hình; chọn XGBoost trên biểu đồ, sau đó xem mức quan trọng.

“Em dự báo trước một giờ, dùng thông tin có trước giờ dự báo. Tập huấn luyện kết thúc tháng 8, tháng 9 gồm 720 giờ dùng kiểm tra. XGBoost đạt RMSE khoảng 205,74, thấp nhất ở thí nghiệm này. Cơ sở theo tuần vẫn tốt hơn cây đơn, nên không giả định mô hình phức tạp luôn tốt hơn.”

“MAE và RMSE càng thấp càng tốt, R² càng cao càng tốt. Hai mô hình tổ hợp có 15 biến, cây gốc có 5 biến; vì vậy đây là so sánh hệ thống dự báo, chưa tách riêng ảnh hưởng thuật toán. Mức quan trọng không chứng minh quan hệ nhân quả.”

## 3:25–4:05 — Bất thường

**Thao tác:** Bất thường → để bộ lọc mặc định; chỉ số 11 và đường quan sát/kỳ vọng.

“Bất thường là quan sát khác đáng chú ý so với dự báo, không nhất thiết là lỗi hoặc một sự kiện. Tuần đầu tháng 9 dùng hiệu chỉnh phần dư, 552 giờ sau đó được chấm điểm; 11 giờ vượt ngưỡng. Giờ có điểm cao nhất được điền 0 do không có bản ghi, nên em cảnh báo về độ bao phủ thay vì kết luận nhu cầu sụt giảm.”

## 4:05–4:40 — Phân cụm không giám sát

**Thao tác:** Phân bố địa lý → Cụm AI.

“Khác với lưới cố định, DBSCAN nhóm các ô liên thông theo mật độ. Thuật toán dùng trọng số lượt đón, bán kính 1,5 kilomet và ngưỡng 20.000 lượt trong lân cận. Có ba cụm và phần nhiễu. Không đặt tên khu phố khi chưa có đối chiếu địa lý. Lọc tháng chỉ đổi số lượt, không huấn luyện lại nhãn cụm.”

## 4:40–5:45 — Hai câu hỏi cho Trợ lý dữ liệu

**Thao tác:** Trợ lý dữ liệu → chọn Toàn bộ dữ liệu, giữ chế độ cục bộ.

1. Gõ **“Dataset có bao nhiêu bản ghi?”** → kiểm tra **4.534.327** và nguồn `dashboard_time_cube.csv`.
2. Gõ **“Mô hình dự báo nào tốt nhất?”** → kiểm tra **XGBoost**, phạm vi tháng 9 và nguồn `model_metrics.csv`.

“Câu hỏi được ánh xạ sang truy vấn R cho phép. R tính số liệu từ kết quả đã lưu, rồi mẫu câu trình bày phạm vi và nguồn. Không cần kết nối mô hình ngôn ngữ. Nếu hỏi nguyên nhân thời tiết hoặc sự kiện, trợ lý phải nói dữ liệu không đủ để xác định.”

Nếu còn thời gian: “Base nào nhiều chuyến nhất?” rồi “Còn hạng hai?” → B02598. Đây là ví dụ hỏi tiếp có giới hạn, không phải trí nhớ hội thoại tổng quát.

## 5:45–6:30 — Phương pháp và kết thúc

**Thao tác:** Phương pháp, lướt qua các mục 01–09.

“Điểm mạnh của đồ án là có chuỗi xử lý và kiểm chứng thống nhất: dữ liệu gốc, làm sạch, tổng hợp, học máy và giao diện cùng sử dụng nguồn kết quả rõ ràng. Shiny là công cụ giao diện; phần học máy nằm ở dự báo và phân cụm, còn phát hiện bất thường kết hợp dự báo với thống kê phần dư.”

“Giới hạn chính là dữ liệu năm 2014, chỉ một tháng kiểm tra, thiếu biến thời tiết, giao thông, sự kiện, giá và điểm đến. Do đó kết quả phục vụ phân tích lịch sử và học thuật, chưa chứng minh hiệu quả vận hành hiện tại.”

## Khi giảng viên hỏi ngoài kịch bản

Dùng `DEFENSE_QA.md` để trả lời ngắn. Nếu hỏi con số ngoài phạm vi đã kiểm chứng, mở bảng nguồn hoặc nói cần kiểm tra; không đoán. Nếu hỏi báo cáo Word, nêu rõ file gốc còn rỗng và các tài liệu Markdown chưa thay thế mẫu báo cáo của trường.
