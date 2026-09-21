# Câu hỏi bảo vệ đồ án và trả lời gợi ý

Trả lời dựa trên triển khai và kết quả đã lưu; không phóng đại khả năng AI. Số liệu đầy đủ và lệnh chạy xem README.

## Dataset

### 1. Dữ liệu lấy từ đâu?

Từ bộ Uber TLC FOIL do FiveThirtyEight công bố, nguồn hồ sơ NYC TLC. Đồ án chỉ dùng sáu CSV tháng 4–9/2014.

### 2. Có bao nhiêu dữ liệu?

4.534.327 bản ghi lượt đón, 183 ngày và 5 Base. Không gọi đây là số hành trình duy nhất đã xác minh.

### 3. Bốn cột gốc có ý nghĩa gì?

Date/Time là thời điểm đón, Lat/Lon là tọa độ, Base là mã đơn vị TLC gắn với lượt đón.

### 4. Có thể tính doanh thu hoặc quãng đường không?

Không. Không có giá cước, điểm đến hoặc chiều dài hành trình.

### 5. Dữ liệu có đại diện cho Uber hiện nay không?

Không. Dữ liệu lịch sử năm 2014 có phạm vi và điều kiện thị trường riêng.

## R và pipeline

### 6. Vì sao chọn R?

R phù hợp xử lý dữ liệu dạng bảng, thống kê, mô hình và trực quan hóa; Shiny cho phép dùng chung ngôn ngữ cho phân tích và giao diện.

### 7. Main.R làm gì?

Chạy tuần tự setup, làm sạch, EDA, hình/insight, marts, mô hình rồi anomaly và clustering. Lỗi ở bước nào làm pipeline dừng ở đó.

### 8. Có cần chạy Main.R mỗi lần mở app không?

Không. Shiny đọc kết quả nhỏ gọn đã lưu; chỉ chạy lại pipeline khi dữ liệu hoặc quy trình phân tích thay đổi.

### 9. Seed có đủ bảo đảm tái lập tuyệt đối không?

Không. Seed 42 giúp tái lập trong môi trường tương thích; phiên bản gói, thuật toán và phần cứng vẫn có thể ảnh hưởng. Metadata lưu phiên bản và tham số.

## Làm sạch

### 10. Vì sao giữ 82.581 dòng trùng?

Không có mã chuyến duy nhất; giống thời gian, tọa độ, Base chưa đủ kết luận cùng một lượt đón. Báo cáo số trùng và không âm thầm xóa.

### 11. Giá trị thiếu được xử lý thế nào?

Pipeline kiểm tra và xuất thống kê; dữ liệu cung cấp không có thiếu ở cột bắt buộc. Không bịa giá trị thay thế.

### 12. Tọa độ hợp lệ khác tọa độ trong NYC thế nào?

Hợp lệ là trong miền vĩ độ/kinh độ toàn cầu. Trong NYC ở đây là qua bộ lọc hình chữ nhật đã công bố, không phải kiểm tra địa giới.

### 13. Thời gian có được chuyển sang UTC không?

Giữ thành phần giờ/ngày gốc. UTC ở chuỗi giờ là nhãn lưu trữ, không chuyển giờ New York.

### 14. Điền 0 vào giờ thiếu có rủi ro gì?

Không có bản ghi có thể là thiếu độ bao phủ, không chắc nhu cầu bằng 0. Đồ án đánh dấu nguồn giờ và nêu rõ giới hạn, nhất là giờ cuối tháng 9.

## EDA

### 15. Giờ cao điểm là gì?

17:00 có tổng 336.190 lượt qua toàn giai đoạn. Không phải số lượt trong một giờ đơn lẻ.

### 16. Tháng và ngày cao điểm là khi nào?

Tháng 9 có 1.028.136 lượt; ngày nhiều lượt nhất là 13/9/2014. Đỉnh theo thứ là thứ Năm.

### 17. Vì sao so ngày thường/cuối tuần bằng trung bình ngày?

Số ngày hai nhóm khác nhau. Chia cho số ngày tương ứng tránh nhầm tổng cao hơn do có nhiều ngày hơn.

### 18. Bộ lọc nhiều điều kiện hoạt động ra sao?

Lấy giao trên cùng time cube. Sep + Weekday + Thu + 17 + B02617 bằng 4.170, đã đối chiếu raw September.

### 19. Ngày không có lượt được chọn có tính vào trung bình không?

Có, nếu ngày đó phù hợp điều kiện lịch. Mẫu số không bị thu hẹp chỉ vì Base/giờ không có lượt.

## Dispatch Base

### 20. Base có phải tài xế không?

Không. Là mã đơn vị Base của TLC gắn với bản ghi đón; không suy ra số tài xế.

### 21. Base nào lớn nhất, thứ hai?

B02617: 1.458.853 lượt; B02598: 1.393.113 lượt trong toàn giai đoạn.

### 22. Tỷ trọng Base có phải thị phần không?

Không. Mẫu số chỉ là lượt trong dữ liệu dưới cùng điều kiện thời gian, không bao gồm toàn bộ thị trường.

### 23. Khi chọn một Base thì vì sao vẫn hiện Base khác?

Để giữ bối cảnh xếp hạng và tỷ trọng; Base được chọn được tô nổi bật, không đổi mẫu số thành chính nó.

## Geography

### 24. Có bao nhiêu lượt trong bbox?

4.462.626 lượt, tương ứng 98,42% bản ghi có tọa độ hợp lệ. Tỷ lệ trên app là số làm tròn.

### 25. Lưới 0,01 độ có phải 1 km² không?

Không chính xác; chiều dài theo kinh độ phụ thuộc vĩ độ. Đồ án chỉ gọi là lưới 0,01 độ.

### 26. Tại sao không đặt tên Manhattan hoặc sân bay?

Tâm lưới và nhãn cụm chưa được đối chiếu với dữ liệu ranh giới/địa danh. Đặt tên sẽ vượt quá bằng chứng có sẵn.

### 27. Top N có làm sai tỷ trọng không?

Không. Top N chỉ giới hạn ô hiển thị; tỷ trọng dùng tổng tất cả ô phù hợp tháng và Base.

## Dashboard

### 28. Shiny có phải AI không?

Không. Shiny là framework giao diện phản ứng; học máy nằm ở các bước mô hình/phân cụm, không ở bản thân framework.

### 29. Vì sao app không đọc trực tiếp 4,5 triệu dòng?

Các câu hỏi dashboard dùng tổng hợp chính xác nên marts đủ thông tin, giảm bộ nhớ và thời gian khởi động.

### 30. Đổi ngôn ngữ có đổi kết quả không?

Không. Chỉ nhãn và định dạng hiển thị thay đổi; bộ lọc dùng giá trị chuẩn, được kiểm thử vòng VI/EN/VI.

### 31. Plotly, Leaflet, DT đảm nhiệm gì?

Plotly: biểu đồ tương tác; Leaflet: bản đồ; DT: bảng tìm kiếm/lọc. Các phép tính chính nằm ở R.

### 32. App có hoạt động không mạng không?

Phân tích và trợ lý cục bộ hoạt động với thư viện/kết quả đã có; nền OpenStreetMap cần mạng. API tùy chọn không bắt buộc.

## Cây hồi quy

### 33. Cây hồi quy học như thế nào?

Chia dữ liệu theo đặc trưng thành các vùng để dự báo giá trị số; dự báo trong lá dựa trên dữ liệu huấn luyện.

### 34. Vì sao baseline tốt hơn cây?

Quan sát cho thấy chu kỳ tuần là mốc mạnh, còn cây hiện tại RMSE cao hơn. Chưa có thí nghiệm loại trừ để khẳng định nguyên nhân; không ép diễn giải thuật toán phức tạp luôn thắng.

### 35. Cây hiện tại có bao nhiêu đặc trưng?

Năm: Hour, Weekday, DayIndex, lag_24, lag_168. Cấu hình gốc được giữ để bảo toàn mốc so sánh.

## Random Forest

### 36. Vì sao dùng Rừng ngẫu nhiên?

Nó mô hình hóa quan hệ phi tuyến và tổ hợp nhiều cây giúp giảm độ biến động của cây đơn; phù hợp dữ liệu bảng trong phạm vi đồ án.

### 37. Chọn tham số bằng cách nào?

Thử bốn cấu hình mtry và kích thước lá trên tháng 8; chọn RMSE thấp nhất rồi huấn luyện lại đến 31/8.

### 38. Có bao nhiêu cây?

400 cây, seed 42; cấu hình được chọn có mtry 5 và min.node.size 5. Metadata lưu thông tin này.

## XGBoost

### 39. Vì sao dùng XGBoost?

Đây là mô hình cây tăng cường cho dữ liệu bảng, bổ sung cây để giảm sai số. Nó cho một hướng tổ hợp khác với Random Forest.

### 40. Dừng sớm có nhìn vào tháng 9 không?

Không. Chỉ dùng RMSE tháng 8, tối đa 400 vòng, kiên nhẫn 30 vòng; cấu hình cuối dùng 78 vòng.

### 41. Mô hình tốt nhất là gì?

XGBoost có RMSE tháng 9 thấp nhất, khoảng 205,74; chỉ kết luận trong tập kiểm tra và giao thức này.

### 42. Có thể nói toàn bộ cải thiện do thuật toán không?

Không. Cây gốc dùng 5 biến, hai mô hình tổ hợp dùng 15. Cần so cùng đặc trưng hoặc thí nghiệm loại trừ để tách tác dụng.

## Metrics và rò rỉ dữ liệu

### 43. MAE khác RMSE ra sao?

MAE là trung bình trị tuyệt đối sai số; RMSE căn trung bình bình phương sai số, nhạy hơn với lỗi lớn. Cùng đơn vị lượt đón.

### 44. R² 0,932 có phải dự báo đúng 93,2% không?

Không. R² so tổng bình phương sai số với biến thiên quanh trung bình tập kiểm tra, không phải accuracy phân loại.

### 45. MAPE xử lý thực tế bằng 0 thế nào?

Bỏ các giờ có thực tế bằng 0 khỏi phép tính MAPE và công bố giới hạn. Các metric khác vẫn dùng đủ 720 giờ.

### 46. Vì sao không chia ngẫu nhiên train/test?

Ngẫu nhiên phá thứ tự thời gian và có thể cho thông tin tương lai đi vào đánh giá; ở đây dùng chia theo lịch.

### 47. Dùng giá trị đầu tháng 9 dự báo cuối tháng 9 có rò rỉ không?

Trong giao thức cuốn chiếu một giờ, số liệu đã quan sát trước t là hợp lệ. Không được diễn giải đây là dự báo cả tháng tại 31/8.

### 48. Kiểm tra cửa sổ không chứa tương lai thế nào?

Kiểm thử thay đổi mục tiêu hiện tại/tương lai và xác nhận đặc trưng hiện tại/quá khứ không đổi; kiểm tra riêng độ trễ và cửa sổ kết thúc ở t−1.

## Anomaly detection

### 49. Anomaly có nghĩa đã xảy ra sự kiện không?

Không. Chỉ là lệch đáng chú ý khỏi kỳ vọng; cần dữ liệu sự kiện/thời tiết/giao thông để điều tra nguyên nhân.

### 50. Vì sao dùng Random Forest cho anomaly dù XGBoost thắng?

Reference anomaly được chọn theo RMSE xác thực tháng 8 giữa hai tổ hợp. XGBoost thắng trên tháng 9 là kết quả kiểm tra sau đó, không dùng đổi reference.

### 51. Ngưỡng phát hiện là gì?

Điểm modified z-score tuyệt đối của phần dư lớn hơn 3,5; hiệu chỉnh median/MAD trên 168 giờ đầu tháng 9.

### 52. Có bao nhiêu anomaly?

11 trong 552 giờ chấm điểm, khoảng 1,99%. Tuần hiệu chỉnh không nằm trong mẫu số.

### 53. Tại sao giờ cuối tháng cần thận trọng?

23:00 ngày 30/9 là giờ không có bản ghi được điền 0. Bất thường ở đó có thể phản ánh thiếu dữ liệu chứ không phải nhu cầu giảm thật.

## Clustering

### 54. Grid hotspot khác DBSCAN thế nào?

Grid cộng lượt trong các ô cố định. DBSCAN học nhóm liên thông mật độ giữa các tâm ô; đây là học không giám sát.

### 55. Trọng số DBSCAN có nghĩa gì?

Mỗi tâm ô đại diện số lượt đón của ô. Ngưỡng 20.000 là tổng trọng số trong bán kính 1,5 km, không phải số ô.

### 56. Có mấy cụm và nhiễu là gì?

Có 3 cụm; mã 0 là các ô nhiễu không thuộc cụm. Không gọi toàn bộ nhiễu là một cụm thứ tư.

### 57. Lọc tháng có chạy lại DBSCAN không?

Không. Nhãn toàn giai đoạn giữ nguyên; tháng/Base chỉ đổi lượt đón và tâm có trọng số. Đây là so sánh trong phân hoạch cố định.

### 58. Kết quả có nhạy tham số không?

Có. Chín bộ tham số cho 2–4 cụm; kết quả chính là một cấu hình công bố rõ, không phải phân chia duy nhất đúng.

## AI Assistant

### 59. Vì sao gọi đây là đồ án AI?

Có dự báo học có giám sát, DBSCAN không giám sát và sàng lọc bất thường dựa trên dự báo. Trợ lý bổ sung giao diện hỏi đáp có căn cứ; phần cục bộ là bộ truy vấn theo luật.

### 60. Chatbot có bịa số không?

Trong các ý định hỗ trợ, số được R lấy/tính từ kết quả đã lưu và đi qua mẫu cố định. Không tuyên bố hiểu mọi câu hỏi; ánh xạ ý định sai vẫn là rủi ro cần kiểm thử.

### 61. Chặn số do LLM bịa bằng cách nào?

LLM chỉ được chọn một lời dẫn trong danh sách; không được sửa dữ kiện, thêm số hay chạy R/SQL. JSON không hợp lệ quay về trả lời cục bộ.

### 62. Không có API thì sao?

Toàn bộ câu hỏi hỗ trợ vẫn chạy cục bộ. API chỉ là lựa chọn diễn đạt, không chịu trách nhiệm tính toán.

### 63. Trợ lý có nhớ hội thoại không?

Giữ tối đa 20 lượt trong phiên và hỗ trợ hỏi hạng hai sau xếp hạng Base. Không có trí nhớ lâu dài hoặc suy luận hội thoại tùy ý.

### 64. Nguồn câu trả lời ở đâu?

Các time/geo marts, metrics/importance, anomalies và cluster assignments đã nạp khi khởi động; mỗi câu trả lời nêu phạm vi và tên nguồn.

### 65. Có gửi dữ liệu thô lên API không?

Không. Nếu bật chế độ ngoài, chỉ gửi câu hỏi hiện tại và kết quả tổng hợp có cấu trúc, không gửi lịch sử hoặc 4,5 triệu dòng.

## Giới hạn và bảo vệ kết luận

### 66. Vì sao không dùng mạng nơ-ron?

Phạm vi là dữ liệu bảng theo giờ với tập kiểm tra ngắn. Các mốc đơn giản và mô hình cây đủ để kiểm chứng; chưa có bằng chứng cần thêm độ phức tạp hoặc chi phí.

### 67. Hạn chế quan trọng nhất là gì?

Dữ liệu 2014 thiếu biến giải thích và chỉ có một tháng kiểm tra. Kết luận mô tả lịch sử, chưa phải chứng minh vận hành thực tế.

### 68. Có thể triển khai dự báo thật ngay không?

Chưa. Cần nguồn dữ liệu đến đúng hạn, kiểm tra qua nhiều giai đoạn, xử lý thiếu dữ liệu, drift, độ trễ và đánh giá ngoài mẫu mới.

### 69. Làm sao biết kết quả không cũ?

Pipeline tái tạo đầu ra; metadata/checksum liên kết model với time cube và cluster với geo cube/predictions; kiểm thử đối chiếu lineage.

### 70. Báo cáo Word đã sẵn sàng chưa?

Chưa. File Word gốc có 0 byte, được giữ nguyên. README, tóm tắt và Q&A hỗ trợ bảo vệ nhưng không tự thay mẫu báo cáo trường.

### 71. Nộp ZIP cần tránh gì?

Không đưa thư viện .r-library, lịch sử R, môi trường chứa khóa hoặc logs vào ZIP. .gitignore không tự áp dụng cho ZIP; kiểm tra danh sách trước khi nộp.
