# Tóm tắt đồ án: Phân tích dữ liệu Uber NYC bằng R và Shiny

Tài liệu phục vụ thuyết trình và bảo vệ; số liệu đối chiếu với các CSV đã tái tạo bởi `Main.R`. Bản Markdown này không thay thế file Word theo mẫu của trường. Báo cáo Word hiện có trong `report/` vẫn rỗng.

## 1. Mục tiêu, dữ liệu và phạm vi

Đồ án trả lời ba nhóm câu hỏi: hoạt động đón khách thay đổi theo thời gian và Base như thế nào; các lượt đón tập trung ở đâu; có thể dự báo nhu cầu theo giờ và nhận diện quan sát khác kỳ vọng hay không. Giao diện Shiny cho phép kiểm chứng kết quả bằng bộ lọc và đặt câu hỏi Việt/Anh cho trợ lý dữ liệu.

Đầu vào gồm sáu CSV từ tháng 4 đến tháng 9/2014, tổng cộng **4.534.327 bản ghi**, **183 ngày** và **5 Base**. Nguồn công bố là [FiveThirtyEight, dữ liệu NYC TLC qua FOIL](https://github.com/fivethirtyeight/uber-tlc-foil-response). Mỗi dòng có `Date/Time`, `Lat`, `Lon`, `Base`. Base là mã đơn vị TLC gắn với lượt đón; không phải mã tài xế, loại xe hay khu phố. Tên “Dispatch Base” được dùng theo quy ước của đồ án.

Đơn vị phân tích cơ bản là **bản ghi lượt đón**, không khẳng định đó là hành trình duy nhất. Không có mã chuyến độc lập để xác thực. Dữ liệu không bao gồm điểm đến, quãng đường, thời lượng, giá cước, tài xế, nguồn cung, thời tiết, sự kiện hay giao thông. Vì vậy không đo doanh thu, năng suất tài xế, nhu cầu chưa đáp ứng hoặc quan hệ nhân quả. Đây là bối cảnh năm 2014, không đại diện cho Uber hiện nay.

## 2. Làm sạch và tạo dữ liệu phân tích

Pipeline kiểm tra sự tồn tại của sáu tệp, tên và kiểu cột, giá trị thiếu, tọa độ, bản ghi trùng và khả năng chuyển đổi thời gian. Dữ liệu hiện tại không có giá trị thiếu trong bốn cột bắt buộc, không lỗi chuyển đổi thời gian và không tọa độ ngoài miền hợp lệ toàn cầu. **82.581 dòng trùng** được báo cáo và giữ lại: trùng thời gian, vị trí, Base chưa đủ chứng minh cùng một lượt đón. Đây là lựa chọn minh bạch, không phải bỏ qua chất lượng dữ liệu.

Từ thời gian tạo Hour, Day, Date, Month, Weekday và DayType. Thành phần giờ/ngày giữ theo dữ liệu gốc, không chuyển múi giờ. Nhãn lịch cố định tránh phụ thuộc ngôn ngữ máy tính. Với mô hình, UTC chỉ là quy ước lưu nhãn thời gian. Chuỗi giờ được hoàn chỉnh bằng 0 ở giờ không có bản ghi; cần phân biệt “không ghi nhận” với “thực sự không có nhu cầu”.

Phân tích địa lý lọc tọa độ hợp lệ rồi áp dụng hình chữ nhật: vĩ độ 40,5774–40,9176; kinh độ −74,1500–−73,7004. Có **4.462.626 lượt đón**, tương đương **98,42%** tọa độ hợp lệ trong khung này. Đây không phải phép kiểm tra địa giới hành chính. Lưới dùng bước 0,01 độ; diện tích thực tế phụ thuộc vĩ độ và không chính xác bằng 1 km².

Kết quả làm sạch và EDA nằm trong `output/results/`; chín hình phục vụ báo cáo nằm trong `output/figures/`. File sạch lớn chỉ dùng trong pipeline. Tệp mẫu 50.000 vị trí dùng cho hình mật độ trong báo cáo, không dùng để tính tổng chính thức hoặc khởi động dashboard.

## 3. Kết quả khám phá chính

Toàn giai đoạn có 4.534.327 lượt đón. Tổng theo khung giờ lớn nhất ở **17:00**, với **336.190 lượt**. Đây là tổng của cùng giờ qua nhiều ngày, không phải 336.190 lượt trong một giờ cụ thể. Tháng 9 có **1.028.136 lượt** và là tháng cao nhất; thứ Năm có tổng cao nhất; ngày **13/9/2014** có nhiều lượt nhất.

Base **B02617** đứng đầu với **1.458.853 lượt**, khoảng **32,17%** dữ liệu; **B02598** đứng thứ hai với **1.393.113 lượt**, khoảng **30,72%**. Các tỷ trọng chỉ so sánh năm Base được quan sát. Không diễn giải chúng là thị phần toàn ngành hoặc hiệu quả kinh doanh.

Ngày thường trung bình khoảng **25.939 lượt/ngày**, cuối tuần khoảng **21.852**, chênh khoảng **18,7%**. So sánh trung bình có ý nghĩa hơn chỉ so sánh tổng vì hai nhóm có số ngày khác nhau. Trong dashboard, trung bình được tính từ số liệu chưa làm tròn và bao gồm ngày hợp lệ có 0 lượt trong phạm vi được chọn.

Một phép kiểm chứng quan trọng: tháng 9 + ngày thường + thứ Năm + 17:00 + B02617 cho **4.170 lượt**, trên **4 ngày** phù hợp, tức 1.042,5 lượt/ngày. Kiểm thử đối chiếu trực tiếp CSV tháng 9, không chỉ so sánh hai bảng tổng hợp từ cùng một công thức.

## 4. Dự báo có giám sát

Mục tiêu là tổng lượt đón trên toàn bộ Base theo từng giờ. Chuỗi gồm **4.392 giờ**. Đánh giá dự báo trước một giờ theo cách cuốn chiếu: tại giờ t giả định đã biết số liệu đến t−1. Các quan sát đầu tháng 9 được phép tạo biến trễ cho giờ sau đó. Đây không phải dự báo cả tháng từ một thời điểm duy nhất.

Bảy ngày đầu tạo lịch sử cho độ trễ tuần. Huấn luyện cuối từ **8/4 đến 31/8**, gồm **3.504 giờ**; kiểm tra từ **1/9 đến 30/9**, gồm **720 giờ**. Khi chọn mô hình tổ hợp, dùng 8/4–31/7 để huấn luyện ứng viên và tháng 8 làm tập xác thực. Chọn tham số xong mới huấn luyện lại đến 31/8. Không dùng nhãn tháng 9 để chọn cấu hình hoặc dừng sớm.

Bốn hệ thống được so sánh:

1. Seasonal Naive sao chép số lượt của giờ tương ứng tuần trước, tức t−168.
2. Cây hồi quy dùng Hour, Weekday, DayIndex, lag_24, lag_168; cấu hình gốc được giữ để có mốc so sánh ổn định.
3. Rừng ngẫu nhiên dùng 400 cây, giảm độ nhạy của một cây đơn lẻ bằng tổ hợp; chọn tham số trên tháng 8.
4. XGBoost cộng dần cây để giảm sai số, với tốc độ học và dừng sớm trên tập xác thực.

Hai mô hình tổ hợp dùng cùng 15 đặc trưng: 6 biến lịch, 5 biến trễ và 4 thống kê cửa sổ quá khứ. Cửa sổ luôn kết thúc tại t−1. Cây gốc chỉ dùng 5 biến nên kết quả so sánh cả hệ thống dự báo, không tách riêng tác dụng của thuật toán. Seed là 42; tham số, phiên bản gói và thời gian chạy được lưu cùng kết quả.

| Mô hình | MAE | RMSE | MAPE | R² |
|---|---:|---:|---:|---:|
| Seasonal Naive | 223,32 | 349,19 | 16,28% | 0,804 |
| Cây hồi quy | 288,06 | 422,08 | 20,90% | 0,714 |
| Rừng ngẫu nhiên | 156,84 | 225,31 | 12,17% | 0,919 |
| XGBoost | 141,19 | **205,74** | 11,28% | **0,932** |

**XGBoost có RMSE thấp nhất trên tập kiểm tra này.** Mô hình cơ sở vẫn tốt hơn cây đơn. Không kết luận “AI luôn tốt hơn”. MAE dễ hiểu theo đơn vị lượt đón; RMSE phạt sai số lớn hơn; R² so sánh với trung bình tập kiểm tra. MAPE bỏ giờ có thực tế bằng 0. Mức quan trọng đặc trưng được chuẩn hóa riêng từng mô hình, không phải quan hệ nhân quả và không so trực tiếp giữa các định nghĩa khác nhau.

## 5. Phát hiện bất thường và phân cụm

Bất thường dùng phần dư quan sát trừ dự báo Rừng ngẫu nhiên. Chọn mô hình này theo RMSE xác thực tháng 8 giữa hai mô hình tổ hợp, không chọn bằng kết quả tháng 9. Tuần 1–7/9 hiệu chỉnh trung vị phần dư và MAD; 8–30/9 gồm **552 giờ** được chấm điểm. Điểm là trị tuyệt đối của 0,67448975 × (phần dư − trung vị tham chiếu) / MAD thô; ngưỡng lớn hơn **3,5**.

Có **11 giờ bất thường**, khoảng **1,99%** số giờ chấm điểm. Sai lệch dương lớn nhất ở 18:00 ngày 13/9, khoảng +952,49 lượt. Giờ điểm cao nhất là 23:00 ngày 30/9, vốn được điền 0 do không có bản ghi. Vì vậy cần cảnh báo về độ bao phủ. Bất thường không đồng nghĩa lỗi, sự kiện hay xác suất; không suy diễn nguyên nhân khi thiếu biến giải thích. Tuần hiệu chỉnh không được gắn nhãn “bình thường” giả tạo.

Phân cụm dùng DBSCAN có trọng số trên **1.337 tâm ô lưới**, đổi sang tọa độ kilomet cục bộ. Bán kính 1,5 km, khối lượng tối thiểu 20.000 lượt đón trong lân cận ô lõi, không phải 20.000 ô. Thuật toán trả **3 cụm** và nhóm nhiễu mã 0. Cụm 1 có 4.125.187 lượt, chiếm 92,44%; nhiễu có 133.098 lượt, chiếm 2,98%. Mẫu số bao gồm cả nhiễu.

Lưới là cách tổng hợp không gian cố định; DBSCAN học các nhóm liên thông theo mật độ. Cụm không phải khu phố, nhóm nhiễu không phải một cụm địa lý riêng. Nhãn học trên toàn giai đoạn được giữ cố định; lọc Tháng/Base chỉ tính lại lượt và tâm có trọng số. Khảo sát chín bộ tham số cho 2–4 cụm, thể hiện tính phụ thuộc tham số. Đây là học không giám sát mang tính mô tả, không phải mô hình dự báo ngoài mẫu.

## 6. Dashboard và trợ lý dữ liệu

Shiny cung cấp chín trang Việt/Anh; Plotly dùng cho biểu đồ, Leaflet cho bản đồ, DT cho bảng tra cứu. Nền tảng giao diện không tự nó là AI. Hai bảng tổng hợp chính gồm 21.852 dòng thời gian và 23.795 dòng địa lý, tổng khoảng 1,58 MB. Các kết quả mô hình, bất thường và phân cụm được đọc một lần lúc khởi động. Ứng dụng không đọc 4,5 triệu dòng, huấn luyện lại hay gọi API không cần thiết.

Trợ lý thực hiện chuỗi: câu hỏi → nhận diện ý định → kiểm tra tham số → truy vấn R trên dữ liệu đã nạp → dữ kiện có cấu trúc → mẫu trả lời kèm phạm vi và nguồn. Có **20 loại ý định** và trả lời an toàn khi không hỗ trợ. Hỗ trợ Việt/Anh, bộ lọc hiện tại và câu hỏi tiếp “Còn hạng hai?” sau xếp hạng Base. Các số chính thức do R tính, không do mô hình ngôn ngữ đoán.

Chế độ cục bộ đủ cho demo. LLM tùy chọn chỉ chọn lời dẫn đã kiểm soát; không sửa số liệu hay viết mã. Lỗi API trở về câu trả lời cục bộ. Không gửi bản ghi thô, không thực thi R/SQL do người dùng yêu cầu, không lưu lịch sử ra tệp. Trợ lý có thể từ chối câu hỏi doanh thu, tài xế, khu phố hay suy luận nguyên nhân. Đây là giao diện truy vấn có giới hạn, không khẳng định hiểu mọi cách diễn đạt.

## 7. Tái lập, kiểm chứng và giới hạn

Chạy `Rscript --vanilla Main.R`, sau đó `Rscript --vanilla tests/run_all_tests.R`. Bộ chạy tổng thực thi sáu bộ kiểm thử trong các phiên R độc lập, in PASS/FAIL và trả mã lỗi nếu có thất bại. Kiểm thử bao gồm đối chiếu dữ liệu thô, bảo toàn tổng, thứ tự thời gian, thay đổi mục tiêu hiện tại/tương lai để phát hiện rò rỉ, tính lại metric, phân cụm, đổi ngôn ngữ và an toàn trợ lý. Checksum liên kết mô hình với dữ liệu đầu vào để phát hiện kết quả cũ.

Giới hạn còn lại: một giai đoạn lịch sử ngắn; chỉ một tháng xác thực và một tháng kiểm tra; đặc trưng hai nhóm mô hình khác nhau; giả định có số lượt giờ trước ngay lập tức; không có dữ liệu nguyên nhân; lưới thô và tham số DBSCAN; hiệu chỉnh bất thường chỉ một tuần; nền bản đồ cần mạng. Chưa chứng minh hiệu quả triển khai thực tế hoặc độ ổn định trên mọi hệ điều hành/phiên bản gói. Tài liệu phiên bản giúp truy vết nhưng chưa khóa toàn bộ môi trường.

Khi nộp, loại `.r-library`, tệp môi trường có khóa bí mật, lịch sử R và logs khỏi ZIP; không xóa thư viện đang dùng trên máy phát triển. Giữ mã nguồn, kiểm thử, dữ liệu gốc nếu cần tái lập, kết quả nhỏ gọn và tài liệu. File Word rỗng cần được hoàn thiện riêng theo yêu cầu của trường.
