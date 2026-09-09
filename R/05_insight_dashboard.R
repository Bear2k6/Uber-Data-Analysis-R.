# ==========================================
# Uber Data Analysis Project
# File: 05_insight_dashboard.R
# Purpose: Compute and export key insights from analysis results
# ==========================================

source("R/00_setup.R")

# ==========================================
# HELPER: LOAD RESULT CSV
# ==========================================

load_result <- function(filename) {
  path <- file.path("Output/results", filename)
  if (!file.exists(path)) {
    stop(paste("Required file not found:", path,
               "\nRun preceding analysis scripts first."))
  }
  readr::read_csv(path, show_col_types = FALSE)
}

# ==========================================
# 1. LOAD PRE-COMPUTED AGGREGATES
# ==========================================

trips_by_hour     <- load_result("trips_by_hour.csv")
trips_by_month    <- load_result("trips_by_month.csv")
trips_by_weekday  <- load_result("trips_by_weekday.csv")
trips_by_base     <- load_result("trips_by_base.csv")
trips_by_daytype  <- load_result("trips_by_day_type.csv")
avg_by_daytype    <- load_result("avg_by_daytype.csv")
top20_hotspots    <- load_result("top20_hotspots.csv")
trips_by_date     <- load_result("trips_by_date.csv")

trips_by_month$Month   <- factor(trips_by_month$Month,
  levels = c("Apr", "May", "Jun", "Jul", "Aug", "Sep"))
trips_by_weekday$Weekday <- factor(trips_by_weekday$Weekday,
  levels = c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"))

# ==========================================
# 2. COMPUTE KEY METRICS
# ==========================================

total_trips <- sum(trips_by_hour$Total_Trips)

# Peak Hour
peak_hour_row <- trips_by_hour %>%
  slice_max(Total_Trips, n = 1, with_ties = FALSE)
peak_hour       <- peak_hour_row$Hour
peak_hour_trips <- peak_hour_row$Total_Trips

# Off-Peak Hour
off_peak_hour_row <- trips_by_hour %>%
  slice_min(Total_Trips, n = 1, with_ties = FALSE)
off_peak_hour       <- off_peak_hour_row$Hour
off_peak_hour_trips <- off_peak_hour_row$Total_Trips

# Peak Month
peak_month_row <- trips_by_month %>%
  slice_max(Total_Trips, n = 1, with_ties = FALSE)
peak_month       <- as.character(peak_month_row$Month)
peak_month_trips <- peak_month_row$Total_Trips

# Monthly growth: April → September
apr_trips <- trips_by_month %>%
  filter(as.character(Month) == "Apr") %>%
  pull(Total_Trips)
sep_trips <- trips_by_month %>%
  filter(as.character(Month) == "Sep") %>%
  pull(Total_Trips)
monthly_growth_pct <- round((sep_trips / apr_trips - 1) * 100, 1)

# Peak Weekday
peak_weekday_row <- trips_by_weekday %>%
  slice_max(Total_Trips, n = 1, with_ties = FALSE)
peak_weekday       <- as.character(peak_weekday_row$Weekday)
peak_weekday_trips <- peak_weekday_row$Total_Trips

# Top Base / Lowest Base
top_base    <- trips_by_base %>% slice_max(Total_Trips, n = 1, with_ties = FALSE)
lowest_base <- trips_by_base %>% slice_min(Total_Trips, n = 1, with_ties = FALSE)

# Weekday vs Weekend
weekday_total  <- trips_by_daytype %>%
  filter(DayType == "Weekday") %>% pull(Total_Trips)
weekend_total  <- trips_by_daytype %>%
  filter(DayType == "Weekend") %>% pull(Total_Trips)
weekday_pct    <- round(weekday_total / total_trips * 100, 1)
weekend_pct    <- round(weekend_total / total_trips * 100, 1)

weekday_avg    <- avg_by_daytype %>%
  filter(DayType == "Weekday") %>% pull(Avg_Trips_Per_Day)
weekend_avg    <- avg_by_daytype %>%
  filter(DayType == "Weekend") %>% pull(Avg_Trips_Per_Day)
weekday_vs_weekend_pct <- round((weekday_avg / weekend_avg - 1) * 100, 1)

# Top hotspot
top_hotspot <- top20_hotspots %>% slice_head(n = 1)

# Average trips per day
avg_trips_per_day <- round(mean(trips_by_date$Total_Trips), 0)

# Busiest date
busiest_date_row <- trips_by_date %>%
  slice_max(Total_Trips, n = 1, with_ties = FALSE)

# ==========================================
# 3. BUILD INSIGHTS TABLE
# ==========================================

insights_df <- data.frame(
  Metric = c(
    "Total Trips",
    "Average Trips Per Day",
    "Busiest Date",
    "Busiest Date Trips",
    "Peak Hour",
    "Peak Hour Trips",
    "Off Peak Hour",
    "Off Peak Hour Trips",
    "Peak Month",
    "Peak Month Trips",
    "Monthly Growth Apr to Sep (%)",
    "Peak Weekday",
    "Peak Weekday Trips",
    "Weekday Total Trips",
    "Weekend Total Trips",
    "Weekday Share (%)",
    "Weekend Share (%)",
    "Weekday Avg Trips Per Day",
    "Weekend Avg Trips Per Day",
    "Weekday vs Weekend Avg Pct Higher",
    "Top Base",
    "Top Base Trips",
    "Top Base Share (%)",
    "Lowest Base",
    "Lowest Base Trips",
    "Top Hotspot Latitude",
    "Top Hotspot Longitude",
    "Top Hotspot Trips"
  ),
  Value = c(
    total_trips,
    avg_trips_per_day,
    as.character(busiest_date_row$Date),
    busiest_date_row$Total_Trips,
    peak_hour,
    peak_hour_trips,
    off_peak_hour,
    off_peak_hour_trips,
    peak_month,
    peak_month_trips,
    monthly_growth_pct,
    peak_weekday,
    peak_weekday_trips,
    weekday_total,
    weekend_total,
    weekday_pct,
    weekend_pct,
    weekday_avg,
    weekend_avg,
    weekday_vs_weekend_pct,
    top_base$Base,
    top_base$Total_Trips,
    top_base$Percentage,
    lowest_base$Base,
    lowest_base$Total_Trips,
    top_hotspot$Latitude,
    top_hotspot$Longitude,
    top_hotspot$Trips
  ),
  stringsAsFactors = FALSE
)

# ==========================================
# 4. PRINT INSIGHTS
# ==========================================

cat("\n==========================================\n")
cat("KEY INSIGHTS — UBER NYC 2014\n")
cat("==========================================\n")

cat("Total Trips              :", scales::comma(total_trips), "\n")
cat("Average Trips / Day      :", scales::comma(avg_trips_per_day), "\n")
cat("Busiest Date             :", as.character(busiest_date_row$Date),
    "(", scales::comma(busiest_date_row$Total_Trips), "trips)\n")
cat("\nPeak Hour                :", paste0(peak_hour, ":00"),
    "(", scales::comma(peak_hour_trips), "trips)\n")
cat("Off-Peak Hour            :", paste0(off_peak_hour, ":00"),
    "(", scales::comma(off_peak_hour_trips), "trips)\n")
cat("\nPeak Month               :", peak_month,
    "(", scales::comma(peak_month_trips), "trips)\n")
cat("Monthly Growth Apr→Sep   :", monthly_growth_pct, "%\n")
cat("\nPeak Weekday             :", peak_weekday,
    "(", scales::comma(peak_weekday_trips), "trips)\n")
cat("\nWeekday Trips            :", scales::comma(weekday_total), "(", weekday_pct, "%)\n")
cat("Weekend Trips            :", scales::comma(weekend_total), "(", weekend_pct, "%)\n")
cat("Weekday Avg/Day          :", scales::comma(weekday_avg), "\n")
cat("Weekend Avg/Day          :", scales::comma(weekend_avg), "\n")
cat("Weekday vs Weekend higher:", weekday_vs_weekend_pct, "%\n")
cat("\nTop Base                 :", top_base$Base,
    "(", scales::comma(top_base$Total_Trips), "trips,", top_base$Percentage, "%)\n")
cat("Lowest Base              :", lowest_base$Base,
    "(", scales::comma(lowest_base$Total_Trips), "trips,", lowest_base$Percentage, "%)\n")
cat("\nTop Hotspot              : Lat =", top_hotspot$Latitude,
    " Lon =", top_hotspot$Longitude,
    " (", scales::comma(top_hotspot$Trips), "trips)\n")

# ==========================================
# 5. EXPORT
# ==========================================

readr::write_csv(insights_df, "Output/results/insights.csv")

cat("\n05_insight_dashboard.R completed successfully.\n")
cat("Insights exported to Output/results/insights.csv\n")
