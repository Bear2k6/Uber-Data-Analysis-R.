# 🚕 Uber Data Analysis Project

## 📌 Giới thiệu

**Uber Data Analysis Project** là dự án phân tích dữ liệu các chuyến đi Uber tại **New York City** bằng ngôn ngữ **R**.

Dự án tập trung vào việc thu thập, tiền xử lý, phân tích và trực quan hóa dữ liệu nhằm tìm ra các xu hướng về **thời gian, tần suất chuyến đi, khu vực hoạt động và các Base của Uber**.

> **Tên đề tài:** Phân tích dữ liệu chuyến đi Uber tại New York bằng R
> **English:** Uber Data Analysis Using R

---

## 🎯 Mục tiêu

Dự án hướng đến các mục tiêu:

* Làm sạch và chuẩn hóa dữ liệu Uber.
* Phân tích số lượng chuyến đi theo thời gian.
* Xác định các khung giờ có nhu cầu Uber cao.
* Phân tích số chuyến theo ngày, tháng và thứ trong tuần.
* Phân tích hoạt động của các Uber Base.
* Trực quan hóa dữ liệu bằng các biểu đồ.
* Tìm ra các **insight** có ý nghĩa từ dữ liệu.
* Rèn luyện kỹ năng sử dụng **R cho Data Analysis và Data Visualization**.

---

## 📊 Dataset

Dataset bao gồm dữ liệu các chuyến Uber tại New York City trong khoảng thời gian:

**04/2014 – 09/2014**

Dữ liệu được chia thành 6 file CSV:

```text
uber-raw-data-apr14.csv
uber-raw-data-may14.csv
uber-raw-data-jun14.csv
uber-raw-data-jul14.csv
uber-raw-data-aug14.csv
uber-raw-data-sep14.csv
```

Các thông tin chính trong dataset:

| Thuộc tính  | Ý nghĩa                     |
| ----------- | --------------------------- |
| `Date/Time` | Ngày và thời gian chuyến đi |
| `Lat`       | Vĩ độ điểm đón              |
| `Lon`       | Kinh độ điểm đón            |
| `Base`      | Mã Uber Base                |
| `Hour`      | Giờ                         |
| `Day`       | Ngày                        |
| `Month`     | Tháng                       |
| `Weekday`   | Thứ trong tuần              |

---

## 🛠️ Công nghệ sử dụng

### Ngôn ngữ

* **R**

### Libraries

```r
ggplot2
dplyr
tidyr
lubridate
ggthemes
scales
DT
```

### Công cụ

* RStudio
* Git
* GitHub

---

## 📁 Cấu trúc project

```text
Uber-Data-Analysis-R/
│
├── data/
│   ├── uber-raw-data-apr14.csv
│   ├── uber-raw-data-may14.csv
│   ├── uber-raw-data-jun14.csv
│   ├── uber-raw-data-jul14.csv
│   ├── uber-raw-data-aug14.csv
│   └── uber-raw-data-sep14.csv
│
├── R/
│   ├── 01_data_cleaning.R
│   ├── 02_time_analysis.R
│   ├── 03_base_analysis.R
│   ├── 04_location_analysis.R
│   └── 05_visualization.R
│
├── output/
│   ├── figures/
│   └── results/
│
├── report/
│   └── BaoCao_Uber_Data_Analysis.docx
│
├── main.R
├── README.md
└── .gitignore
```

---

## 🔎 Quy trình phân tích

```text
Dataset
   ↓
Data Collection
   ↓
Data Cleaning
   ↓
Data Transformation
   ↓
Exploratory Data Analysis
   ↓
Data Visualization
   ↓
Insight & Analysis
   ↓
Conclusion
```

---

## 📈 Nội dung phân tích

### 1. Phân tích theo giờ

Xác định số lượng chuyến Uber theo từng giờ trong ngày.

Mục tiêu:

* Tìm giờ cao điểm.
* Tìm giờ thấp điểm.
* Phân tích nhu cầu sử dụng Uber trong ngày.

---

### 2. Phân tích theo ngày

Phân tích số lượng chuyến theo ngày trong tháng.

Mục tiêu:

* Xác định những ngày có lượng chuyến cao.
* Quan sát sự thay đổi nhu cầu theo từng ngày.

---

### 3. Phân tích theo tháng

So sánh số lượng chuyến trong 6 tháng:

```text
April
May
June
July
August
September
```

Mục tiêu:

* Xác định tháng có nhu cầu cao nhất.
* Quan sát xu hướng sử dụng Uber theo thời gian.

---

### 4. Phân tích theo thứ trong tuần

So sánh:

```text
Monday
Tuesday
Wednesday
Thursday
Friday
Saturday
Sunday
```

Mục tiêu:

* Xác định ngày trong tuần có nhiều chuyến nhất.
* So sánh nhu cầu giữa ngày thường và cuối tuần.

---

### 5. Phân tích Uber Base

Phân tích số lượng chuyến của từng Uber Base.

Mục tiêu:

* Xác định Base có số lượng chuyến cao nhất.
* So sánh mức độ hoạt động giữa các Base.

---

### 6. Phân tích vị trí

Sử dụng thông tin:

```text
Latitude
Longitude
```

để trực quan hóa các điểm đón Uber tại New York City.

Mục tiêu:

* Xác định khu vực tập trung nhiều chuyến.
* Quan sát sự phân bố địa lý của các chuyến Uber.

---

### 7. Heatmap

Xây dựng heatmap để biểu diễn số lượng chuyến theo:

```text
Hour × Weekday
```

và có thể mở rộng:

```text
Month × Hour
```

Heatmap giúp dễ dàng xác định các thời điểm có nhu cầu Uber cao.

---

## 💡 Expected Insights

Sau khi hoàn thành phân tích, nhóm sẽ tập trung trả lời các câu hỏi:

1. Khung giờ nào có nhiều chuyến Uber nhất?
2. Khung giờ nào có ít chuyến nhất?
3. Tháng nào có số lượng chuyến cao nhất?
4. Ngày nào trong tuần có nhu cầu cao nhất?
5. Uber Base nào hoạt động nhiều nhất?
6. Những khu vực nào tập trung nhiều điểm đón?
7. Có sự khác biệt về nhu cầu giữa ngày thường và cuối tuần không?
8. Có thể rút ra những insight nào giúp Uber tối ưu hoạt động?

---

## 👥 Phân công thành viên

| Thành viên   | Nhiệm vụ                        |
| ------------ | ------------------------------- |
| **Member 1** | Data Collection & Data Cleaning |
| **Member 2** | Time Analysis                   |
| **Member 3** | Base & Geographic Analysis      |
| **Member 4** | Data Visualization & Heatmap    |
| **Member 5** | Report, Insights & Presentation |

---

## ▶️ Cách chạy project

### 1. Cài đặt R

Cài đặt **R** và **RStudio**.

### 2. Cài đặt các thư viện

Chạy:

```r
install.packages(c(
  "ggplot2",
  "dplyr",
  "tidyr",
  "lubridate",
  "ggthemes",
  "scales",
  "DT"
))
```

### 3. Đặt dataset

Đặt các file `.csv` vào thư mục:

```text
data/
```

### 4. Chạy project

Mở:

```text
main.R
```
sau đó chạy toàn bộ chương trình.
---
## 📂 Output

Các kết quả phân tích được lưu trong:

```text
output/
├── figures/
└── results/
```
Bao gồm:
* Biểu đồ số chuyến theo giờ.
* Biểu đồ số chuyến theo ngày.
* Biểu đồ số chuyến theo tháng.
* Biểu đồ theo thứ.
* Biểu đồ theo Base.
* Heatmap.
* Visualization về vị trí.

---

## 📚 References
Dataset và ý tưởng ban đầu được tham khảo từ bài hướng dẫn:
**DataFlair – R Data Science Project: Uber Data Analysis**
[DataFlair – Uber Data Analysis Project](https://data-flair.training/blogs/r-data-science-project-uber-data-analysis/?utm_source=chatgpt.com)
---
## 📄 License
Project được thực hiện cho mục đích **học tập và nghiên cứu**.
---
## ⭐ Project
**Uber Data Analysis Using R**
> Data Analysis • Data Visualization • R • EDA • Uber NYC
