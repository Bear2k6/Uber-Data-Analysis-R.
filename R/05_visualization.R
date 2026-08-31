# ============================================================
# 04_visualization.R
# Uber Data Analysis - Chapter 4: Visualization
# ============================================================

# 1. Thư viện
library(ggplot2)
library(dplyr)
library(scales)

# ============================================================
# 2. Tự tìm dữ liệu đã làm sạch
# ============================================================

if (file.exists("output/results/uber_clean.csv")) {
  data_file <- "output/results/uber_clean.csv"
} else if (file.exists("../output/results/uber_clean.csv")) {
  data_file <- "../output/results/uber_clean.csv"
} else {
  stop("Không tìm thấy file uber_clean.csv")
}

uber_data <- read.csv(data_file)

cat("Đã đọc dữ liệu thành công!\n")
cat("Tổng số chuyến:", format(nrow(uber_data), big.mark = ","), "\n\n")

# Tạo thư mục lưu hình
if (file.exists("output")) {
  dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)
} else {
  dir.create("../output/figures", recursive = TRUE, showWarnings = FALSE)
}

if (file.exists("output/figures")) {
  figure_path <- "output/figures"
} else {
  figure_path <- "../output/figures"
}

# ============================================================
# 3. BIỂU ĐỒ 1: SỐ CHUYẾN THEO GIỜ
# ============================================================

trips_by_hour <- uber_data %>%
  group_by(Hour) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  arrange(Hour)

p_hour <- ggplot(
  trips_by_hour,
  aes(x = Hour, y = Total_Trips)
) +
  geom_col() +
  geom_text(
    aes(label = comma(Total_Trips)),
    vjust = -0.3,
    size = 3
  ) +
  scale_x_continuous(breaks = 0:23) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Số lượng chuyến Uber theo giờ",
    subtitle = "New York City - April to September 2014",
    x = "Giờ trong ngày",
    y = "Số chuyến"
  ) +
  theme_minimal()

print(p_hour)

ggsave(
  file.path(figure_path, "01_trips_by_hour.png"),
  p_hour,
  width = 10,
  height = 6,
  dpi = 300
)

# ============================================================
# 4. BIỂU ĐỒ 2: SỐ CHUYẾN THEO THÁNG
# ============================================================

month_order <- c("Apr", "May", "Jun", "Jul", "Aug", "Sep")

trips_by_month <- uber_data %>%
  group_by(Month) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  mutate(Month = factor(Month, levels = month_order)) %>%
  arrange(Month)

p_month <- ggplot(
  trips_by_month,
  aes(x = Month, y = Total_Trips)
) +
  geom_col() +
  geom_text(
    aes(label = comma(Total_Trips)),
    vjust = -0.3,
    size = 3.5
  ) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Số lượng chuyến Uber theo tháng",
    subtitle = "New York City - April to September 2014",
    x = "Tháng",
    y = "Số chuyến"
  ) +
  theme_minimal()

print(p_month)

ggsave(
  file.path(figure_path, "02_trips_by_month.png"),
  p_month,
  width = 9,
  height = 6,
  dpi = 300
)

# ============================================================
# 5. BIỂU ĐỒ 3: SỐ CHUYẾN THEO THỨ
# ============================================================

weekday_order <- c(
  "Mon", "Tue", "Wed",
  "Thu", "Fri", "Sat", "Sun"
)

trips_by_weekday <- uber_data %>%
  group_by(Weekday) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  mutate(
    Weekday = factor(
      Weekday,
      levels = weekday_order
    )
  ) %>%
  arrange(Weekday)

p_weekday <- ggplot(
  trips_by_weekday,
  aes(x = Weekday, y = Total_Trips)
) +
  geom_col() +
  geom_text(
    aes(label = comma(Total_Trips)),
    vjust = -0.3,
    size = 3.5
  ) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Số lượng chuyến Uber theo thứ trong tuần",
    subtitle = "New York City - April to September 2014",
    x = "Thứ",
    y = "Số chuyến"
  ) +
  theme_minimal()

print(p_weekday)

ggsave(
  file.path(figure_path, "03_trips_by_weekday.png"),
  p_weekday,
  width = 9,
  height = 6,
  dpi = 300
)

# ============================================================
# 6. BIỂU ĐỒ 4: HEATMAP GIỜ × THỨ
# ============================================================

heatmap_data <- uber_data %>%
  group_by(Weekday, Hour) %>%
  summarise(
    Total_Trips = n(),
    .groups = "drop"
  ) %>%
  mutate(
    Weekday = factor(
      Weekday,
      levels = weekday_order
    )
  )

p_heatmap <- ggplot(
  heatmap_data,
  aes(
    x = Hour,
    y = Weekday,
    fill = Total_Trips
  )
) +
  geom_tile(color = "white") +
  scale_x_continuous(breaks = 0:23) +
  scale_fill_gradient(
    low = "white",
    high = "red",
    labels = comma
  ) +
  labs(
    title = "Heatmap số lượng chuyến Uber theo giờ và thứ",
    subtitle = "New York City - April to September 2014",
    x = "Giờ trong ngày",
    y = "Thứ trong tuần",
    fill = "Số chuyến"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    )
  )

print(p_heatmap)

ggsave(
  file.path(figure_path, "04_heatmap_hour_weekday.png"),
  p_heatmap,
  width = 14,
  height = 7,
  dpi = 300
)

# ============================================================
# 7. BIỂU ĐỒ 5: PHÂN BỐ ĐIỂM ĐÓN
# ============================================================

set.seed(42)

location_sample <- uber_data %>%
  filter(
    !is.na(Lat),
    !is.na(Lon),
    Lat >= 40.5774,
    Lat <= 40.9176,
    Lon >= -74.1500,
    Lon <= -73.7004
  ) %>%
  slice_sample(
    n = min(100000, n())
  )

p_location <- ggplot(
  location_sample,
  aes(x = Lon, y = Lat)
) +
  geom_point(
    alpha = 0.15,
    size = 0.5
  ) +
  coord_fixed() +
  labs(
    title = "Phân bố điểm đón Uber tại New York City",
    subtitle = "Sample tối đa 100.000 điểm đón",
    x = "Longitude",
    y = "Latitude"
  ) +
  theme_minimal()

print(p_location)

ggsave(
  file.path(
    figure_path,
    "05_pickup_location_distribution.png"
  ),
  p_location,
  width = 9,
  height = 8,
  dpi = 300
)

# ============================================================
# 8. TỔNG HỢP KẾT QUẢ
# ============================================================

cat("\n========================================\n")
cat("        KẾT QUẢ VISUALIZATION\n")
cat("========================================\n")

cat(
  "Tổng số chuyến:",
  format(nrow(uber_data), big.mark = ","),
  "\n"
)

cat("\nGiờ có nhiều chuyến nhất:\n")
print(
  trips_by_hour %>%
    slice_max(Total_Trips, n = 1)
)

cat("\nTháng có nhiều chuyến nhất:\n")
print(
  trips_by_month %>%
    slice_max(Total_Trips, n = 1)
)

cat("\nThứ có nhiều chuyến nhất:\n")
print(
  trips_by_weekday %>%
    slice_max(Total_Trips, n = 1)
)

cat("\nCác biểu đồ đã được lưu tại:\n")
cat(figure_path, "\n")

cat("\nHoàn thành!\n")
