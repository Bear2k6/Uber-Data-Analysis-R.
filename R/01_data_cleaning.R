# ==========================================
# Uber Data Analysis Project
# File: 01_data_cleaning.R
# Author: TV1
# Purpose: Load, clean and transform Uber data
# ==========================================

source("R/00_setup.R")

# ==========================================
# 0. CREATE OUTPUT DIRECTORIES
# ==========================================

dir.create(
  "Output/results",
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  "Output/figures",
  recursive = TRUE,
  showWarnings = FALSE
)

# ==========================================
# 1. READ RAW DATA
# ==========================================

apr <- read.csv(
  "Data/uber-raw-data-apr14.csv",
  check.names = FALSE
)

may <- read.csv(
  "Data/uber-raw-data-may14.csv",
  check.names = FALSE
)

jun <- read.csv(
  "Data/uber-raw-data-jun14.csv",
  check.names = FALSE
)

jul <- read.csv(
  "Data/uber-raw-data-jul14.csv",
  check.names = FALSE
)

aug <- read.csv(
  "Data/uber-raw-data-aug14.csv",
  check.names = FALSE
)

sep <- read.csv(
  "Data/uber-raw-data-sep14.csv",
  check.names = FALSE
)

# ==========================================
# 2. COMBINE ALL DATASETS
# ==========================================

uber_data <- dplyr::bind_rows(
  apr,
  may,
  jun,
  jul,
  aug,
  sep
)

cat("Total rows:", nrow(uber_data), "\n")
cat("Total columns:", ncol(uber_data), "\n")

# ==========================================
# 3. CHECK DATA STRUCTURE
# ==========================================

cat("\n===== DATA STRUCTURE =====\n")
str(uber_data)

cat("\n===== SUMMARY =====\n")
print(summary(uber_data))

# ==========================================
# 4. CHECK MISSING VALUES
# ==========================================

missing_values <- colSums(is.na(uber_data))

cat("\n===== MISSING VALUES =====\n")
print(missing_values)

# ==========================================
# 5. CHECK DUPLICATED ROWS
# ==========================================

duplicate_count <- sum(duplicated(uber_data))

cat(
  "\nDuplicated rows:",
  duplicate_count,
  "\n"
)

# ==========================================
# 6. CONVERT DATE/TIME
# ==========================================

uber_data$`Date/Time` <- lubridate::mdy_hms(
  uber_data$`Date/Time`
)

# ==========================================
# 7. CREATE TIME FEATURES
# ==========================================

uber_data$Hour <- lubridate::hour(
  uber_data$`Date/Time`
)

uber_data$Day <- lubridate::day(
  uber_data$`Date/Time`
)

uber_data$Date <- as.Date(
  uber_data$`Date/Time`
)

uber_data$Month <- lubridate::month(
  uber_data$`Date/Time`,
  label = TRUE,
  abbr = TRUE
)

uber_data$Weekday <- lubridate::wday(
  uber_data$`Date/Time`,
  label = TRUE,
  abbr = TRUE
)

uber_data$DayType <- ifelse(
  lubridate::wday(uber_data$`Date/Time`) %in% c(1, 7),
  "Weekend",
  "Weekday"
)

# ==========================================
# 8. FINAL CHECK
# ==========================================

cat("\n===== FINAL DATA =====\n")
print(head(uber_data))

cat(
  "\nRows:",
  nrow(uber_data),
  "\n"
)

cat(
  "Columns:",
  ncol(uber_data),
  "\n"
)

cat("\n===== FINAL MISSING VALUES =====\n")
print(colSums(is.na(uber_data)))

# ==========================================
# 9. EXPORT CLEAN DATASET
# ==========================================

write.csv(
  uber_data,
  "Output/results/uber_clean.csv",
  row.names = FALSE
)

cat(
  "\nClean dataset exported successfully!\n"
)

cat(
  "Output: Output/results/uber_clean.csv\n"
)