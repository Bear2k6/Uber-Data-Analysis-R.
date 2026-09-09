# ==========================================
# Uber Data Analysis Project
# File: 03_location_analysis.R
# Purpose: Analyze geographic distribution of Uber pickups
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

uber_data$Month <- factor(uber_data$Month,
  levels = c("Apr", "May", "Jun", "Jul", "Aug", "Sep"))

cat("Rows loaded:", format(nrow(uber_data), big.mark = ","), "\n")

# ==========================================
# 2. VALIDATE LAT/LON COLUMNS
# ==========================================

required_cols <- c("Lat", "Lon")
missing_cols  <- setdiff(required_cols, names(uber_data))
if (length(missing_cols) > 0) {
  stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
}

# ==========================================
# 3. COORDINATE QUALITY CHECK
# ==========================================

missing_lat  <- sum(is.na(uber_data$Lat))
missing_lon  <- sum(is.na(uber_data$Lon))
invalid_lat  <- sum(!is.na(uber_data$Lat) & (uber_data$Lat < -90  | uber_data$Lat > 90))
invalid_lon  <- sum(!is.na(uber_data$Lon) & (uber_data$Lon < -180 | uber_data$Lon > 180))

coordinate_quality <- data.frame(
  Metric = c("Missing Latitude", "Missing Longitude",
             "Invalid Latitude", "Invalid Longitude"),
  Count  = c(missing_lat, missing_lon, invalid_lat, invalid_lon)
)

cat("\n=== COORDINATE QUALITY ===\n")
print(coordinate_quality)

# ==========================================
# 4. FILTER VALID COORDINATES
# ==========================================

valid_data <- uber_data %>%
  filter(
    !is.na(Lat), !is.na(Lon),
    Lat >= -90, Lat <= 90,
    Lon >= -180, Lon <= 180
  )

cat("Valid coordinate rows:", format(nrow(valid_data), big.mark = ","), "\n")

# ==========================================
# 5. FILTER TO NYC BOUNDING BOX
# ==========================================

# NYC bounding box (broad):
#   Latitude : 40.5774 – 40.9176
#   Longitude: -74.1500 – -73.7004

NYC_LAT_MIN <- 40.5774
NYC_LAT_MAX <- 40.9176
NYC_LON_MIN <- -74.1500
NYC_LON_MAX <- -73.7004

nyc_data <- valid_data %>%
  filter(
    Lat >= NYC_LAT_MIN, Lat <= NYC_LAT_MAX,
    Lon >= NYC_LON_MIN, Lon <= NYC_LON_MAX
  )

cat("Rows within NYC bounding box:", format(nrow(nyc_data), big.mark = ","), "\n")

# ==========================================
# 6. LOCATION SUMMARY STATISTICS
# ==========================================

pct_in_nyc <- round(nrow(nyc_data) / nrow(valid_data) * 100, 2)

location_summary <- data.frame(
  Metric = c(
    "Total Records",
    "Valid Coordinates",
    "Records inside NYC bbox",
    "Percentage inside NYC (%)",
    "Latitude Range Min",
    "Latitude Range Max",
    "Longitude Range Min",
    "Longitude Range Max",
    "Median Latitude",
    "Median Longitude"
  ),
  Value = c(
    nrow(uber_data),
    nrow(valid_data),
    nrow(nyc_data),
    pct_in_nyc,
    min(nyc_data$Lat,  na.rm = TRUE),
    max(nyc_data$Lat,  na.rm = TRUE),
    min(nyc_data$Lon,  na.rm = TRUE),
    max(nyc_data$Lon,  na.rm = TRUE),
    median(nyc_data$Lat, na.rm = TRUE),
    median(nyc_data$Lon, na.rm = TRUE)
  )
)

cat("\n=== LOCATION SUMMARY ===\n")
print(location_summary)

# ==========================================
# 7. CREATE 0.01-DEGREE GRID
# ==========================================

# Grid resolution: ~1 km cells
GRID_RES <- 0.01

location_grid <- nyc_data %>%
  mutate(
    Lat_Grid = round(Lat / GRID_RES) * GRID_RES,
    Lon_Grid = round(Lon / GRID_RES) * GRID_RES
  ) %>%
  group_by(Lat_Grid, Lon_Grid) %>%
  summarise(Total_Trips = n(), .groups = "drop") %>%
  arrange(desc(Total_Trips)) %>%
  mutate(Percentage = round(Total_Trips / sum(Total_Trips) * 100, 3))

cat("\nGrid cells created:", format(nrow(location_grid), big.mark = ","), "\n")

# ==========================================
# 8. TOP 20 HOTSPOTS
# ==========================================

top20_hotspots <- location_grid %>%
  slice_head(n = 20) %>%
  mutate(
    Rank      = row_number(),
    Latitude  = Lat_Grid,
    Longitude = Lon_Grid
  ) %>%
  select(Rank, Latitude, Longitude, Trips = Total_Trips)

cat("\n=== TOP 20 PICKUP HOTSPOTS ===\n")
print(top20_hotspots)

# ==========================================
# 9. LOCATION ANALYSIS BY BASE
# ==========================================

if ("Base" %in% names(nyc_data)) {
  location_by_base <- nyc_data %>%
    filter(!is.na(Base), trimws(Base) != "") %>%
    group_by(Base) %>%
    summarise(
      Total_Trips    = n(),
      Mean_Latitude  = round(mean(Lat, na.rm = TRUE), 4),
      Mean_Longitude = round(mean(Lon, na.rm = TRUE), 4),
      .groups = "drop"
    ) %>%
    arrange(desc(Total_Trips))

  cat("\n=== LOCATION SUMMARY BY BASE ===\n")
  print(location_by_base)

  readr::write_csv(location_by_base, "Output/results/location_by_base.csv")
}

# ==========================================
# 10. SAMPLE FOR VISUALIZATION (50k points)
# ==========================================

set.seed(42)
sample_size   <- min(50000, nrow(nyc_data))
location_sample <- nyc_data %>%
  slice_sample(n = sample_size)

cat("\nSample size for visualization:", format(nrow(location_sample), big.mark = ","), "\n")

# ==========================================
# 11. EXPORT RESULTS
# ==========================================

readr::write_csv(coordinate_quality, "Output/results/coordinate_quality.csv")
readr::write_csv(location_summary,   "Output/results/location_summary.csv")
readr::write_csv(location_grid,      "Output/results/location_grid_counts.csv")
readr::write_csv(top20_hotspots,     "Output/results/top20_hotspots.csv")
readr::write_csv(location_sample,    "Output/results/location_sample.csv")

# ==========================================
# 12. SUMMARY
# ==========================================

cat("\n==========================================\n")
cat("LOCATION ANALYSIS SUMMARY\n")
cat("==========================================\n")
cat("Total Records            :", format(nrow(uber_data), big.mark = ","), "\n")
cat("Valid Coordinates        :", format(nrow(valid_data), big.mark = ","), "\n")
cat("Inside NYC bbox          :", format(nrow(nyc_data),   big.mark = ","), "\n")
cat("Percentage inside NYC    :", pct_in_nyc, "%\n")
cat("Grid cells               :", format(nrow(location_grid), big.mark = ","), "\n")
cat("Top hotspot              : Lat =", top20_hotspots$Latitude[1],
    " Lon =", top20_hotspots$Longitude[1],
    " Trips =", format(top20_hotspots$Trips[1], big.mark = ","), "\n")

cat("\n03_location_analysis.R completed successfully.\n")
cat("Results exported to Output/results/\n")
