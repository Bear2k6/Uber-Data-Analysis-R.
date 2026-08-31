# ==========================================
# Uber Data Analysis Project
# Main.R
# ==========================================

cat("====================================\n")
cat("UBER DATA ANALYSIS PROJECT\n")
cat("====================================\n\n")


# ==========================================
# 1. DATA CLEANING
# ==========================================

cat("[1/4] Running Data Cleaning...\n")

source(
  "R/01_data_cleaning.R"
)


# ==========================================
# 2. TIME ANALYSIS
# ==========================================

cat("\n[2/4] Running Time Analysis...\n")

source(
  "R/02_time_analysis.R"
)


# ==========================================
# 3. BASE ANALYSIS
# ==========================================

cat("\n[3/4] Running Base Analysis...\n")

source(
  "R/03_base_analysis.R"
)


# ==========================================
# 4. LOCATION ANALYSIS
# ==========================================

cat("\n[4/4] Running Location Analysis...\n")

source(
  "R/04_location_analysis.R"
)


# ==========================================
# FINISHED
# ==========================================

cat("\n====================================\n")
cat("PIPELINE COMPLETED SUCCESSFULLY\n")
cat("====================================\n")