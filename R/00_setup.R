# Required packages
packages <- c(
  "ggplot2",
  "dplyr",
  "tidyr",
  "lubridate",
  "ggthemes",
  "scales"
)

# Install missing packages
for (pkg in packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
}

# Load packages
library(ggplot2)
library(dplyr)
library(tidyr)
library(lubridate)
library(ggthemes)
library(scales)

cat("All required packages are ready.\n")