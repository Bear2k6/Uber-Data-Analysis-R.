# ==========================================
# Uber Data Analysis Project
# File: 05_visualization.R
# Purpose: Create all analysis charts from pre-computed results
# ==========================================

source("R/00_setup.R")

# ==========================================
# 0. HELPER: LOAD RESULT CSV
# ==========================================

load_result <- function(filename) {
  path <- file.path("output/results", filename)
  if (!file.exists(path)) {
    stop(paste("Required result file not found:", path,
               "\nRun the analysis scripts first."))
  }
  readr::read_csv(path, show_col_types = FALSE)
}

# Uber brand color palette
uber_colors <- c(
  "#000000", "#276EF1", "#52677E", "#75899F",
  "#A5B9CD", "#163C68", "#D2DCE7"
)

# Common theme
theme_uber <- function() {
  theme_minimal(base_size = 13) +
    theme(
      plot.title    = element_text(face = "bold", size = 15),
      plot.subtitle = element_text(color = "grey50", size = 11),
      axis.title    = element_text(face = "bold"),
      plot.margin   = margin(15, 15, 15, 15)
    )
}

save_plot <- function(plot, filename, width = 10, height = 6) {
  path <- file.path("output/figures", filename)
  ggsave(path, plot, width = width, height = height, dpi = 150)
  cat("Saved:", path, "\n")
}

# ==========================================
# 1. TRIPS BY HOUR  →  01_hour.png
# ==========================================

trips_by_hour <- load_result("trips_by_hour.csv")

p1 <- ggplot(trips_by_hour, aes(x = Hour, y = Total_Trips)) +
  geom_col(fill = "#276EF1", alpha = 0.85) +
  geom_text(aes(label = scales::comma(Total_Trips)),
            vjust = -0.4, size = 2.8, color = "grey30") +
  scale_x_continuous(breaks = 0:23) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.08))) +
  labs(
    title    = "Uber Trips by Hour of Day",
    subtitle = "New York City — April to September 2014",
    x        = "Hour of Day",
    y        = "Total Trips"
  ) +
  theme_uber()

save_plot(p1, "01_hour.png", width = 12, height = 6)

# ==========================================
# 2. TRIPS BY MONTH  →  02_month.png
# ==========================================

trips_by_month <- load_result("trips_by_month.csv")
trips_by_month$Month <- factor(trips_by_month$Month,
  levels = c("Apr", "May", "Jun", "Jul", "Aug", "Sep"))

p2 <- ggplot(trips_by_month, aes(x = Month, y = Total_Trips, fill = Month)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = scales::comma(Total_Trips)),
            vjust = -0.4, size = 3.5, fontface = "bold") +
  scale_fill_manual(values = uber_colors) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.1))) +
  labs(
    title    = "Uber Trips by Month",
    subtitle = "New York City — April to September 2014",
    x        = "Month",
    y        = "Total Trips"
  ) +
  theme_uber()

save_plot(p2, "02_month.png", width = 9, height = 6)

# ==========================================
# 3. TRIPS BY WEEKDAY  →  03_weekday.png
# ==========================================

trips_by_weekday <- load_result("trips_by_weekday.csv")
trips_by_weekday$Weekday <- factor(trips_by_weekday$Weekday,
  levels = c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"))

p3 <- ggplot(trips_by_weekday, aes(x = Weekday, y = Total_Trips, fill = Weekday)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = scales::comma(Total_Trips)),
            vjust = -0.4, size = 3.5, fontface = "bold") +
  scale_fill_manual(values = uber_colors) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.1))) +
  labs(
    title    = "Uber Trips by Day of Week",
    subtitle = "New York City — April to September 2014",
    x        = "Day of Week",
    y        = "Total Trips"
  ) +
  theme_uber()

save_plot(p3, "03_weekday.png", width = 9, height = 6)

# ==========================================
# 4. TRIPS BY BASE  →  04_base.png
# ==========================================

trips_by_base <- load_result("trips_by_base.csv")

p4 <- ggplot(trips_by_base,
             aes(x = reorder(Base, Total_Trips), y = Total_Trips, fill = Base)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = paste0(scales::comma(Total_Trips), " (", Percentage, "%)")),
            hjust = -0.05, size = 3.2) +
  coord_flip() +
  scale_fill_manual(values = uber_colors) +
  scale_x_discrete() +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.2))) +
  labs(
    title    = "Uber Trips by Dispatch Base",
    subtitle = "New York City — April to September 2014",
    x        = "Base",
    y        = "Total Trips"
  ) +
  theme_uber()

save_plot(p4, "04_base.png", width = 10, height = 5)

# ==========================================
# 5. PICKUP DENSITY MAP (ggplot)  →  05_location.png
# ==========================================

location_sample <- load_result("location_sample.csv")

p5 <- ggplot(location_sample, aes(x = Lon, y = Lat)) +
  stat_density_2d(
    aes(fill = after_stat(density)),
    geom  = "raster",
    contour = FALSE,
    n = 200
  ) +
  scale_fill_viridis_c(option = "inferno", name = "Density") +
  coord_fixed(
    xlim = c(-74.15, -73.70),
    ylim = c(40.58, 40.92)
  ) +
  labs(
    title    = "Uber Pickup Density — NYC",
    subtitle = paste0("Based on ", scales::comma(nrow(location_sample)), " sampled pickups"),
    x        = "Longitude",
    y        = "Latitude"
  ) +
  theme_uber()

save_plot(p5, "05_location.png", width = 9, height = 8)

# ==========================================
# 6. TOP 20 HOTSPOTS MAP  →  06_hotspots.png
# ==========================================

top20 <- load_result("top20_hotspots.csv")

p6 <- ggplot(top20, aes(x = Longitude, y = Latitude, size = Trips, color = Trips)) +
  geom_point(alpha = 0.8) +
  geom_text(aes(label = Rank), size = 3, color = "white", fontface = "bold") +
  scale_size_continuous(range = c(4, 18), labels = scales::comma) +
  scale_color_viridis_c(option = "plasma", labels = scales::comma) +
  coord_fixed(
    xlim = c(-74.05, -73.92),
    ylim = c(40.68, 40.85)
  ) +
  labs(
    title    = "Top 20 Uber Pickup Hotspots — NYC",
    subtitle = "Circle size proportional to trip count",
    x        = "Longitude",
    y        = "Latitude",
    size     = "Trips",
    color    = "Trips"
  ) +
  theme_uber()

save_plot(p6, "06_hotspots.png", width = 9, height = 8)

# ==========================================
# 7. DAYTYPE COMPARISON  →  07_daytype.png
# ==========================================

trips_by_daytype <- load_result("trips_by_day_type.csv")

p7 <- ggplot(trips_by_daytype, aes(x = DayType, y = Total_Trips, fill = DayType)) +
  geom_col(width = 0.5, show.legend = FALSE) +
  geom_text(aes(label = scales::comma(Total_Trips)),
            vjust = -0.4, size = 4, fontface = "bold") +
  scale_fill_manual(values = c("Weekday" = "#276EF1", "Weekend" = "#75899F")) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.1))) +
  labs(
    title    = "Uber Trips: Weekday vs Weekend",
    subtitle = "New York City — April to September 2014",
    x        = NULL,
    y        = "Total Trips"
  ) +
  theme_uber()

save_plot(p7, "07_daytype.png", width = 7, height = 6)

# ==========================================
# 8. HOUR × DAYTYPE  →  08_hour_daytype.png
# ==========================================

trips_hour_daytype <- load_result("trips_by_hour_daytype.csv")

p8 <- ggplot(trips_hour_daytype, aes(x = Hour, y = Total_Trips, color = DayType)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 0:23) +
  scale_y_continuous(labels = scales::comma) +
  scale_color_manual(values = c("Weekday" = "#276EF1", "Weekend" = "#75899F")) +
  labs(
    title    = "Trips by Hour: Weekday vs Weekend",
    subtitle = "New York City — April to September 2014",
    x        = "Hour of Day",
    y        = "Total Trips",
    color    = "Day Type"
  ) +
  theme_uber()

save_plot(p8, "08_hour_daytype.png", width = 12, height = 6)

# ==========================================
# 9. BASE × MONTH HEATMAP  →  09_base_month.png
# ==========================================

trips_base_month <- load_result("trips_by_base_month.csv")
trips_base_month$Month <- factor(trips_base_month$Month,
  levels = c("Apr", "May", "Jun", "Jul", "Aug", "Sep"))

p9 <- ggplot(trips_base_month, aes(x = Month, y = Base, fill = Total_Trips)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = scales::comma(Total_Trips)), size = 3, color = "white", fontface = "bold") +
  scale_fill_gradient(low = "#416C9A", high = "#102D50", labels = scales::comma) +
  labs(
    title    = "Trips by Base and Month",
    subtitle = "New York City — April to September 2014",
    x        = "Month",
    y        = "Base",
    fill     = "Trips"
  ) +
  theme_uber() +
  theme(legend.position = "right")

save_plot(p9, "09_base_month.png", width = 10, height = 5)

cat("\n05_visualization.R completed successfully.\n")
cat("Figures saved to output/figures/\n")

