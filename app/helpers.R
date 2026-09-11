# Pure aggregate operations shared by the dashboard and verification script.
month_levels <- c("Apr", "May", "Jun", "Jul", "Aug", "Sep")
weekday_levels <- c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
filter_cube <- function(df, month = "All", weekday = "All", daytype = "All",
                        hour = "All", base = "All", dates = NULL) {
  selections <- list(Month = month, Weekday = weekday, DayType = daytype, Hour = hour, Base = base)
  for (column in names(selections)) {
    value <- selections[[column]]
    if (!is.null(value) && length(value) == 1 && value != "All")
      df <- df[as.character(df[[column]]) == as.character(value), , drop = FALSE]
  }
  if (!is.null(dates)) df <- df[df$Date >= as.Date(dates[1]) & df$Date <= as.Date(dates[2]), , drop = FALSE]
  df
}
aggregate_trips <- function(df, dimensions) {
  result <- df %>% group_by(across(all_of(dimensions))) %>%
    summarise(Total_Trips = sum(Total_Trips), .groups = "drop")
  if ("Month" %in% dimensions) result$Month <- factor(result$Month, levels = month_levels)
  if ("Weekday" %in% dimensions) result$Weekday <- factor(result$Weekday, levels = weekday_levels)
  arrange(result, across(all_of(dimensions)))
}
peak_label <- function(df, dimension) {
  if (!nrow(df) || sum(df$Total_Trips) == 0) return("No matching trips")
  counts <- aggregate_trips(df, dimension)
  value <- counts[[dimension]][which.max(counts$Total_Trips)]
  if (dimension == "Hour") sprintf("%02d:00", as.integer(value)) else as.character(value)
}
read_checked <- function(path, columns) {
  fail <- function(reason) stop(paste(reason, path, "\nRun Rscript Main.R from the repository root."), call. = FALSE)
  if (!file.exists(path)) fail("Missing output:")
  df <- readr::read_csv(path, show_col_types = FALSE)
  if (!all(columns %in% names(df)) || !nrow(df)) fail("Empty or invalid schema:")
  if (anyNA(df[columns])) fail("Missing required values:")
  numeric_cols <- vapply(df[columns], is.numeric, logical(1))
  if (any(vapply(df[columns][numeric_cols], function(x) any(!is.finite(x)), logical(1)))) fail("Nonfinite values:")
  if ("Total_Trips" %in% names(df) && (!is.numeric(df$Total_Trips) ||
      any(!is.finite(df$Total_Trips) | df$Total_Trips < 0 | df$Total_Trips %% 1 != 0))) fail("Invalid counts:")
  df
}

