# ==========================================
# Uber Data Analysis Project
# File: 02_time_analysis.R
# Author: TV2
# Purpose: Analyze Uber trip patterns over time
# ==========================================

# 1. LOAD LIBRARIES & CLEAN DATA
source("R/00_setup.R")
uber_data <- read.csv("output/results/uber_clean.csv")

# 2. ANALYSIS BY HOUR (Phân tích theo Giờ)
trips_by_hour <- uber_data %>%
  group_by(Hour) %>%
  summarise(Total_Trips = n()) %>%
  arrange(Hour)

print("Bảng số chuyển đi theo giờ")
print(trips_by_hour)

# 3. ANALYSIS BY DAY OF MONTH (Phân tích theo Ngày trong tháng)
trips_by_day <- uber_data %>%
  group_by(Day) %>%
  summarise(Total_Trips = n()) %>%
  arrange(Day)

print("=== BẢNG SỐ CHUYẾN ĐI THEO NGÀY TRONG THÁNG ===")
print(trips_by_day)

# 4. ANALYSIS BY WEEKDAY (Phân tích theo Thứ trong tuần)
trips_by_weekday <- uber_data %>%
  group_by(Weekday) %>%
  summarise(Total_Trips = n()) %>%
  arrange(match(Weekday, c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")))

print("Bảng số chuyển đi theo thứ")
print(trips_by_weekday)

# 5. ANALYSIS BY MONTH (Phân tích theo Tháng)
trips_by_month <- uber_data %>%
  group_by(Month) %>%
  summarise(Total_Trips = n()) %>%
  arrange(match(Month, c("Apr", "May", "Jun", "Jul", "Aug", "Sep")))

print("Bảng số chuyển đi theo tháng")
print(trips_by_month)

# 6. EXPORT RESULTS 
write.csv(trips_by_hour, "output/results/trips_by_hour.csv", row.names = FALSE)
write.csv(trips_by_day, "output/results/trips_by_day.csv", row.names = FALSE)
write.csv(trips_by_weekday, "output/results/trips_by_weekday.csv", row.names = FALSE)
write.csv(trips_by_month, "output/results/trips_by_month.csv", row.names = FALSE)

cat("\nTime analysis completed and results exported successfully!\n")
