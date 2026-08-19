# ==========================================
# Uber Data Analysis Project
# File: 01_data_cleaning.R
# Author: TV1
# Purpose: Load, clean and transform Uber data
# ==========================================

source("R/00_setup.R")

# ==========================================
# 1. READ RAW DATA
# ==========================================

apr <- read.csv("data/uber-raw-data-apr14.csv")
may <- read.csv("data/uber-raw-data-may14.csv")
jun <- read.csv("data/uber-raw-data-jun14.csv")
jul <- read.csv("data/uber-raw-data-jul14.csv")
aug <- read.csv("data/uber-raw-data-aug14.csv")
sep <- read.csv("data/uber-raw-data-sep14.csv")

# ==========================================
# 2. CHECK RAW DATA
# ==========================================

cat("April:", nrow(apr), "rows\n")
cat("May:", nrow(may), "rows\n")
cat("June:", nrow(jun), "rows\n")
cat("July:", nrow(jul), "rows\n")
cat("August:", nrow(aug), "rows\n")
cat("September:", nrow(sep), "rows\n")

# ==========================================
# 3. COMBINE ALL DATASETS
# ==========================================

uber_data <- bind_rows(
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
# 4. CHECK DATA STRUCTURE
# ==========================================

print(str(uber_data))
print(summary(uber_data))

# ==========================================
# 5. CHECK MISSING VALUES
# ==========================================

missing_values <- colSums(is.na(uber_data))
print(missing_values)

# ==========================================
# 6. CHECK DUPLICATED ROWS
# ==========================================

duplicate_count <- sum(duplicated(uber_data))
cat("Duplicated rows:", duplicate_count, "\n")

# ==========================================
# 7. CONVERT DATE/TIME
# ==========================================

uber_data$`Date/Time` <- mdy_hms(
  uber_data$`Date/Time`
)

# ==========================================
# 8. CREATE TIME FEATURES
# ==========================================

uber_data$Hour <- hour(
  uber_data$`Date/Time`
)

uber_data$Day <- day(
  uber_data$`Date/Time`
)

uber_data$Month <- month(
  uber_data$`Date/Time`,
  label = TRUE,
  abbr = TRUE
)

uber_data$Weekday <- wday(
  uber_data$`Date/Time`,
  label = TRUE,
  abbr = TRUE
)

# ==========================================
# 9. FINAL CHECK
# ==========================================

cat("\n===== FINAL DATA =====\n")
print(head(uber_data))
cat("\nRows:", nrow(uber_data), "\n")
cat("Columns:", ncol(uber_data), "\n")
print(colSums(is.na(uber_data)))

# ==========================================
# 10. EXPORT CLEAN DATASET
# ==========================================

write.csv(
  uber_data,
  "output/results/uber_clean.csv",
  row.names = FALSE
)
cat("\nClean dataset exported successfully!\n")