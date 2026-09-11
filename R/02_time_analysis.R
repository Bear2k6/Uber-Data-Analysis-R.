# ==========================================
# Uber Data Analysis Project
# File: 02_time_analysis.R
# Purpose: Analyze Uber trip patterns over time
# ==========================================

source("R/00_setup.R")

# ==========================================
# 1. LOAD CLEAN DATA
# ==========================================

clean_file <- "output/results/uber_clean.csv"
if (!file.exists(clean_file)) {
  stop("uber_clean.csv not found. Run 01_data_cleaning.R first.")
}

cat("Loading cleaned dataset...\n")
uber_data <- readr::read_csv(
  clean_file,
  col_types = readr::cols(
    `Date/Time` = readr::col_character(),
    Lat         = readr::col_double(),
    Lon         = readr::col_double(),
    Base        = readr::col_character(),
    Hour        = readr::col_integer(),
    Day         = readr::col_integer(),
    Date        = readr::col_date(),
    Month       = readr::col_character(),
    Weekday     = readr::col_character(),
    DayType     = readr::col_character()
  ),
  show_col_types = FALSE
)

# Re-apply factor levels so ordering is correct
month_levels   <- c("Apr", "May", "Jun", "Jul", "Aug", "Sep")
weekday_levels <- c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

uber_data$Month   <- factor(uber_data$Month,   levels = month_levels)
uber_data$Weekday <- factor(uber_data$Weekday, levels = weekday_levels)

cat("Rows loaded:", format(nrow(uber_data), big.mark = ","), "\n")

# ==========================================
# 2. TRIPS BY HOUR
# ==========================================

trips_by_hour <- uber_data %>%
  group_by(Hour) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  arrange(Hour)

cat("\n=== TRIPS BY HOUR ===\n")
print(trips_by_hour)

# ==========================================
# 3. TRIPS BY DATE (daily)
# ==========================================

trips_by_date <- uber_data %>%
  group_by(Date) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  arrange(Date)

busiest_date <- trips_by_date %>%
  slice_max(Total_Trips, n = 1, with_ties = FALSE)

cat("\n=== BUSIEST DATE ===\n")
print(busiest_date)

# ==========================================
# 4. TRIPS BY DAY OF MONTH
# ==========================================

trips_by_day <- uber_data %>%
  group_by(Day) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  arrange(Day)

cat("\n=== TRIPS BY DAY OF MONTH ===\n")
print(trips_by_day)

# ==========================================
# 5. TRIPS BY MONTH
# ==========================================

trips_by_month <- uber_data %>%
  group_by(Month) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  arrange(Month)

cat("\n=== TRIPS BY MONTH ===\n")
print(trips_by_month)

# ==========================================
# 6. TRIPS BY WEEKDAY
# ==========================================

trips_by_weekday <- uber_data %>%
  group_by(Weekday) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  arrange(Weekday)

cat("\n=== TRIPS BY WEEKDAY ===\n")
print(trips_by_weekday)

# ==========================================
# 7. WEEKDAY VS WEEKEND
# ==========================================

trips_by_day_type <- uber_data %>%
  group_by(DayType) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  arrange(desc(Total_Trips))

cat("\n=== WEEKDAY VS WEEKEND ===\n")
print(trips_by_day_type)

# ==========================================
# 8. HOUR × DAYTYPE
# ==========================================

trips_by_hour_daytype <- uber_data %>%
  group_by(DayType, Hour) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  arrange(DayType, Hour)

cat("\n=== TRIPS BY HOUR × DAYTYPE ===\n")
print(trips_by_hour_daytype)

# ==========================================
# 9. HOUR × WEEKDAY HEATMAP DATA
# ==========================================

trips_by_hour_weekday <- uber_data %>%
  group_by(Weekday, Hour) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  arrange(Weekday, Hour)

# ==========================================
# 10. AVERAGE DAILY TRIPS BY DAYTYPE
# ==========================================

avg_by_daytype <- uber_data %>%
  group_by(Date, DayType) %>%
  summarise(Daily_Trips = n(), .groups = "drop") %>%
  group_by(DayType) %>%
  summarise(
    Num_Days             = n(),
    Avg_Trips_Per_Day    = round(mean(Daily_Trips), 0),
    Median_Trips_Per_Day = round(median(Daily_Trips), 0),
    .groups = "drop"
  )

cat("\n=== AVG DAILY TRIPS BY DAYTYPE ===\n")
print(avg_by_daytype)

# ==========================================
# 11. EXPORT RESULTS
# ==========================================

readr::write_csv(trips_by_hour,         "output/results/trips_by_hour.csv")
readr::write_csv(trips_by_date,         "output/results/trips_by_date.csv")
readr::write_csv(trips_by_day,          "output/results/trips_by_day.csv")
readr::write_csv(trips_by_month,        "output/results/trips_by_month.csv")
readr::write_csv(trips_by_weekday,      "output/results/trips_by_weekday.csv")
readr::write_csv(trips_by_day_type,     "output/results/trips_by_day_type.csv")
readr::write_csv(trips_by_hour_daytype, "output/results/trips_by_hour_daytype.csv")
readr::write_csv(trips_by_hour_weekday, "output/results/trips_by_hour_weekday.csv")
readr::write_csv(avg_by_daytype,        "output/results/avg_by_daytype.csv")

cat("\n02_time_analysis.R completed successfully.\n")
cat("Results exported to output/results/\n")