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

cat("[0/9] Setup — installing/loading packages...\n")
source("R/00_setup.R")
cat("      Done.\n\n")

# ==========================================
# STEP 1: DATA CLEANING
# ==========================================

cat("[1/9] Data Cleaning...\n")
source("R/01_data_cleaning.R")
cat("      Done.\n\n")

# ==========================================
# STEP 2: TIME ANALYSIS
# ==========================================

cat("[2/9] Time Analysis...\n")
source("R/02_time_analysis.R")
cat("      Done.\n\n")

# ==========================================
# STEP 3: BASE ANALYSIS
# ==========================================

cat("[3/9] Base Analysis...\n")
source("R/03_base_analysis.R")
cat("      Done.\n\n")

# ==========================================
# STEP 4: LOCATION ANALYSIS
# ==========================================

cat("[4/9] Location Analysis...\n")
source("R/04_location_analysis.R")
cat("      Done.\n\n")

# ==========================================
# STEP 5: VISUALIZATION
# ==========================================

cat("[5/9] Visualization...\n")
source("R/05_visualization.R")
cat("      Done.\n\n")

# ==========================================
# STEP 6: INSIGHTS
# ==========================================

cat("[6/9] Computing Insights...\n")
source("R/06_insight_dashboard.R")
cat("      Done.\n\n")

# ==========================================
# PIPELINE COMPLETE
# ==========================================

cat("[7/9] Exact dashboard marts...\n")
source("R/07_dashboard_marts.R")
cat("[8/9] Historical prediction experiment...\n")
source("R/08_demand_model.R")
cat("[9/9] Anomalies and spatial clustering...\n")
source("R/09_ai_analytics.R")
pipeline_end  <- Sys.time()
elapsed       <- round(as.numeric(difftime(pipeline_end, pipeline_start, units = "mins")), 1)

cat("====================================\n")
cat("PIPELINE COMPLETED SUCCESSFULLY\n")
cat("====================================\n")
cat("Time elapsed:", elapsed, "minutes\n\n")

cat("Outputs created:\n")
cat("  output/results/uber_clean.csv\n")
cat("  output/results/trips_by_hour.csv\n")
cat("  output/results/trips_by_month.csv\n")
cat("  output/results/trips_by_weekday.csv\n")
cat("  output/results/trips_by_base.csv\n")
cat("  output/results/top20_hotspots.csv\n")
cat("  output/results/insights.csv\n")
cat("  output/figures/  (9 chart files)\n\n")

cat("  output/dashboard/ (exact aggregate cubes)\n")
cat("  output/model/ (metrics, predictions, importance)\n")
cat("  output/anomaly/ (scored residuals, calibration summary)\n")
cat("  output/clusters/ (weighted DBSCAN, sensitivity, metadata)\n\n")
cat("To launch the Shiny dashboard, run in R:\n")
cat("  shiny::runApp('app')\n\n")

