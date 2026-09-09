# ==========================================
# Uber Data Analysis Project
# File: 03_base_analysis.R
# Purpose: Analyze Uber trips by Base
# ==========================================

source("R/00_setup.R")

# ==========================================
# 1. LOAD CLEAN DATA
# ==========================================

clean_file <- "Output/results/uber_clean.csv"
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

month_levels   <- c("Apr", "May", "Jun", "Jul", "Aug", "Sep")
weekday_levels <- c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

uber_data$Month   <- factor(uber_data$Month,   levels = month_levels)
uber_data$Weekday <- factor(uber_data$Weekday, levels = weekday_levels)

cat("Rows loaded:", format(nrow(uber_data), big.mark = ","), "\n")

# ==========================================
# 2. VALIDATE BASE COLUMN
# ==========================================

if (!"Base" %in% names(uber_data)) {
  stop("Column 'Base' not found in uber_clean.csv")
}

# Filter valid Base records
base_data <- uber_data %>%
  filter(!is.na(Base), trimws(Base) != "")

cat("Rows with valid Base:", format(nrow(base_data), big.mark = ","), "\n")

# ==========================================
# 3. TRIPS BY BASE
# ==========================================

trips_by_base <- base_data %>%
  group_by(Base) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  arrange(desc(Total_Trips)) %>%
  mutate(
    Rank       = row_number(),
    Percentage = round(Total_Trips / sum(Total_Trips) * 100, 2)
  ) %>%
  select(Rank, Base, Total_Trips, Percentage)

cat("\n=== TRIPS BY BASE ===\n")
print(trips_by_base)

# ==========================================
# 4. MOST / LEAST ACTIVE BASE
# ==========================================

most_active_base <- trips_by_base %>%
  slice_max(Total_Trips, n = 1, with_ties = FALSE)

least_active_base <- trips_by_base %>%
  slice_min(Total_Trips, n = 1, with_ties = FALSE)

cat("\n=== MOST ACTIVE BASE ===\n")
print(most_active_base)

cat("\n=== LEAST ACTIVE BASE ===\n")
print(least_active_base)

# ==========================================
# 5. TRIPS BY BASE × MONTH
# ==========================================

trips_by_base_month <- base_data %>%
  group_by(Base, Month) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  arrange(Base, Month)

cat("\n=== TRIPS BY BASE × MONTH ===\n")
print(trips_by_base_month)

# ==========================================
# 6. TRIPS BY BASE × WEEKDAY
# ==========================================

trips_by_base_weekday <- base_data %>%
  group_by(Base, Weekday) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  arrange(Base, Weekday)

cat("\n=== TRIPS BY BASE × WEEKDAY ===\n")
print(trips_by_base_weekday)

# ==========================================
# 7. EXPORT RESULTS
# ==========================================

readr::write_csv(trips_by_base,         "Output/results/trips_by_base.csv")
readr::write_csv(most_active_base,      "Output/results/most_active_base.csv")
readr::write_csv(least_active_base,     "Output/results/least_active_base.csv")
readr::write_csv(trips_by_base_month,   "Output/results/trips_by_base_month.csv")
readr::write_csv(trips_by_base_weekday, "Output/results/trips_by_base_weekday.csv")

# ==========================================
# 8. SUMMARY
# ==========================================

cat("\n==========================================\n")
cat("BASE ANALYSIS SUMMARY\n")
cat("==========================================\n")
cat("Total Bases       :", nrow(trips_by_base), "\n")
cat("Most active Base  :", most_active_base$Base,
    "-", format(most_active_base$Total_Trips, big.mark = ","),
    "trips (", most_active_base$Percentage, "%)\n")
cat("Least active Base :", least_active_base$Base,
    "-", format(least_active_base$Total_Trips, big.mark = ","),
    "trips (", least_active_base$Percentage, "%)\n")

cat("\n03_base_analysis.R completed successfully.\n")
cat("Results exported to Output/results/\n")
