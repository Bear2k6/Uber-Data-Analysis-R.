# ============================================================
# Uber Data Analysis Project
# File: 05_insight_dashboard.R
# Author: TV5
# Purpose: Tổng hợp kết quả, rút ra insight, kết luận và dashboard
# ============================================================

source("R/00_setup.R")

# Dùng gridExtra để ghép dashboard 4 biểu đồ
if (!requireNamespace("gridExtra", quietly = TRUE)) {
  install.packages("gridExtra")
}

library(gridExtra)

# ============================================================
# 1. CHUẨN BỊ THƯ MỤC OUTPUT
# ============================================================
dir.create("Output/results", recursive = TRUE, showWarnings = FALSE)
dir.create("Output/figures", recursive = TRUE, showWarnings = FALSE)

# ============================================================
# 2. ĐỌC DỮ LIỆU ĐÃ LÀM SẠCH TỪ CHƯƠNG TRƯỚC
# ============================================================
clean_file <- "Output/results/uber_clean.csv"

if (!file.exists(clean_file)) {
  stop("Không tìm thấy Output/results/uber_clean.csv. Hãy chạy 01_data_cleaning.R trước.")
}

uber_data <- read.csv(clean_file, check.names = FALSE)

uber_data$`Date/Time` <- lubridate::mdy_hms(uber_data$`Date/Time`)
uber_data$Date <- as.Date(uber_data$`Date/Time`)
uber_data$Hour <- lubridate::hour(uber_data$`Date/Time`)
uber_data$Month <- lubridate::month(uber_data$`Date/Time`, label = TRUE, abbr = TRUE)
uber_data$Weekday <- lubridate::wday(uber_data$`Date/Time`, label = TRUE, abbr = TRUE)
uber_data$DayType <- ifelse(
  lubridate::wday(uber_data$`Date/Time`) %in% c(1, 7),
  "Weekend",
  "Weekday"
)

# ============================================================
# 3. TỔNG HỢP CÁC KPI CHÍNH
# ============================================================
trips_by_hour <- uber_data %>%
  count(Hour, name = "Total_Trips") %>%
  arrange(Hour)

trips_by_month <- uber_data %>%
  count(Month, name = "Total_Trips") %>%
  arrange(match(as.character(Month), c("Apr", "May", "Jun", "Jul", "Aug", "Sep")))

trips_by_weekday <- uber_data %>%
  count(Weekday, name = "Total_Trips") %>%
  arrange(match(as.character(Weekday), c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")))

trips_by_base <- uber_data %>%
  filter(!is.na(Base), Base != "") %>%
  count(Base, name = "Total_Trips") %>%
  arrange(desc(Total_Trips)) %>%
  mutate(Percentage = round(Total_Trips / sum(Total_Trips) * 100, 2))

peak_hour <- trips_by_hour %>% slice_max(Total_Trips, n = 1, with_ties = FALSE)
low_hour <- trips_by_hour %>% slice_min(Total_Trips, n = 1, with_ties = FALSE)
peak_month <- trips_by_month %>% slice_max(Total_Trips, n = 1, with_ties = FALSE)
peak_weekday <- trips_by_weekday %>% slice_max(Total_Trips, n = 1, with_ties = FALSE)
top_base <- trips_by_base %>% slice_max(Total_Trips, n = 1, with_ties = FALSE)

# Tăng trưởng từ tháng 4 đến tháng 9
apr_trips <- trips_by_month %>% filter(as.character(Month) == "Apr") %>% pull(Total_Trips)
sep_trips <- trips_by_month %>% filter(as.character(Month) == "Sep") %>% pull(Total_Trips)
growth_apr_sep <- round((sep_trips / apr_trips - 1) * 100, 2)

# ============================================================
# 4. WEEKDAY VS WEEKEND - SO SÁNH CÔNG BẰNG THEO TRUNG BÌNH NGÀY
# ============================================================
daily_trips <- uber_data %>%
  count(Date, DayType, name = "Total_Trips")

avg_day_type <- daily_trips %>%
  group_by(DayType) %>%
  summarise(
    Number_of_Days = n(),
    Average_Trips_Per_Day = round(mean(Total_Trips), 0),
    Median_Trips_Per_Day = round(median(Total_Trips), 0),
    .groups = "drop"
  )

# Giờ cao điểm riêng cho ngày thường và cuối tuần
peak_hour_day_type <- uber_data %>%
  count(DayType, Hour, name = "Total_Trips") %>%
  group_by(DayType) %>%
  slice_max(Total_Trips, n = 1, with_ties = FALSE) %>%
  ungroup()

# ============================================================
# 5. PHÂN TÍCH ĐỊA LÝ / HOTSPOT
# ============================================================
location_data <- uber_data %>%
  mutate(
    Lat = suppressWarnings(as.numeric(Lat)),
    Lon = suppressWarnings(as.numeric(Lon))
  ) %>%
  filter(
    !is.na(Lat), !is.na(Lon),
    Lat >= 40.5774, Lat <= 40.9176,
    Lon >= -74.1500, Lon <= -73.7004
  )

nyc_percentage <- round(nrow(location_data) / nrow(uber_data) * 100, 2)

location_grid <- location_data %>%
  mutate(
    Lat_Grid = round(Lat, 2),
    Lon_Grid = round(Lon, 2)
  ) %>%
  count(Lat_Grid, Lon_Grid, name = "Total_Trips") %>%
  arrange(desc(Total_Trips))

top_hotspot <- location_grid %>% slice_head(n = 1)

# ============================================================
# 6. BẢNG TÓM TẮT CHƯƠNG 5
# ============================================================
summary_table <- data.frame(
  Metric = c(
    "Total trips",
    "Peak hour",
    "Trips at peak hour",
    "Lowest hour",
    "Trips at lowest hour",
    "Peak month",
    "Trips in peak month",
    "Growth Apr to Sep (%)",
    "Peak weekday",
    "Trips on peak weekday",
    "Most active Base",
    "Trips of most active Base",
    "Most active Base share (%)",
    "Trips inside NYC area (%)",
    "Top hotspot latitude grid",
    "Top hotspot longitude grid",
    "Trips in top hotspot grid"
  ),
  Value = c(
    nrow(uber_data),
    peak_hour$Hour,
    peak_hour$Total_Trips,
    low_hour$Hour,
    low_hour$Total_Trips,
    as.character(peak_month$Month),
    peak_month$Total_Trips,
    growth_apr_sep,
    as.character(peak_weekday$Weekday),
    peak_weekday$Total_Trips,
    top_base$Base,
    top_base$Total_Trips,
    top_base$Percentage,
    nyc_percentage,
    top_hotspot$Lat_Grid,
    top_hotspot$Lon_Grid,
    top_hotspot$Total_Trips
  )
)

write.csv(summary_table, "Output/results/chapter5_summary.csv", row.names = FALSE)
write.csv(avg_day_type, "Output/results/chapter5_weekday_weekend.csv", row.names = FALSE)
write.csv(peak_hour_day_type, "Output/results/chapter5_peak_hour_day_type.csv", row.names = FALSE)

# ============================================================
# 7. TỰ ĐỘNG TẠO INSIGHT DẠNG TEXT
# ============================================================
weekday_avg <- avg_day_type %>% filter(DayType == "Weekday") %>% pull(Average_Trips_Per_Day)
weekend_avg <- avg_day_type %>% filter(DayType == "Weekend") %>% pull(Average_Trips_Per_Day)
weekday_vs_weekend <- round((weekday_avg / weekend_avg - 1) * 100, 2)

insights <- c(
  "CHƯƠNG 5 - KẾT QUẢ, INSIGHT VÀ KẾT LUẬN",
  "",
  paste0("1. Dataset có ", scales::comma(nrow(uber_data)), " chuyến Uber trong giai đoạn 04/2014-09/2014."),
  paste0("2. Khung giờ cao điểm là ", peak_hour$Hour, ":00 với ", scales::comma(peak_hour$Total_Trips), " chuyến; thấp nhất là ", low_hour$Hour, ":00 với ", scales::comma(low_hour$Total_Trips), " chuyến."),
  paste0("3. Tháng có nhiều chuyến nhất là ", as.character(peak_month$Month), " với ", scales::comma(peak_month$Total_Trips), " chuyến. Lượng chuyến tháng 9 cao hơn tháng 4 khoảng ", growth_apr_sep, "%."),
  paste0("4. ", as.character(peak_weekday$Weekday), " là thứ có tổng số chuyến cao nhất với ", scales::comma(peak_weekday$Total_Trips), " chuyến."),
  paste0("5. Khi chuẩn hóa theo số ngày, một ngày thường có trung bình ", scales::comma(weekday_avg), " chuyến, cao hơn cuối tuần khoảng ", weekday_vs_weekend, "% (cuối tuần: ", scales::comma(weekend_avg), " chuyến/ngày)."),
  paste0("6. Base hoạt động mạnh nhất là ", top_base$Base, " với ", scales::comma(top_base$Total_Trips), " chuyến, chiếm ", top_base$Percentage, "% tổng số chuyến."),
  paste0("7. Khoảng ", nyc_percentage, "% bản ghi nằm trong bounding box NYC được sử dụng trong phân tích địa lý."),
  paste0("8. Grid điểm đón dày nhất nằm quanh (", top_hotspot$Lat_Grid, ", ", top_hotspot$Lon_Grid, ") với ", scales::comma(top_hotspot$Total_Trips), " chuyến."),
  "",
  "KẾT LUẬN:",
  "Nhu cầu Uber không phân bố đồng đều theo thời gian và không gian. Nhu cầu tập trung mạnh vào buổi chiều - đầu buổi tối, tăng rõ rệt trong giai đoạn tháng 4 đến tháng 9, đồng thời tập trung tại một số grid địa lý và một số Base chủ lực. Uber có thể ưu tiên phân bổ tài xế theo khung giờ cao điểm, khu vực pickup mật độ cao và theo dõi tăng trưởng nhu cầu theo tháng để giảm thời gian chờ và nâng cao hiệu quả vận hành."
)

writeLines(insights, "Output/results/chapter5_insights.txt", useBytes = TRUE)
cat(paste(insights, collapse = "\n"), "\n")

# ============================================================
# 8. DASHBOARD TÓM TẮT 4 BIỂU ĐỒ
# ============================================================
p1 <- ggplot(trips_by_hour, aes(x = Hour, y = Total_Trips)) +
  geom_col(fill = "steelblue") +
  scale_x_continuous(breaks = 0:23) +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Trips by Hour", x = "Hour", y = "Trips") +
  theme_minimal()

p2 <- ggplot(trips_by_month, aes(x = Month, y = Total_Trips)) +
  geom_col(fill = "darkorange") +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Trips by Month", x = "Month", y = "Trips") +
  theme_minimal()

p3 <- ggplot(trips_by_weekday, aes(x = Weekday, y = Total_Trips)) +
  geom_col(fill = "seagreen") +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Trips by Weekday", x = "Weekday", y = "Trips") +
  theme_minimal()

p4 <- ggplot(trips_by_base, aes(x = reorder(Base, Total_Trips), y = Total_Trips)) +
  geom_col(fill = "mediumpurple") +
  coord_flip() +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Trips by Base", x = "Base", y = "Trips") +
  theme_minimal()

png(
  "Output/figures/05_insight_dashboard.png",
  width = 1800,
  height = 1200,
  res = 150
)

gridExtra::grid.arrange(
  p1, p2, p3, p4,
  ncol = 2,
  top = "UBER DATA ANALYSIS - CHAPTER 5 DASHBOARD"
)

dev.off()

cat("\nChapter 5 completed successfully.\n")
cat("Outputs:\n")
cat("- Output/results/chapter5_summary.csv\n")
cat("- Output/results/chapter5_weekday_weekend.csv\n")
cat("- Output/results/chapter5_peak_hour_day_type.csv\n")
cat("- Output/results/chapter5_insights.txt\n")
cat("- Output/figures/05_insight_dashboard.png\n")
