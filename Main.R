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

cat("[0/8] Setup — installing/loading packages...\n")
source("R/00_setup.R")
cat("      Done.\n\n")

# ==========================================
# STEP 1: DATA CLEANING
# ==========================================

cat("[1/8] Data Cleaning...\n")
source("R/01_data_cleaning.R")
cat("      Done.\n\n")

# ==========================================
# STEP 2: TIME ANALYSIS
# ==========================================

cat("[2/8] Time Analysis...\n")
source("R/02_time_analysis.R")
cat("      Done.\n\n")

# ==========================================
# STEP 3: BASE ANALYSIS
# ==========================================

cat("[3/8] Base Analysis...\n")
source("R/03_base_analysis.R")
cat("      Done.\n\n")

# ==========================================
# STEP 4: LOCATION ANALYSIS
# ==========================================

cat("[4/8] Location Analysis...\n")
source("R/04_location_analysis.R")
cat("      Done.\n\n")

# ==========================================
# STEP 5: VISUALIZATION
# ==========================================

cat("[5/8] Visualization...\n")
source("R/05_visualization.R")
cat("      Done.\n\n")

# ==========================================
# STEP 6: INSIGHTS
# ==========================================

cat("[6/8] Computing Insights...\n")
source("R/06_insight_dashboard.R")
cat("      Done.\n\n")

# ==========================================
# PIPELINE COMPLETE
# ==========================================

cat("[7/8] Exact dashboard marts...\n")
source("R/07_dashboard_marts.R")
cat("[8/8] Historical prediction experiment...\n")
source("R/08_demand_model.R")
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
cat("  output/model/ (metrics, predictions, importance)\n\n")
cat("To launch the Shiny dashboard, run in R:\n")
cat("  shiny::runApp('app')\n\n")

