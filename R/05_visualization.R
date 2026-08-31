# ============================================================
# 05_visualization.R
# UBER DATA ANALYSIS - VISUALIZATION & HEATMAP
# ============================================================

if (!require(ggplot2)) install.packages("ggplot2")
if (!require(dplyr)) install.packages("dplyr")
if (!require(scales)) install.packages("scales")

library(ggplot2)
library(dplyr)
library(scales)

files <- list.files("Data", pattern = "uber-raw-data-.*\\.csv$", full.names = TRUE)
cat("Số file dữ liệu:", length(files), "\n")

uber_data <- bind_rows(lapply(files, function(file) {
  data <- read.csv(file, stringsAsFactors = FALSE)
  data$Month <- substr(basename(file), 16, 18)
  data
}))

cat("Tổng số chuyến:", format(nrow(uber_data), big.mark = ","), "\n")

uber_data$Date.Time <- as.POSIXct(uber_data$Date.Time, format = "%m/%d/%Y %H:%M:%S")
uber_data$Hour <- as.integer(format(uber_data$Date.Time, "%H"))
uber_data$Weekday <- weekdays(uber_data$Date.Time)

weekday_map <- c("Monday"="Mon", "Tuesday"="Tue", "Wednesday"="Wed", "Thursday"="Thu", "Friday"="Fri", "Saturday"="Sat", "Sunday"="Sun")
uber_data$Weekday <- factor(weekday_map[uber_data$Weekday], levels=c("Mon","Tue","Wed","Thu","Fri","Sat","Sun"))
uber_data$Month <- factor(uber_data$Month, levels=c("Apr","May","Jun","Jul","Aug","Sep"))

dir.create("output/figures", recursive=TRUE, showWarnings=FALSE)

hour_data <- uber_data %>% group_by(Hour) %>% summarise(Trips=n(), .groups="drop")
p1 <- ggplot(hour_data, aes(Hour, Trips)) + geom_col() + scale_x_continuous(breaks=0:23) + scale_y_continuous(labels=comma) + labs(title="Số lượng chuyến Uber theo giờ", subtitle="New York City - April to September 2014", x="Giờ trong ngày", y="Số chuyến") + theme_minimal()
print(p1)
ggsave("output/figures/01_trips_by_hour.png", p1, width=10, height=6, dpi=300)

month_data <- uber_data %>% group_by(Month) %>% summarise(Trips=n(), .groups="drop")
p2 <- ggplot(month_data, aes(Month, Trips)) + geom_col() + scale_y_continuous(labels=comma) + labs(title="Số lượng chuyến Uber theo tháng", subtitle="New York City - April to September 2014", x="Tháng", y="Số chuyến") + theme_minimal()
print(p2)
ggsave("output/figures/02_trips_by_month.png", p2, width=9, height=6, dpi=300)

weekday_data <- uber_data %>% group_by(Weekday) %>% summarise(Trips=n(), .groups="drop")
p3 <- ggplot(weekday_data, aes(Weekday, Trips)) + geom_col() + scale_y_continuous(labels=comma) + labs(title="Số lượng chuyến Uber theo thứ trong tuần", subtitle="New York City - April to September 2014", x="Thứ", y="Số chuyến") + theme_minimal()
print(p3)
ggsave("output/figures/03_trips_by_weekday.png", p3, width=9, height=6, dpi=300)

heatmap_data <- uber_data %>% group_by(Weekday, Hour) %>% summarise(Trips=n(), .groups="drop")
p4 <- ggplot(heatmap_data, aes(Hour, Weekday, fill=Trips)) + geom_tile(color="white") + scale_x_continuous(breaks=0:23) + scale_fill_gradient(low="white", high="red", labels=comma) + labs(title="Heatmap số lượng chuyến Uber theo giờ và thứ", subtitle="New York City - April to September 2014", x="Giờ trong ngày", y="Thứ trong tuần", fill="Số chuyến") + theme_minimal() + theme(axis.text.x=element_text(angle=45, hjust=1))
print(p4)
ggsave("output/figures/04_heatmap_hour_weekday.png", p4, width=14, height=7, dpi=300)

cat("\n========================================\nHOÀN THÀNH VISUALIZATION & HEATMAP\n========================================\n")
cat("Tổng số chuyến:", format(nrow(uber_data), big.mark=","), "\n")
cat("\nGiờ cao điểm:\n"); print(hour_data %>% slice_max(Trips, n=1))
cat("\nTháng có nhiều chuyến nhất:\n"); print(month_data %>% slice_max(Trips, n=1))
cat("\nThứ có nhiều chuyến nhất:\n"); print(weekday_data %>% slice_max(Trips, n=1))
cat("\n4 biểu đồ đã được lưu tại: output/figures/\n")
