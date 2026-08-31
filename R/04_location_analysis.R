# ==========================================
# Uber Data Analysis Project
# File: 04_location_analysis.R
# Author: TV3
# Purpose: Analyze geographic distribution
#          of Uber pickup locations
# ==========================================

# 1. LOAD LIBRARIES & CLEAN DATA
source("R/00_setup.R")
uber_data <- read.csv("output/results/uber_clean.csv")

# Create output folder if it does not exist
dir.create("output/results", recursive = TRUE, showWarnings = FALSE)


# ==========================================
# 2. CHECK LOCATION COLUMNS
# ==========================================

required_columns <- c("Lat", "Lon")

missing_columns <- setdiff(
  required_columns,
  names(uber_data)
)

if (length(missing_columns) > 0) {

  stop(
    paste(
      "Missing required columns:",
      paste(missing_columns, collapse = ", ")
    )
  )
}


# ==========================================
# 3. CONVERT COORDINATES TO NUMERIC
# ==========================================

uber_data$Lat <- suppressWarnings(
  as.numeric(uber_data$Lat)
)

uber_data$Lon <- suppressWarnings(
  as.numeric(uber_data$Lon)
)


# ==========================================
# 4. CHECK COORDINATE QUALITY
# ==========================================

missing_lat <- sum(is.na(uber_data$Lat))
missing_lon <- sum(is.na(uber_data$Lon))

invalid_lat <- sum(
  !is.na(uber_data$Lat) &
    (uber_data$Lat < -90 | uber_data$Lat > 90)
)

invalid_lon <- sum(
  !is.na(uber_data$Lon) &
    (uber_data$Lon < -180 | uber_data$Lon > 180)
)

coordinate_quality <- data.frame(

  Metric = c(
    "Missing Latitude",
    "Missing Longitude",
    "Invalid Latitude",
    "Invalid Longitude"
  ),

  Count = c(
    missing_lat,
    missing_lon,
    invalid_lat,
    invalid_lon
  )
)

cat("\n=== KIỂM TRA CHẤT LƯỢNG TỌA ĐỘ ===\n")
print(coordinate_quality)


# ==========================================
# 5. FILTER VALID COORDINATES
# ==========================================

valid_location_data <- uber_data %>%

  filter(
    !is.na(Lat),
    !is.na(Lon),

    Lat >= -90,
    Lat <= 90,

    Lon >= -180,
    Lon <= 180
  )

cat(
  "\nSố dòng có tọa độ hợp lệ:",
  nrow(valid_location_data),
  "\n"
)


# ==========================================
# 6. FILTER NEW YORK CITY AREA
# ==========================================

# Broad bounding box for New York City area
#
# Latitude:
# 40.5774 -> 40.9176
#
# Longitude:
# -74.1500 -> -73.7004

nyc_location_data <- valid_location_data %>%

  filter(
    Lat >= 40.5774,
    Lat <= 40.9176,

    Lon >= -74.1500,
    Lon <= -73.7004
  )

cat(
  "Số chuyến nằm trong khu vực NYC:",
  nrow(nyc_location_data),
  "\n"
)


# ==========================================
# 7. LOCATION SUMMARY
# ==========================================

percentage_inside_nyc <- round(
  nrow(nyc_location_data) /
    nrow(valid_location_data) *
    100,
  2
)

location_summary <- data.frame(

  Metric = c(
    "Total Records",
    "Valid Coordinates",
    "Records inside NYC area",
    "Percentage inside NYC (%)",
    "Minimum Latitude",
    "Maximum Latitude",
    "Minimum Longitude",
    "Maximum Longitude",
    "Median Latitude",
    "Median Longitude"
  ),

  Value = c(
    nrow(uber_data),

    nrow(valid_location_data),

    nrow(nyc_location_data),

    percentage_inside_nyc,

    min(
      nyc_location_data$Lat,
      na.rm = TRUE
    ),

    max(
      nyc_location_data$Lat,
      na.rm = TRUE
    ),

    min(
      nyc_location_data$Lon,
      na.rm = TRUE
    ),

    max(
      nyc_location_data$Lon,
      na.rm = TRUE
    ),

    median(
      nyc_location_data$Lat,
      na.rm = TRUE
    ),

    median(
      nyc_location_data$Lon,
      na.rm = TRUE
    )
  )
)

cat("\n=== THỐNG KÊ LOCATION ===\n")
print(location_summary)


# ==========================================
# 8. CREATE LOCATION GRID
# ==========================================

# Round coordinates to 2 decimal places.
# Each grid cell represents approximately
# a small geographic area in NYC.

location_grid <- nyc_location_data %>%

  mutate(

    Lat_Grid = round(
      Lat,
      digits = 2
    ),

    Lon_Grid = round(
      Lon,
      digits = 2
    )
  ) %>%

  group_by(
    Lat_Grid,
    Lon_Grid
  ) %>%

  summarise(
    Total_Trips = n(),
    .groups = "drop"
  ) %>%

  arrange(
    desc(Total_Trips)
  )


# ==========================================
# 9. CALCULATE HOTSPOT PERCENTAGE
# ==========================================

location_grid <- location_grid %>%

  mutate(

    Percentage = round(
      Total_Trips /
        sum(Total_Trips) *
        100,
      3
    )
  )


# ==========================================
# 10. TOP 20 PICKUP HOTSPOTS
# ==========================================

top20_hotspots <- location_grid %>%
  slice_head(n = 20)

cat("\n=== TOP 20 KHU VỰC CÓ NHIỀU PICKUP NHẤT ===\n")
print(top20_hotspots)


# ==========================================
# 11. LOCATION ANALYSIS BY BASE
# ==========================================

if ("Base" %in% names(nyc_location_data)) {

  location_by_base <- nyc_location_data %>%

    filter(
      !is.na(Base),
      Base != ""
    ) %>%

    group_by(
      Base
    ) %>%

    summarise(

      Total_Trips = n(),

      Mean_Latitude = mean(
        Lat,
        na.rm = TRUE
      ),

      Mean_Longitude = mean(
        Lon,
        na.rm = TRUE
      ),

      .groups = "drop"
    ) %>%

    arrange(
      desc(Total_Trips)
    )

  cat("\n=== LOCATION SUMMARY BY BASE ===\n")
  print(location_by_base)

  write.csv(
    location_by_base,
    "output/results/location_by_base.csv",
    row.names = FALSE
  )
}


# ==========================================
# 12. CREATE SAMPLE FOR VISUALIZATION
# ==========================================

# The dataset contains millions of rows.
# Drawing every point can make RStudio slow.
# Therefore, create a reproducible sample
# for visualization in 05_visualization.R.

set.seed(42)

sample_size <- min(
  100000,
  nrow(nyc_location_data)
)

location_sample <- nyc_location_data %>%
  slice_sample(
    n = sample_size
  )

cat(
  "\nSố điểm được lấy mẫu cho visualization:",
  nrow(location_sample),
  "\n"
)


# ==========================================
# 13. EXPORT RESULTS
# ==========================================

write.csv(
  coordinate_quality,
  "output/results/coordinate_quality.csv",
  row.names = FALSE
)

write.csv(
  location_summary,
  "output/results/location_summary.csv",
  row.names = FALSE
)

write.csv(
  location_grid,
  "output/results/location_grid_counts.csv",
  row.names = FALSE
)

write.csv(
  top20_hotspots,
  "output/results/top20_location_hotspots.csv",
  row.names = FALSE
)

write.csv(
  location_sample,
  "output/results/location_sample.csv",
  row.names = FALSE
)


# ==========================================
# 14. FINAL SUMMARY
# ==========================================

cat("\n==========================================\n")
cat("LOCATION ANALYSIS SUMMARY\n")
cat("==========================================\n")

cat(
  "Tổng số bản ghi:",
  nrow(uber_data),
  "\n"
)

cat(
  "Tọa độ hợp lệ:",
  nrow(valid_location_data),
  "\n"
)

cat(
  "Số bản ghi trong khu vực NYC:",
  nrow(nyc_location_data),
  "\n"
)

cat(
  "Tỷ lệ tọa độ nằm trong NYC:",
  percentage_inside_nyc,
  "%\n"
)

cat(
  "Số khu vực grid được phát hiện:",
  nrow(location_grid),
  "\n"
)

cat(
  "\nLocation analysis completed and results exported successfully!\n"
)
