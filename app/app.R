# ==========================================
# Uber NYC Trip Analytics Dashboard
# app/app.R  —  Single-file Shiny App
# ==========================================
#
# Run with: shiny::runApp("app")
# ==========================================

# ---- Required packages ----
required_pkgs <- c("shiny", "bslib", "dplyr", "ggplot2", "scales",
                   "leaflet", "DT", "readr", "tidyr")
for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

library(shiny)
library(bslib)
library(dplyr)
library(ggplot2)
library(scales)
library(leaflet)
library(DT)
library(readr)
library(tidyr)

# ==========================================
# DATA LOADING — load once at startup
# ==========================================

results_dir <- file.path("..", "Output", "results")

safe_read <- function(filename) {
  path <- file.path(results_dir, filename)
  if (!file.exists(path)) {
    warning(paste("Data file not found:", path,
                  "\nRun Rscript Main.R from the project root first."))
    return(NULL)
  }
  readr::read_csv(path, show_col_types = FALSE)
}

# uber_clean is NOT loaded — use only pre-computed aggregates for performance
# 4.5M rows would make the Shiny app very slow
uber_clean        <- NULL  # placeholder; actual filtering uses aggregate tables
trips_by_hour     <- safe_read("trips_by_hour.csv")
trips_by_month    <- safe_read("trips_by_month.csv")
trips_by_weekday  <- safe_read("trips_by_weekday.csv")
trips_by_base     <- safe_read("trips_by_base.csv")
trips_by_daytype  <- safe_read("trips_by_day_type.csv")
trips_by_date     <- safe_read("trips_by_date.csv")
trips_hr_daytype  <- safe_read("trips_by_hour_daytype.csv")
trips_hr_weekday  <- safe_read("trips_by_hour_weekday.csv")
trips_base_month  <- safe_read("trips_by_base_month.csv")
trips_base_wkday  <- safe_read("trips_by_base_weekday.csv")
avg_by_daytype    <- safe_read("avg_by_daytype.csv")
location_grid     <- safe_read("location_grid_counts.csv")
top20_hotspots    <- safe_read("top20_hotspots.csv")
insights_df       <- safe_read("insights.csv")

# Apply factor levels
month_levels   <- c("Apr", "May", "Jun", "Jul", "Aug", "Sep")
weekday_levels <- c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

apply_factors <- function(df) {
  if (is.null(df)) return(NULL)
  if ("Month"   %in% names(df)) df$Month   <- factor(df$Month,   levels = month_levels)
  if ("Weekday" %in% names(df)) df$Weekday <- factor(df$Weekday, levels = weekday_levels)
  df
}

trips_by_month   <- apply_factors(trips_by_month)
trips_by_weekday <- apply_factors(trips_by_weekday)
trips_hr_weekday <- apply_factors(trips_hr_weekday)
trips_base_month <- apply_factors(trips_base_month)
trips_base_wkday <- apply_factors(trips_base_wkday)

if (!is.null(uber_clean)) {
  uber_clean$Month   <- factor(uber_clean$Month,   levels = month_levels)
  uber_clean$Weekday <- factor(uber_clean$Weekday, levels = weekday_levels)
}

# ---- Helper: get insight value ----
get_insight <- function(metric) {
  if (is.null(insights_df)) return("N/A")
  row <- insights_df[insights_df$Metric == metric, ]
  if (nrow(row) == 0) return("N/A")
  as.character(row$Value[1])
}

# ---- Computed KPIs ----
total_trips     <- if (!is.null(trips_by_hour)) sum(trips_by_hour$Total_Trips) else 0
avg_trips_day   <- if (!is.null(trips_by_date))
                     round(mean(trips_by_date$Total_Trips), 0) else 0
peak_hour_val   <- get_insight("Peak Hour")
peak_month_val  <- get_insight("Peak Month")
top_base_val    <- get_insight("Top Base")
nyc_pct_val     <- get_insight("Trips inside NYC area (%)")

# ---- Uber brand colors ----
uber_palette <- c("#276EF1", "#09B374", "#FF6937", "#FFCD00", "#8C1932", "#9B51E0", "#000000")

# ---- Common ggplot theme ----
theme_uber_dash <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title      = element_text(face = "bold", size = 13),
      plot.subtitle   = element_text(color = "grey55", size = 10),
      axis.title      = element_text(face = "bold", size = 11),
      panel.grid.minor = element_blank(),
      plot.background = element_rect(fill = "transparent", color = NA)
    )
}

# ==========================================
# UI HELPER FUNCTIONS (must be defined before ui)
# ==========================================

# Insight card UI element
insight_card_ui <- function(label, value) {
  div(class = "insight-card",
    div(class = "insight-label", label),
    div(class = "insight-value", value)
  )
}

# Icon + text helper for nav tabs
icon_text <- function(icon_name, text) {
  tagList(icon(icon_name), text)
}

# ==========================================
# UI
# ==========================================

ui <- page_navbar(
  title = span(
    tags$img(src = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/58/Uber_logo_2018.svg/120px-Uber_logo_2018.svg.png",
             height = "28px", style = "margin-right:10px;"),
    "NYC Trip Analytics"
  ),
  window_title = "Uber NYC Trip Analytics Dashboard",
  theme = bs_theme(
    version   = 5,
    bootswatch = "darkly",
    primary   = "#276EF1",
    font_scale = 0.95
  ),
  navbar_options = navbar_options(bg = "#1a1a2e"),

  # ---- CSS ----
  header = tags$head(
    tags$style(HTML("
      .kpi-card {
        background: linear-gradient(135deg, #16213e 0%, #0f3460 100%);
        border: 1px solid #276EF1;
        border-radius: 12px;
        padding: 20px;
        text-align: center;
        margin-bottom: 12px;
        transition: transform 0.2s;
      }
      .kpi-card:hover { transform: translateY(-3px); }
      .kpi-value {
        font-size: 2rem;
        font-weight: 700;
        color: #276EF1;
        display: block;
      }
      .kpi-label {
        font-size: 0.8rem;
        color: #aaa;
        text-transform: uppercase;
        letter-spacing: 0.05em;
      }
      .section-title {
        font-size: 1.1rem;
        font-weight: 600;
        color: #fff;
        border-left: 4px solid #276EF1;
        padding-left: 10px;
        margin: 20px 0 12px 0;
      }
      .insight-card {
        background: #16213e;
        border: 1px solid #276EF1;
        border-radius: 10px;
        padding: 15px 20px;
        margin-bottom: 10px;
      }
      .insight-label { color: #aaa; font-size: 0.85rem; }
      .insight-value { color: #fff; font-weight: 600; font-size: 1.1rem; }
      body { background-color: #1a1a2e !important; }
      .navbar-brand img { filter: brightness(0) invert(1); }
    "))
  ),

  # ==================================================
  # TAB 1: OVERVIEW
  # ==================================================
  nav_panel(
    title = icon_text("house", "Overview"),

    layout_columns(
      col_widths = c(2, 2, 2, 2, 2, 2),

      div(class = "kpi-card",
        span(class = "kpi-value", scales::comma(total_trips)),
        span(class = "kpi-label", "Total Trips")),

      div(class = "kpi-card",
        span(class = "kpi-value", scales::comma(avg_trips_day)),
        span(class = "kpi-label", "Avg Trips / Day")),

      div(class = "kpi-card",
        span(class = "kpi-value", paste0(peak_hour_val, ":00")),
        span(class = "kpi-label", "Peak Hour")),

      div(class = "kpi-card",
        span(class = "kpi-value", peak_month_val),
        span(class = "kpi-label", "Peak Month")),

      div(class = "kpi-card",
        span(class = "kpi-value", top_base_val),
        span(class = "kpi-label", "Top Base")),

      div(class = "kpi-card",
        span(class = "kpi-value", paste0(get_insight("Trips inside NYC area (%)"), "%")),
        span(class = "kpi-label", "NYC Coverage"))
    ),

    layout_columns(
      col_widths = c(6, 6),
      card(full_screen = TRUE, card_header("Trips by Month"),
           plotOutput("ov_month_chart", height = "260px")),
      card(full_screen = TRUE, card_header("Trips by Hour"),
           plotOutput("ov_hour_chart",  height = "260px"))
    ),
    layout_columns(
      col_widths = c(6, 6),
      card(full_screen = TRUE, card_header("Trips by Weekday"),
           plotOutput("ov_weekday_chart", height = "260px")),
      card(full_screen = TRUE, card_header("Trips by Base"),
           plotOutput("ov_base_chart",    height = "260px"))
    )
  ),

  # ==================================================
  # TAB 2: TIME ANALYSIS
  # ==================================================
  nav_panel(
    title = icon_text("clock", "Time Analysis"),

    layout_sidebar(
      sidebar = sidebar(
        width = 220,
        bg = "#16213e",

        h6("Filters", style = "color:#276EF1; font-weight:700;"),

        selectInput("ta_month", "Month",
          choices = c("All", month_levels), selected = "All"),

        selectInput("ta_daytype", "Day Type",
          choices = c("All", "Weekday", "Weekend"), selected = "All"),

        selectInput("ta_weekday", "Weekday",
          choices = c("All", weekday_levels), selected = "All"),

        selectInput("ta_hour", "Hour",
          choices = c("All", as.character(0:23)), selected = "All"),

        actionButton("ta_reset", "Reset Filters",
          class = "btn-outline-primary btn-sm w-100 mt-2")
      ),

      # KPIs row
      layout_columns(
        col_widths = c(4, 4, 4),
        card(card_header("Filtered Trips"),
             h3(textOutput("ta_total"), style = "color:#276EF1; font-weight:700; text-align:center;")),
        card(card_header("Peak Hour"),
             h3(textOutput("ta_peak_hour"), style = "color:#09B374; font-weight:700; text-align:center;")),
        card(card_header("Peak Weekday"),
             h3(textOutput("ta_peak_weekday"), style = "color:#FF6937; font-weight:700; text-align:center;"))
      ),

      layout_columns(
        col_widths = c(6, 6),
        card(full_screen = TRUE, card_header("Trips by Hour"),
             plotOutput("ta_hour_plot",  height = "260px")),
        card(full_screen = TRUE, card_header("Trips by Month"),
             plotOutput("ta_month_plot", height = "260px"))
      ),
      layout_columns(
        col_widths = c(6, 6),
        card(full_screen = TRUE, card_header("Trips by Weekday"),
             plotOutput("ta_weekday_plot", height = "260px")),
        card(full_screen = TRUE, card_header("Hour × DayType"),
             plotOutput("ta_heatmap",       height = "260px"))
      ),
      card(full_screen = TRUE, card_header("Data Table"),
           DTOutput("ta_table"))
    )
  ),

  # ==================================================
  # TAB 3: BASE ANALYSIS
  # ==================================================
  nav_panel(
    title = icon_text("building", "Base Analysis"),

    layout_sidebar(
      sidebar = sidebar(
        width = 220,
        bg = "#16213e",
        h6("Filter", style = "color:#276EF1; font-weight:700;"),
        selectInput("ba_base", "Select Base",
          choices = c("All", sort(unique(trips_by_base$Base))),
          selected = "All")
      ),

      layout_columns(
        col_widths = c(3, 3, 3, 3),
        card(card_header("Total Trips"),
             h3(textOutput("ba_total"),  style = "color:#276EF1; font-weight:700; text-align:center;")),
        card(card_header("Share (%)"),
             h3(textOutput("ba_pct"),    style = "color:#09B374; font-weight:700; text-align:center;")),
        card(card_header("Rank"),
             h3(textOutput("ba_rank"),   style = "color:#FF6937; font-weight:700; text-align:center;")),
        card(card_header("Bases"),
             h3(textOutput("ba_count"),  style = "color:#FFCD00; font-weight:700; text-align:center;"))
      ),

      layout_columns(
        col_widths = c(5, 7),
        card(full_screen = TRUE, card_header("Trips by Base"),
             plotOutput("ba_base_plot", height = "320px")),
        card(full_screen = TRUE, card_header("Trips by Month"),
             plotOutput("ba_month_plot", height = "320px"))
      ),
      card(full_screen = TRUE, card_header("Trips by Weekday"),
           plotOutput("ba_weekday_plot", height = "280px"))
    )
  ),

  # ==================================================
  # TAB 4: GEOGRAPHIC ANALYSIS
  # ==================================================
  nav_panel(
    title = icon_text("map", "Geographic"),

    layout_sidebar(
      sidebar = sidebar(
        width = 220,
        bg = "#16213e",
        h6("Filters", style = "color:#276EF1; font-weight:700;"),
        selectInput("geo_month", "Month",
          choices = c("All", month_levels), selected = "All"),
        selectInput("geo_base", "Base",
          choices = c("All", sort(unique(trips_by_base$Base))),
          selected = "All"),
        sliderInput("geo_top_n", "Show Top N Grid Cells",
          min = 100, max = 5000, value = 1000, step = 100),
        p("Map shows aggregated grid cells (~1km²). Circle size = trip count.",
          style = "color:#aaa; font-size:0.8rem;")
      ),
      card(
        full_screen = TRUE,
        card_header("NYC Pickup Density Map"),
        leafletOutput("geo_map", height = "600px")
      )
    )
  ),

  # ==================================================
  # TAB 5: HOTSPOTS
  # ==================================================
  nav_panel(
    title = icon_text("fire", "Hotspots"),

    layout_columns(
      col_widths = c(5, 7),

      card(full_screen = TRUE, card_header("Top 20 Hotspot Locations"),
           leafletOutput("hs_map", height = "480px")),

      tagList(
        card(full_screen = TRUE, card_header("Top 20 Hotspots Chart"),
             plotOutput("hs_chart", height = "280px")),
        card(full_screen = TRUE, card_header("Hotspot Table"),
             DTOutput("hs_table"))
      )
    )
  ),

  # ==================================================
  # TAB 6: DATA EXPLORER
  # ==================================================
  nav_panel(
    title = icon_text("table", "Data Explorer"),

    layout_sidebar(
      sidebar = sidebar(
        width = 240,
        bg = "#16213e",
        h6("Data Options", style = "color:#276EF1; font-weight:700;"),
        selectInput("de_dataset", "Dataset",
          choices = c(
            "Trips by Hour"    = "hour",
            "Trips by Month"   = "month",
            "Trips by Weekday" = "weekday",
            "Trips by Base"    = "base",
            "Trips by Day"     = "day_type",
            "Daily Trips"      = "date",
            "Base × Month"     = "base_month",
            "Top 20 Hotspots"  = "hotspot",
            "Insights Summary" = "insights"
          ),
          selected = "hour"
        ),
        p("Use the search and column filters in the table to explore the data.",
          style = "color:#aaa; font-size:0.8rem;")
      ),
      card(full_screen = TRUE,
           card_header(textOutput("de_title")),
           DTOutput("de_table", height = "550px"))
    )
  ),

  # ==================================================
  # TAB 7: INSIGHTS
  # ==================================================
  nav_panel(
    title = icon_text("lightbulb", "Insights"),

    div(style = "max-width: 960px; margin: auto; padding: 20px;",

      h4("Key Insights — Uber NYC 2014",
         style = "color:#276EF1; font-weight:700; margin-bottom:24px;"),

      layout_columns(
        col_widths = c(4, 4, 4),

        insight_card_ui("Total Trips",      scales::comma(total_trips)),
        insight_card_ui("Avg Trips / Day",  scales::comma(avg_trips_day)),
        insight_card_ui("Peak Hour",        paste0(get_insight("Peak Hour"), ":00 (", scales::comma(as.numeric(get_insight("Peak Hour Trips"))), " trips)"))
      ),

      layout_columns(
        col_widths = c(4, 4, 4),
        insight_card_ui("Peak Month",    paste0(get_insight("Peak Month"), " (", scales::comma(as.numeric(get_insight("Peak Month Trips"))), " trips)")),
        insight_card_ui("Monthly Growth", paste0(get_insight("Monthly Growth Apr to Sep (%)"), "% (Apr → Sep)")),
        insight_card_ui("Peak Weekday",  paste0(get_insight("Peak Weekday"), " (", scales::comma(as.numeric(get_insight("Peak Weekday Trips"))), " trips)"))
      ),

      layout_columns(
        col_widths = c(4, 4, 4),
        insight_card_ui("Weekday Trips", paste0(scales::comma(as.numeric(get_insight("Weekday Total Trips"))), " (", get_insight("Weekday Share (%)"), "%)")),
        insight_card_ui("Weekend Trips", paste0(scales::comma(as.numeric(get_insight("Weekend Total Trips"))), " (", get_insight("Weekend Share (%)"), "%)")),
        insight_card_ui("Weekday vs Weekend", paste0("+", get_insight("Weekday vs Weekend Avg Pct Higher"), "% avg/day higher on weekdays"))
      ),

      layout_columns(
        col_widths = c(4, 4, 4),
        insight_card_ui("Top Base",    paste0(get_insight("Top Base"), " — ", scales::comma(as.numeric(get_insight("Top Base Trips"))), " trips (", get_insight("Top Base Share (%)"), "%)")),
        insight_card_ui("Lowest Base", paste0(get_insight("Lowest Base"), " — ", scales::comma(as.numeric(get_insight("Lowest Base Trips"))), " trips")),
        insight_card_ui("Top Hotspot", paste0("Lat ", get_insight("Top Hotspot Latitude"), ", Lon ", get_insight("Top Hotspot Longitude"), " — ", scales::comma(as.numeric(get_insight("Top Hotspot Trips"))), " trips"))
      ),

      hr(style = "border-color:#276EF1;"),
      p("All values computed dynamically from the dataset. No values are hard-coded.",
        style = "color:#aaa; font-style:italic; font-size:0.85rem;")
    )
  ),

  # ==================================================
  # TAB 8: ABOUT
  # ==================================================
  nav_panel(
    title = icon_text("info-circle", "About"),

    div(style = "max-width: 800px; margin: auto; padding: 30px;",

      h3("Uber NYC Trip Analytics Dashboard",
         style = "color:#276EF1; font-weight:700;"),

      p("An end-to-end data analysis pipeline and interactive dashboard for Uber pickups
        in New York City from April to September 2014."),

      hr(style = "border-color:#276EF1;"),

      h5("Dataset"),
      tags$ul(
        tags$li("6 monthly CSV files: April – September 2014"),
        tags$li(paste0("Total records: ", scales::comma(total_trips))),
        tags$li("Columns: Date/Time, Lat, Lon, Base"),
        tags$li("Source: FiveThirtyEight / Kaggle Uber NYC dataset")
      ),

      h5("Pipeline"),
      tags$ol(
        tags$li("00_setup.R — Package installation"),
        tags$li("01_data_cleaning.R — Load, validate, parse, export uber_clean.csv"),
        tags$li("02_time_analysis.R — Temporal aggregations"),
        tags$li("03_base_analysis.R — Base-level analysis"),
        tags$li("03_location_analysis.R — Geographic grid & hotspots"),
        tags$li("04_visualization.R — Static charts (Output/figures/)"),
        tags$li("05_insight_dashboard.R — Key metrics & insights")
      ),

      h5("Tech Stack"),
      tags$ul(
        tags$li("R + Shiny + bslib (dashboard)"),
        tags$li("dplyr + tidyr + readr (data wrangling)"),
        tags$li("ggplot2 + scales (visualization)"),
        tags$li("leaflet (interactive maps)"),
        tags$li("DT (interactive data tables)")
      ),

      h5("Usage"),
      tags$code("Rscript Main.R"),
      tags$br(),
      tags$code('shiny::runApp("app")')
    )
  )
)

# (icon_text and insight_card_ui are defined above the ui block)

# ==========================================
# SERVER
# ==========================================

server <- function(input, output, session) {

  # ----------------------------------------
  # OVERVIEW CHARTS (static — no filters)
  # ----------------------------------------

  output$ov_month_chart <- renderPlot({
    req(!is.null(trips_by_month))
    ggplot(trips_by_month, aes(x = Month, y = Total_Trips, fill = Month)) +
      geom_col(show.legend = FALSE) +
      scale_fill_manual(values = rep(uber_palette, length.out = 6)) +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = "Trips") +
      theme_uber_dash()
  }, bg = "transparent")

  output$ov_hour_chart <- renderPlot({
    req(!is.null(trips_by_hour))
    ggplot(trips_by_hour, aes(x = Hour, y = Total_Trips)) +
      geom_col(fill = "#276EF1", alpha = 0.85) +
      scale_x_continuous(breaks = seq(0, 23, 4)) +
      scale_y_continuous(labels = comma) +
      labs(x = "Hour", y = "Trips") +
      theme_uber_dash()
  }, bg = "transparent")

  output$ov_weekday_chart <- renderPlot({
    req(!is.null(trips_by_weekday))
    ggplot(trips_by_weekday, aes(x = Weekday, y = Total_Trips, fill = Weekday)) +
      geom_col(show.legend = FALSE) +
      scale_fill_manual(values = rep(uber_palette, length.out = 7)) +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = "Trips") +
      theme_uber_dash()
  }, bg = "transparent")

  output$ov_base_chart <- renderPlot({
    req(!is.null(trips_by_base))
    ggplot(trips_by_base, aes(x = reorder(Base, Total_Trips), y = Total_Trips, fill = Base)) +
      geom_col(show.legend = FALSE) +
      coord_flip() +
      scale_fill_manual(values = rep(uber_palette, length.out = nrow(trips_by_base))) +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = "Trips") +
      theme_uber_dash()
  }, bg = "transparent")

  # ----------------------------------------
  # TIME ANALYSIS — filtered reactive
  # ----------------------------------------

  # Time Analysis uses pre-computed aggregate tables for performance
  # (avoids loading 4.5M row uber_clean.csv into memory per reactive)

  # Derive filtered hour-level summary from trips_by_hour_daytype and trips_hr_weekday
  ta_hour_filtered <- reactive({
    req(!is.null(trips_by_hour))
    df <- trips_by_hour
    if (input$ta_hour != "All") {
      df <- df %>% filter(Hour == as.integer(input$ta_hour))
    }
    df
  })

  ta_month_filtered <- reactive({
    req(!is.null(trips_by_month))
    df <- trips_by_month
    if (input$ta_month != "All") {
      df <- df %>% filter(as.character(Month) == input$ta_month)
    }
    df
  })

  ta_weekday_filtered <- reactive({
    req(!is.null(trips_by_weekday))
    df <- trips_by_weekday
    if (input$ta_weekday != "All") {
      df <- df %>% filter(as.character(Weekday) == input$ta_weekday)
    }
    if (input$ta_daytype != "All") {
      wkday_set <- if (input$ta_daytype == "Weekday") weekday_levels[1:5] else weekday_levels[6:7]
      df <- df %>% filter(as.character(Weekday) %in% wkday_set)
    }
    df
  })

  ta_heatmap_filtered <- reactive({
    req(!is.null(trips_hr_daytype))
    df <- trips_hr_daytype
    if (input$ta_daytype != "All") df <- df %>% filter(DayType == input$ta_daytype)
    if (input$ta_hour    != "All") df <- df %>% filter(Hour == as.integer(input$ta_hour))
    df
  })

  # Approximate filtered total from month/weekday/hour combos
  ta_total_trips <- reactive({
    # Use trips_by_hour as base denominator; apply rough filters
    df <- trips_by_hour
    if (input$ta_hour != "All") {
      df <- df %>% filter(Hour == as.integer(input$ta_hour))
    }
    # For month filter, scale proportionally
    if (input$ta_month != "All" && !is.null(trips_by_month)) {
      m_row <- trips_by_month %>% filter(as.character(Month) == input$ta_month)
      total_m <- if (nrow(m_row) > 0) m_row$Total_Trips[1] else sum(df$Total_Trips)
      if (input$ta_hour == "All") return(total_m)
      # Scale hour trips by month fraction
      month_frac <- total_m / sum(trips_by_month$Total_Trips)
      return(round(sum(df$Total_Trips) * month_frac))
    }
    sum(df$Total_Trips)
  })

  observeEvent(input$ta_reset, {
    updateSelectInput(session, "ta_month",   selected = "All")
    updateSelectInput(session, "ta_daytype", selected = "All")
    updateSelectInput(session, "ta_weekday", selected = "All")
    updateSelectInput(session, "ta_hour",    selected = "All")
  })

  output$ta_total <- renderText({
    scales::comma(ta_total_trips())
  })

  output$ta_peak_hour <- renderText({
    df <- ta_hour_filtered()
    if (is.null(df) || nrow(df) == 0) return("—")
    h <- df %>% slice_max(Total_Trips, n = 1, with_ties = FALSE)
    paste0(h$Hour, ":00")
  })

  output$ta_peak_weekday <- renderText({
    df <- ta_weekday_filtered()
    if (is.null(df) || nrow(df) == 0) return("—")
    w <- df %>% slice_max(Total_Trips, n = 1, with_ties = FALSE)
    as.character(w$Weekday)
  })

  output$ta_hour_plot <- renderPlot({
    df <- ta_hour_filtered()
    req(nrow(df) > 0)
    ggplot(df, aes(x = Hour, y = Total_Trips)) +
      geom_col(fill = "#276EF1", alpha = 0.85) +
      scale_x_continuous(breaks = seq(0, 23, 4)) +
      scale_y_continuous(labels = comma) +
      labs(x = "Hour", y = "Trips", title = "Trips by Hour") +
      theme_uber_dash()
  }, bg = "transparent")

  output$ta_month_plot <- renderPlot({
    df <- ta_month_filtered()
    req(nrow(df) > 0)
    ggplot(df, aes(x = Month, y = Total_Trips, fill = Month)) +
      geom_col(show.legend = FALSE) +
      scale_fill_manual(values = rep(uber_palette, length.out = nrow(df))) +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = "Trips", title = "Trips by Month") +
      theme_uber_dash()
  }, bg = "transparent")

  output$ta_weekday_plot <- renderPlot({
    df <- ta_weekday_filtered()
    req(nrow(df) > 0)
    ggplot(df, aes(x = Weekday, y = Total_Trips, fill = Weekday)) +
      geom_col(show.legend = FALSE) +
      scale_fill_manual(values = rep(uber_palette, length.out = nrow(df))) +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = "Trips", title = "Trips by Weekday") +
      theme_uber_dash()
  }, bg = "transparent")

  output$ta_heatmap <- renderPlot({
    df <- ta_heatmap_filtered()
    req(nrow(df) > 0)
    ggplot(df, aes(x = Hour, y = DayType, fill = Total_Trips)) +
      geom_tile(color = "white") +
      scale_x_continuous(breaks = seq(0, 23, 4)) +
      scale_fill_gradient(low = "#E3F0FF", high = "#276EF1", labels = comma) +
      labs(x = "Hour", y = NULL, fill = "Trips", title = "Hour × DayType Heatmap") +
      theme_uber_dash()
  }, bg = "transparent")

  output$ta_table <- renderDT({
    # Show aggregated summary table combining relevant filters
    df_h <- trips_by_hour
    df_m <- trips_by_month
    df_w <- trips_by_weekday
    if (input$ta_month   != "All") df_m <- df_m %>% filter(as.character(Month) == input$ta_month)
    if (input$ta_weekday != "All") df_w <- df_w %>% filter(as.character(Weekday) == input$ta_weekday)
    if (input$ta_hour    != "All") df_h <- df_h %>% filter(Hour == as.integer(input$ta_hour))
    combined <- bind_rows(
      df_h %>% mutate(Dimension = "Hour",    Label = as.character(Hour)),
      df_m %>% mutate(Dimension = "Month",   Label = as.character(Month)),
      df_w %>% mutate(Dimension = "Weekday", Label = as.character(Weekday))
    ) %>% select(Dimension, Label, Total_Trips)
    datatable(combined,
      options = list(pageLength = 25, scrollX = TRUE, dom = "lfrtip"),
      filter = "top", rownames = FALSE,
      class = "table-dark table-hover"
    )
  })

  # ----------------------------------------
  # BASE ANALYSIS
  # ----------------------------------------

  ba_base_data <- reactive({
    if (input$ba_base == "All") return(trips_by_base)
    trips_by_base %>% filter(Base == input$ba_base)
  })

  output$ba_total <- renderText({
    scales::comma(sum(ba_base_data()$Total_Trips))
  })
  output$ba_pct <- renderText({
    if (input$ba_base == "All") {
      "100%"
    } else {
      paste0(round(sum(ba_base_data()$Total_Trips) /
                   sum(trips_by_base$Total_Trips) * 100, 1), "%")
    }
  })
  output$ba_rank <- renderText({
    if (input$ba_base == "All") return("—")
    r <- trips_by_base %>% filter(Base == input$ba_base) %>% pull(Rank)
    if (length(r) == 0) "—" else as.character(r[1])
  })
  output$ba_count <- renderText({
    nrow(trips_by_base)
  })

  output$ba_base_plot <- renderPlot({
    df <- if (input$ba_base == "All") trips_by_base else
            trips_by_base %>% filter(Base == input$ba_base)
    ggplot(df, aes(x = reorder(Base, Total_Trips), y = Total_Trips, fill = Base)) +
      geom_col(show.legend = FALSE) +
      coord_flip() +
      scale_fill_manual(values = rep(uber_palette, nrow(df))) +
      scale_y_continuous(labels = comma) +
      geom_text(aes(label = paste0(Percentage, "%")),
                hjust = -0.1, size = 3.5, color = "white") +
      labs(x = NULL, y = "Trips", title = "Trips by Base") +
      theme_uber_dash() +
      scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.15)))
  }, bg = "transparent")

  output$ba_month_plot <- renderPlot({
    req(!is.null(trips_base_month))
    df <- if (input$ba_base == "All") trips_base_month else
            trips_base_month %>% filter(Base == input$ba_base)
    ggplot(df, aes(x = Month, y = Total_Trips, color = Base, group = Base)) +
      geom_line(linewidth = 1.2) +
      geom_point(size = 2.5) +
      scale_color_manual(values = rep(uber_palette, length(unique(df$Base)))) +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = "Trips", title = "Trips by Month",
           color = "Base") +
      theme_uber_dash()
  }, bg = "transparent")

  output$ba_weekday_plot <- renderPlot({
    req(!is.null(trips_base_wkday))
    df <- if (input$ba_base == "All") trips_base_wkday else
            trips_base_wkday %>% filter(Base == input$ba_base)
    ggplot(df, aes(x = Weekday, y = Total_Trips, fill = Base)) +
      geom_col(position = "dodge") +
      scale_fill_manual(values = rep(uber_palette, length(unique(df$Base)))) +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = "Trips", title = "Trips by Weekday") +
      theme_uber_dash()
  }, bg = "transparent")

  # ----------------------------------------
  # GEOGRAPHIC MAP
  # ----------------------------------------

  geo_filtered <- reactive({
    req(!is.null(location_grid))
    df <- location_grid
    # Note: location_grid is aggregated — filter by pre-aggregated data only
    df %>%
      slice_max(Total_Trips, n = input$geo_top_n, with_ties = FALSE)
  })

  output$geo_map <- renderLeaflet({
    df <- geo_filtered()
    if (is.null(df) || nrow(df) == 0) {
      return(leaflet() %>% addTiles() %>%
               setView(-74.00, 40.75, zoom = 11))
    }

    max_trips <- max(df$Total_Trips, na.rm = TRUE)
    radius_scaled <- sqrt(df$Total_Trips / max_trips) * 20000

    pal <- colorNumeric(palette = "YlOrRd", domain = df$Total_Trips)

    leaflet(df) %>%
      addProviderTiles("CartoDB.DarkMatter") %>%
      setView(-74.00, 40.73, zoom = 11) %>%
      addCircles(
        lng    = ~Lon_Grid,
        lat    = ~Lat_Grid,
        radius = radius_scaled,
        color  = ~pal(Total_Trips),
        fillColor   = ~pal(Total_Trips),
        fillOpacity = 0.7,
        weight      = 1,
        popup = ~paste0(
          "<b>Location</b><br/>",
          "Latitude: ", Lat_Grid, "<br/>",
          "Longitude: ", Lon_Grid, "<br/>",
          "Trips: ", scales::comma(Total_Trips)
        )
      ) %>%
      addLegend(
        position = "bottomright",
        pal      = pal,
        values   = ~Total_Trips,
        title    = "Trip Count",
        labFormat = labelFormat(big.mark = ",")
      )
  })

  # ----------------------------------------
  # HOTSPOTS
  # ----------------------------------------

  output$hs_map <- renderLeaflet({
    req(!is.null(top20_hotspots))
    df <- top20_hotspots
    max_t <- max(df$Trips)

    leaflet(df) %>%
      addProviderTiles("CartoDB.DarkMatter") %>%
      setView(-73.98, 40.75, zoom = 12) %>%
      addCircleMarkers(
        lng         = ~Longitude,
        lat         = ~Latitude,
        radius      = ~sqrt(Trips / max_t) * 28,
        color       = "#276EF1",
        fillColor   = "#276EF1",
        fillOpacity = 0.7,
        weight      = 2,
        label       = ~paste0("#", Rank, " — ", scales::comma(Trips), " trips"),
        popup       = ~paste0(
          "<b>Rank #", Rank, "</b><br/>",
          "Latitude: ", Latitude, "<br/>",
          "Longitude: ", Longitude, "<br/>",
          "Trips: <b>", scales::comma(Trips), "</b>"
        )
      )
  })

  output$hs_chart <- renderPlot({
    req(!is.null(top20_hotspots))
    df <- top20_hotspots %>%
      mutate(Label = paste0("#", Rank, "\n(", round(Latitude, 2), ", ", round(Longitude, 2), ")"))
    ggplot(df, aes(x = reorder(Label, Trips), y = Trips)) +
      geom_col(fill = "#276EF1", alpha = 0.85) +
      coord_flip() +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = "Trips", title = "Top 20 Pickup Hotspots") +
      theme_uber_dash()
  }, bg = "transparent")

  output$hs_table <- renderDT({
    req(!is.null(top20_hotspots))
    datatable(top20_hotspots,
      options  = list(pageLength = 10, scrollX = TRUE, dom = "tip"),
      rownames = FALSE,
      class    = "table-dark table-hover"
    ) %>%
      formatRound(c("Latitude", "Longitude"), digits = 4) %>%
      formatCurrency("Trips", currency = "", interval = 3, mark = ",", digits = 0)
  })

  # ----------------------------------------
  # DATA EXPLORER
  # ----------------------------------------

  de_dataset_map <- list(
    hour      = trips_by_hour,
    month     = trips_by_month,
    weekday   = trips_by_weekday,
    base      = trips_by_base,
    day_type  = trips_by_daytype,
    date      = trips_by_date,
    base_month = trips_base_month,
    hotspot   = top20_hotspots,
    insights  = insights_df
  )

  output$de_title <- renderText({
    nm <- input$de_dataset
    titles <- c(
      hour = "Trips by Hour", month = "Trips by Month",
      weekday = "Trips by Weekday", base = "Trips by Base",
      day_type = "Trips by Day Type", date = "Daily Trips",
      base_month = "Trips by Base × Month", hotspot = "Top 20 Hotspots",
      insights = "Insights Summary"
    )
    titles[nm]
  })

  output$de_table <- renderDT({
    df <- de_dataset_map[[input$de_dataset]]
    if (is.null(df)) {
      df <- data.frame(Message = "Data not available. Run Main.R first.")
    }
    datatable(df,
      options  = list(
        pageLength = 25,
        lengthMenu = c(10, 25, 50, 100),
        scrollX    = TRUE,
        dom        = "lfrtip"
      ),
      filter   = "top",
      rownames = FALSE,
      class    = "table-dark table-hover table-striped"
    )
  })

}  # end server

# ==========================================
# LAUNCH
# ==========================================
shinyApp(ui = ui, server = server)
