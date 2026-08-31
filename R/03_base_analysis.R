# ==========================================
# Uber Data Analysis Project
# File: 03_base_analysis.R
# Author: TV3
# Purpose: Analyze Uber trips by Base
# ==========================================

# 1. LOAD LIBRARIES & CLEAN DATA
source("R/00_setup.R")
uber_data <- read.csv("output/results/uber_clean.csv")

# Create output folder if it does not exist
dir.create("output/results", recursive = TRUE, showWarnings = FALSE)


# ==========================================
# 2. CHECK BASE COLUMN
# ==========================================

if (!"Base" %in% names(uber_data)) {
  stop("Column 'Base' was not found in uber_clean.csv")
}

# Remove rows with missing or empty Base
base_data <- uber_data %>%
  filter(!is.na(Base), Base != "")


# ==========================================
# 3. ANALYSIS BY BASE
# ==========================================

trips_by_base <- base_data %>%
  group_by(Base) %>%
  summarise(
    Total_Trips = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(Total_Trips)) %>%
  mutate(
    Percentage = round(
      Total_Trips / sum(Total_Trips) * 100,
      2
    )
  )

print("=== BẢNG SỐ CHUYẾN ĐI THEO BASE ===")
print(trips_by_base)


# ==========================================
# 4. BASE WITH MOST / LEAST TRIPS
# ==========================================

most_active_base <- trips_by_base %>%
  slice_max(
    order_by = Total_Trips,
    n = 1,
    with_ties = FALSE
  )

least_active_base <- trips_by_base %>%
  slice_min(
    order_by = Total_Trips,
    n = 1,
    with_ties = FALSE
  )

cat("\n=== BASE HOẠT ĐỘNG NHIỀU NHẤT ===\n")
print(most_active_base)

cat("\n=== BASE HOẠT ĐỘNG ÍT NHẤT ===\n")
print(least_active_base)


# ==========================================
# 5. BASE ANALYSIS BY MONTH
# ==========================================

if ("Month" %in% names(base_data)) {

  trips_by_base_month <- base_data %>%
    group_by(Base, Month) %>%
    summarise(
      Total_Trips = n(),
      .groups = "drop"
    ) %>%
    arrange(
      Base,
      match(
        Month,
        c("Apr", "May", "Jun", "Jul", "Aug", "Sep")
      )
    )

  cat("\n=== SỐ CHUYẾN CỦA TỪNG BASE THEO THÁNG ===\n")
  print(trips_by_base_month)

  write.csv(
    trips_by_base_month,
    "output/results/trips_by_base_month.csv",
    row.names = FALSE
  )
}


# ==========================================
# 6. BASE ANALYSIS BY WEEKDAY
# ==========================================

if ("Weekday" %in% names(base_data)) {

  trips_by_base_weekday <- base_data %>%
    group_by(Base, Weekday) %>%
    summarise(
      Total_Trips = n(),
      .groups = "drop"
    ) %>%
    arrange(
      Base,
      match(
        Weekday,
        c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
      )
    )

  cat("\n=== SỐ CHUYẾN CỦA TỪNG BASE THEO THỨ ===\n")
  print(trips_by_base_weekday)

  write.csv(
    trips_by_base_weekday,
    "output/results/trips_by_base_weekday.csv",
    row.names = FALSE
  )
}


# ==========================================
# 7. EXPORT MAIN RESULTS
# ==========================================

write.csv(
  trips_by_base,
  "output/results/trips_by_base.csv",
  row.names = FALSE
)

write.csv(
  most_active_base,
  "output/results/most_active_base.csv",
  row.names = FALSE
)

write.csv(
  least_active_base,
  "output/results/least_active_base.csv",
  row.names = FALSE
)


# ==========================================
# 8. SUMMARY
# ==========================================

cat("\n==========================================\n")
cat("BASE ANALYSIS SUMMARY\n")
cat("==========================================\n")

cat(
  "Tổng số Base:",
  nrow(trips_by_base),
  "\n"
)

cat(
  "Base hoạt động nhiều nhất:",
  most_active_base$Base,
  "-",
  most_active_base$Total_Trips,
  "chuyến (",
  most_active_base$Percentage,
  "% )\n"
)

cat(
  "Base hoạt động ít nhất:",
  least_active_base$Base,
  "-",
  least_active_base$Total_Trips,
  "chuyến (",
  least_active_base$Percentage,
  "% )\n"
)

cat(
  "\nBase analysis completed and results exported successfully!\n"
)
