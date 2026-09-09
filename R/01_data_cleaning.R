# ==========================================
# Uber Data Analysis Project
# File: 01_data_cleaning.R
# Purpose: Load, clean, validate and export Uber data
# ==========================================

source("R/00_setup.R")

# ==========================================
# 1. READ RAW CSV FILES
# ==========================================

data_files <- list(
  apr = "Data/uber-raw-data-apr14.csv",
  may = "Data/uber-raw-data-may14.csv",
  jun = "Data/uber-raw-data-jun14.csv",
  jul = "Data/uber-raw-data-jul14.csv",
  aug = "Data/uber-raw-data-aug14.csv",
  sep = "Data/uber-raw-data-sep14.csv"
)

# Verify all files exist before reading
missing_files <- data_files[!file.exists(unlist(data_files))]
if (length(missing_files) > 0) {
  stop(paste(
    "Missing data files:",
    paste(unlist(missing_files), collapse = ", ")
  ))
}

cat("Reading 6 raw CSV files...\n")

read_uber_csv <- function(path) {
  df <- readr::read_csv(
    path,
    col_types = readr::cols(
      `Date/Time` = readr::col_character(),
      Lat         = readr::col_double(),
      Lon         = readr::col_double(),
      Base        = readr::col_character()
    ),
    show_col_types = FALSE
  )
  return(df)
}

apr <- read_uber_csv(data_files$apr)
may <- read_uber_csv(data_files$may)
jun <- read_uber_csv(data_files$jun)
jul <- read_uber_csv(data_files$jul)
aug <- read_uber_csv(data_files$aug)
sep <- read_uber_csv(data_files$sep)

# ==========================================
# 2. PER-FILE DIMENSION CHECK
# ==========================================

cat("\n===== PER-FILE DIMENSIONS =====\n")
file_dims <- data.frame(
  File  = names(data_files),
  Rows  = c(nrow(apr), nrow(may), nrow(jun), nrow(jul), nrow(aug), nrow(sep)),
  Cols  = c(ncol(apr), ncol(may), ncol(jun), ncol(jul), ncol(aug), ncol(sep))
)
print(file_dims)

# ==========================================
# 3. COMBINE ALL DATASETS
# ==========================================

uber_data <- dplyr::bind_rows(apr, may, jun, jul, aug, sep)
rm(apr, may, jun, jul, aug, sep)  # free memory

cat("\nTotal rows after combining:", format(nrow(uber_data), big.mark = ","), "\n")
cat("Total columns:", ncol(uber_data), "\n")

# ==========================================
# 4. VALIDATE REQUIRED COLUMNS
# ==========================================

required_cols <- c("Date/Time", "Lat", "Lon", "Base")
missing_cols <- setdiff(required_cols, names(uber_data))
if (length(missing_cols) > 0) {
  stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")))
}

cat("\n===== COLUMN NAMES =====\n")
print(names(uber_data))

cat("\n===== DATA TYPES =====\n")
str(uber_data)

# ==========================================
# 5. CHECK MISSING VALUES
# ==========================================

missing_values <- colSums(is.na(uber_data))
cat("\n===== MISSING VALUES =====\n")
print(missing_values)

# ==========================================
# 6. CHECK DUPLICATED ROWS (report only, do not remove)
# ==========================================

duplicate_count <- sum(duplicated(uber_data))
cat("\n===== DUPLICATE ROWS =====\n")
cat("Duplicated rows detected:", format(duplicate_count, big.mark = ","), "\n")
cat("NOTE: Duplicates are reported only, not removed.\n")

# ==========================================
# 7. VALIDATE LAT/LON RANGES
# ==========================================

invalid_lat <- sum(!is.na(uber_data$Lat) & (uber_data$Lat < -90 | uber_data$Lat > 90))
invalid_lon <- sum(!is.na(uber_data$Lon) & (uber_data$Lon < -180 | uber_data$Lon > 180))
cat("\n===== LAT/LON VALIDATION =====\n")
cat("Invalid Latitude values  :", invalid_lat, "\n")
cat("Invalid Longitude values :", invalid_lon, "\n")

# NYC bounding box check
nyc_count <- sum(
  !is.na(uber_data$Lat) & !is.na(uber_data$Lon) &
  uber_data$Lat >= 40.5774 & uber_data$Lat <= 40.9176 &
  uber_data$Lon >= -74.1500 & uber_data$Lon <= -73.7004
)
cat("Points within NYC bounding box:", format(nyc_count, big.mark = ","), "\n")

# ==========================================
# 8. PARSE DATE/TIME
# ==========================================

cat("\nParsing Date/Time column...\n")
uber_data$datetime_parsed <- lubridate::mdy_hms(uber_data$`Date/Time`)

parse_failures <- sum(is.na(uber_data$datetime_parsed))
if (parse_failures > 0) {
  warning(paste(
    parse_failures,
    "rows failed Date/Time parsing. These rows will have NA time features."
  ))
}

# ==========================================
# 9. CREATE TIME FEATURES
# ==========================================

uber_data$Hour    <- lubridate::hour(uber_data$datetime_parsed)
uber_data$Day     <- lubridate::day(uber_data$datetime_parsed)
uber_data$Date    <- as.Date(uber_data$datetime_parsed)

uber_data$Month   <- lubridate::month(
  uber_data$datetime_parsed,
  label = TRUE,
  abbr  = TRUE
)

uber_data$Weekday <- lubridate::wday(
  uber_data$datetime_parsed,
  label = TRUE,
  abbr  = TRUE,
  week_start = 1  # Monday = 1
)

# DayType: Sun=1, Sat=7 in default wday; with week_start=1: Sat=6, Sun=7
uber_data$DayType <- ifelse(
  lubridate::wday(uber_data$datetime_parsed, week_start = 1) >= 6,
  "Weekend",
  "Weekday"
)

# Drop helper column
uber_data$datetime_parsed <- NULL

# ==========================================
# 10. FINAL VALIDATION
# ==========================================

cat("\n===== FINAL DATASET SUMMARY =====\n")
cat("Rows   :", format(nrow(uber_data), big.mark = ","), "\n")
cat("Columns:", ncol(uber_data), "\n")

cat("\n===== FINAL MISSING VALUES =====\n")
print(colSums(is.na(uber_data)))

cat("\n===== SAMPLE ROWS =====\n")
print(head(uber_data, 5))

# ==========================================
# 11. EXPORT CLEAN DATASET
# ==========================================

output_path <- "Output/results/uber_clean.csv"

readr::write_csv(uber_data, output_path)

cat(paste("\nClean dataset exported to:", output_path, "\n"))
cat(paste("Total rows:", format(nrow(uber_data), big.mark = ","), "\n"))
cat("01_data_cleaning.R completed successfully.\n")