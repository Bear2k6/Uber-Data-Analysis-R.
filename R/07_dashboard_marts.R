# Exact dashboard marts. Runs after geographic analysis using the cleaned records.
dir.create("output/dashboard", recursive = TRUE, showWarnings = FALSE)
stopifnot(all(c("Date", "Month", "Weekday", "DayType", "Hour", "Base") %in% names(uber_data)))
if (anyNA(uber_data[c("Date", "Month", "Weekday", "DayType", "Hour", "Base")])) {
  stop("Missing dashboard dimensions: inspect cleaning_quality.csv before publishing.")
}
dashboard_time_cube <- uber_data %>%
  count(Date, Month, Weekday, DayType, Hour, Base, name = "Total_Trips") %>%
  arrange(Date, Hour, Base)
dashboard_geo_cube <- nyc_data %>%
  mutate(Lat_Grid = round(Lat / GRID_RES) * GRID_RES,
         Lon_Grid = round(Lon / GRID_RES) * GRID_RES) %>%
  count(Month, Base, Lat_Grid, Lon_Grid, name = "Total_Trips")
stopifnot(sum(dashboard_time_cube$Total_Trips) == nrow(uber_data),
          sum(dashboard_geo_cube$Total_Trips) == nrow(nyc_data))
write_csv(dashboard_time_cube, "output/dashboard/dashboard_time_cube.csv")
write_csv(dashboard_geo_cube, "output/dashboard/dashboard_geo_cube.csv")
cat("Dashboard marts:", nrow(dashboard_time_cube), "time rows;", nrow(dashboard_geo_cube), "geographic rows\n")
