# ==========================================
# Uber Data Analysis Project
# Main.R  — Data Pipeline Runner
# ==========================================
#
# Usage:
#   Rscript Main.R
#
# After completion, launch the dashboard with:
#   shiny::runApp("app")
# ==========================================

cat("====================================\n")
cat("UBER NYC TRIP ANALYTICS — PIPELINE\n")
cat("====================================\n\n")

# Record start time
pipeline_start <- Sys.time()

# ==========================================
# STEP 0: SETUP
# ==========================================

cat("[0/6] Setup — installing/loading packages...\n")
source("R/00_setup.R")
cat("      Done.\n\n")

# ==========================================
# STEP 1: DATA CLEANING
# ==========================================

cat("[1/6] Data Cleaning...\n")
source("R/01_data_cleaning.R")
cat("      Done.\n\n")

# ==========================================
# STEP 2: TIME ANALYSIS
# ==========================================

cat("[2/6] Time Analysis...\n")
source("R/02_time_analysis.R")
cat("      Done.\n\n")

# ==========================================
# STEP 3: BASE ANALYSIS
# ==========================================

cat("[3/6] Base Analysis...\n")
source("R/03_base_analysis.R")
cat("      Done.\n\n")

# ==========================================
# STEP 4: LOCATION ANALYSIS
# ==========================================

cat("[4/6] Location Analysis...\n")
source("R/03_location_analysis.R")
cat("      Done.\n\n")

# ==========================================
# STEP 5: VISUALIZATION
# ==========================================

cat("[5/6] Visualization...\n")
source("R/04_visualization.R")
cat("      Done.\n\n")

# ==========================================
# STEP 6: INSIGHTS
# ==========================================

cat("[6/6] Computing Insights...\n")
source("R/05_insight_dashboard.R")
cat("      Done.\n\n")

# ==========================================
# PIPELINE COMPLETE
# ==========================================

pipeline_end  <- Sys.time()
elapsed       <- round(as.numeric(difftime(pipeline_end, pipeline_start, units = "mins")), 1)

cat("====================================\n")
cat("PIPELINE COMPLETED SUCCESSFULLY\n")
cat("====================================\n")
cat("Time elapsed:", elapsed, "minutes\n\n")

cat("Outputs created:\n")
cat("  Output/results/uber_clean.csv\n")
cat("  Output/results/trips_by_hour.csv\n")
cat("  Output/results/trips_by_month.csv\n")
cat("  Output/results/trips_by_weekday.csv\n")
cat("  Output/results/trips_by_base.csv\n")
cat("  Output/results/top20_hotspots.csv\n")
cat("  Output/results/insights.csv\n")
cat("  Output/figures/  (9 chart files)\n\n")

cat("To launch the Shiny dashboard, run in R:\n")
cat("  shiny::runApp('app')\n\n")