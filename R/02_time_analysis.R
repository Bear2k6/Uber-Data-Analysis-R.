# ==========================================
# Uber Data Analysis Project
# File: 02_time_analysis.R
# Author: TV2
# Purpose: Analyze Uber trip patterns over time
# ==========================================

# ==========================================
# 1. LOAD LIBRARIES & CLEAN DATA
# ==========================================

source("R/00_setup.R")

uber_data <- read.csv(
  "Output/results/uber_clean.csv",
  check.names = FALSE
)

# Convert Date/Time again after reading CSV
uber_data$`Date/Time` <- lubridate::mdy_hms(
  uber_data$`Date/Time`
)

# ==========================================
# 2. CREATE DATE
# ==========================================

uber_data$Date <- as.Date(
  uber_data$`Date/Time`
)

# ==========================================
# 3. CREATE WEEKDAY / WEEKEND
# ==========================================

uber_data$DayType <- ifelse(
  lubridate::wday(uber_data$`Date/Time`) %in% c(1, 7),
  "Weekend",
  "Weekday"
)

# ==========================================
# 4. ANALYSIS BY HOUR
# ==========================================

trips_by_hour <- uber_data %>%
  group_by(Hour) %>%
  summarise(
    Total_Trips = n(),
    .groups = "drop"
  ) %>%
  arrange(Hour)

cat("\n=== BẢNG SỐ CHUYẾN ĐI THEO GIỜ ===\n")
print(trips_by_hour)

# ==========================================
# 5. ANALYSIS BY DATE
# ==========================================

trips_by_date <- uber_data %>%
  group_by(Date) %>%
  summarise(
    Total_Trips = n(),
    .groups = "drop"
  ) %>%
  arrange(Date)

cat("\n=== BẢNG SỐ CHUYẾN ĐI THEO NGÀY ===\n")
print(head(trips_by_date, 20))

# ==========================================
# 6. ANALYSIS BY DAY OF MONTH
# ==========================================

trips_by_day <- uber_data %>%
  group_by(Day) %>%
  summarise(
    Total_Trips = n(),
    .groups = "drop"
  ) %>%
  arrange(Day)

cat("\n=== BẢNG SỐ CHUYẾN ĐI THEO NGÀY TRONG THÁNG ===\n")
print(trips_by_day)

# ==========================================
# 7. ANALYSIS BY WEEKDAY
# ==========================================

trips_by_weekday <- uber_data %>%
  group_by(Weekday) %>%
  summarise(
    Total_Trips = n(),
    .groups = "drop"
  ) %>%
  arrange(
    match(
      Weekday,
      c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
    )
  )

cat("\n=== BẢNG SỐ CHUYẾN ĐI THEO THỨ ===\n")
print(trips_by_weekday)

# ==========================================
# 8. WEEKDAY VS WEEKEND
# ==========================================

trips_by_day_type <- uber_data %>%
  group_by(DayType) %>%
  summarise(
    Total_Trips = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(Total_Trips))

cat("\n=== WEEKDAY VS WEEKEND ===\n")
print(trips_by_day_type)

# ==========================================
# 9. ANALYSIS BY MONTH
# ==========================================

trips_by_month <- uber_data %>%
  group_by(Month) %>%
  summarise(
    Total_Trips = n(),
    .groups = "drop"
  ) %>%
  arrange(
    match(
      Month,
      c("Apr", "May", "Jun", "Jul", "Aug", "Sep")
    )
  )

cat("\n=== BẢNG SỐ CHUYẾN ĐI THEO THÁNG ===\n")
print(trips_by_month)

# ==========================================
# 10. HOUR BY WEEKDAY/WEEKEND
# ==========================================

trips_by_hour_day_type <- uber_data %>%
  group_by(DayType, Hour) %>%
  summarise(
    Total_Trips = n(),
    .groups = "drop"
  ) %>%
  arrange(DayType, Hour)

cat("\n=== SỐ CHUYẾN THEO GIỜ VÀ DAY TYPE ===\n")
print(trips_by_hour_day_type)

# ==========================================
# 11. EXPORT RESULTS
# ==========================================

write.csv(
  trips_by_hour,
  "Output/results/trips_by_hour.csv",
  row.names = FALSE
)

write.csv(
  trips_by_date,
  "Output/results/trips_by_date.csv",
  row.names = FALSE
)

write.csv(
  trips_by_day,
  "Output/results/trips_by_day.csv",
  row.names = FALSE
)

write.csv(
  trips_by_weekday,
  "Output/results/trips_by_weekday.csv",
  row.names = FALSE
)

write.csv(
  trips_by_day_type,
  "Output/results/trips_by_day_type.csv",
  row.names = FALSE
)

write.csv(
  trips_by_month,
  "Output/results/trips_by_month.csv",
  row.names = FALSE
)

write.csv(
  trips_by_hour_day_type,
  "Output/results/trips_by_hour_day_type.csv",
  row.names = FALSE
)

cat(
  "\nTime analysis completed and results exported successfully!\n"
)