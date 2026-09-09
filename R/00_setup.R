# ==========================================
# Uber Data Analysis Project
# File: 00_setup.R
# Purpose: Install and load all required packages
# ==========================================

packages <- c(
  "ggplot2",
  "dplyr",
  "tidyr",
  "lubridate",
  "ggthemes",
  "scales",
  "readr",
  "shiny",
  "bslib",
  "leaflet",
  "DT"
)

# Install missing packages
for (pkg in packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(paste("Installing package:", pkg))
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

# Load core analysis packages
library(ggplot2)
library(dplyr)
library(tidyr)
library(lubridate)
library(ggthemes)
library(scales)
library(readr)

# Ensure output directories exist
dir.create("Output/results", recursive = TRUE, showWarnings = FALSE)
dir.create("Output/figures", recursive = TRUE, showWarnings = FALSE)

cat("All required packages are ready.\n")