# Uber NYC Demand Intelligence: compact aggregates only, loaded once at startup.
options(sass.cache = FALSE)
# Windows shells can inherit an invalid Unix locale; Unicode UI needs UTF-8.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))
project_root <- if (file.exists("Main.R")) normalizePath(".") else normalizePath("..")
.libPaths(c(file.path(project_root, ".r-library"), .libPaths()))
required_pkgs <- c("shiny", "bslib", "dplyr", "ggplot2", "scales", "leaflet", "DT", "readr", "tidyr", "plotly", "stringi", "jsonlite")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs)) stop("Missing packages: ", paste(missing_pkgs, collapse = ", "),
  ". Run Rscript R/00_setup.R from the repository root.")
invisible(lapply(setdiff(required_pkgs,c("stringi","jsonlite")), library, character.only = TRUE))
source(file.path(project_root, "app/helpers.R"), local = TRUE)
out <- function(...) file.path(project_root, "output", ...)
time_cube <- read_checked(out("dashboard/dashboard_time_cube.csv"), c("Date","Month","Weekday","DayType","Hour","Base","Total_Trips"))
geo_cube <- read_checked(out("dashboard/dashboard_geo_cube.csv"), c("Month","Base","Lat_Grid","Lon_Grid","Total_Trips"))
location_summary <- read_checked(out("results/location_summary.csv"), c("Metric","Value"))
coordinate_quality <- read_checked(out("results/coordinate_quality.csv"), c("Metric","Count"))
cleaning_quality <- read_checked(out("results/cleaning_quality.csv"), c("Metric","Count"))
if (!inherits(time_cube$Date,"Date") || any(!time_cube$Month %in% month_levels) ||
    any(!time_cube$Weekday %in% weekday_levels) || any(!time_cube$Hour %in% 0:23))
  stop("Invalid dashboard dimensions. Run Rscript Main.R.")
metric <- function(name) {
  v <- location_summary$Value[location_summary$Metric == name]
  if (length(v) != 1 || !is.finite(v)) stop("Invalid location summary metric: ",name,". Run Rscript Main.R.")
  v
}
coverage <- metric("Percentage inside NYC (%)")
stopifnot(coverage >= 0, coverage <= 100, sum(geo_cube$Total_Trips) == metric("Records inside NYC bbox"),
          sum(time_cube$Total_Trips) == metric("Total Records"))
calendar <- distinct(time_cube, Date, Month, Weekday, DayType)
bases <- sort(unique(time_cube$Base))
source(file.path(project_root,"app/i18n.R"), local=TRUE, encoding="UTF-8")
source(file.path(project_root,"app/components.R"), local=TRUE, encoding="UTF-8")
model_paths <- c("model_metrics.csv","predictions.csv","feature_importance.csv","model_metadata.csv")
model_available <- all(file.exists(out("model",model_paths)))
if(model_available) {
  model_metrics <- read_checked(out("model/model_metrics.csv"),c("Model","MAE","RMSE","MAPE","R2","Train_Start","Train_End","Test_Start","Test_End"))
  predictions <- read_checked(out("model/predictions.csv"),c("DateTime","Date","Hour","Actual","Baseline","Prediction","Residual","Seasonal_Naive","Regression_Tree","Random_Forest","XGBoost"))
  importance <- read_checked(out("model/feature_importance.csv"),c("Model","Feature","Importance","Rank"))
  model_metadata <- read_checked(out("model/model_metadata.csv"),c("Model","Features","Hyperparameters","Target","Seed"))
  model_series <- c("Seasonal_Naive","Regression_Tree","Random_Forest","XGBoost")
  importance_models <- c("Regression tree","Random Forest","XGBoost")
  stopifnot(setequal(model_metrics$Model,c("Seasonal naive (last week)",importance_models)),nrow(predictions)==720)
}
source(file.path(project_root,"app/ai_components.R"), local=TRUE, encoding="UTF-8")
source(file.path(project_root,"app/assistant_ui.R"), local=TRUE, encoding="UTF-8")
# Explicit allowlist excludes raw/cleaned trips and the pickup-level map sample.
explorer <- list("Time cube"=time_cube,"Geographic cube"=geo_cube,
  "Hourly totals"=aggregate_trips(time_cube,"Hour"),"Daily totals"=aggregate_trips(time_cube,"Date"),
  "Monthly totals"=aggregate_trips(time_cube,"Month"),"Weekday totals"=aggregate_trips(time_cube,"Weekday"),
  "Base totals"=aggregate_trips(time_cube,"Base"),"Base by month"=aggregate_trips(time_cube,c("Base","Month")),
  "Coordinate quality"=coordinate_quality,"Location summary"=location_summary,"Cleaning quality"=cleaning_quality)
ui <- page_navbar(title=NULL,fillable=FALSE,id="navigation",window_title=tr("app_title"),
  theme=bs_theme(version=5,bg="#F7F7F5",fg="#252525",primary="#276EF1",base_font="system-ui"),
  navbar_options=navbar_options(bg="#111111",theme="dark",collapsible=TRUE),
  header=tags$head(tags$link(rel="stylesheet",href=paste0("dashboard.css?v=",unname(tools::md5sum(file.path(project_root,"app/www/dashboard.css")))))),
  nav_panel(label("nav_overview"),value="overview",div(class="page",
    heading("app_title","app_subtitle"),textOutput("ov_metadata",container=function(...) p(class="metadata",...)),
    uiOutput("ov_kpis"),uiOutput("ov_secondary"),section_title("01","section_activity"),
    div(class="editorial-grid",chart_card("daily_trend","ov_daily",300),uiOutput("ov_insights")),
    section_title("02","section_temporal"),pair(chart_card("hourly_profile","ov_hour"),chart_card("weekly_profile","ov_weekday")),
    section_title("03","section_comparison"),pair(chart_card("monthly_profile","ov_month"),chart_card("daytype_profile","ov_daytype")))),
  nav_panel(label("nav_demand"),value="demand",div(class="page",heading("nav_demand","demand_subtitle"),
    filter_panel(dateRangeInput("ta_dates",label("Date range"),start=min(calendar$Date),end=max(calendar$Date),min=min(calendar$Date),max=max(calendar$Date),language="vi",format="dd/mm/yyyy",separator="\u2014"),
      choice("ta_month","Month",month_levels),choice("ta_daytype","DayType",c("Weekday","Weekend")),choice("ta_weekday","Weekday",weekday_levels),choice("ta_hour","Hour",0:23),choice("ta_base","Base",bases),reset_button("ta_reset")),
    uiOutput("ta_kpis"),p(class="context",textOutput("ta_context")),
    pair(chart_card("hourly_profile","ta_hour_plot"),chart_card("hour_weekday","ta_heatmap")),chart_card("eligible_daily","ta_daily",280),
    pair(chart_card("monthly_profile","ta_month_plot"),chart_card("weekly_profile","ta_weekday_plot")),table_section("filtered_table","ta_table","ta_download","download_filtered"))),
  nav_panel(label("nav_geo"),value="geo",div(class="page",heading("nav_geo","geo_subtitle"),
    filter_panel(selectInput("geo_mode",label("map_mode"),localized_choices(c("Grid Density","AI Clusters"),all=FALSE),selectize=FALSE),choice("geo_month","Month",month_levels),choice("geo_base","Base",bases),conditionalPanel("input.geo_mode === 'Grid Density'",numericInput("geo_top_n",label("Top N cells"),min=1,max=nrow(distinct(geo_cube,Lat_Grid,Lon_Grid)),value=20,step=1)),reset_button("geo_reset")),
    conditionalPanel("input.geo_mode === 'Grid Density'",uiOutput("geo_kpis"),p(class="context",label("geo_note")),div(class="editorial-grid geography-grid",
      div(class="chart-frame",h4(label("map_title")),leafletOutput("geo_map",height="520px")),chart_card("hotspots","geo_rank",520)),
    table_section("geo_table","geo_table","geo_download","download_cells")),
    conditionalPanel("input.geo_mode === 'AI Clusters'",cluster_panel()))),
  nav_panel(label("nav_base"),value="base",div(class="page",heading("nav_base","base_subtitle"),
    filter_panel(choice("ba_base","Base",bases),choice("ba_month","Month",month_levels),choice("ba_weekday","Weekday",weekday_levels),choice("ba_daytype","DayType",c("Weekday","Weekend")),reset_button("ba_reset")),
    uiOutput("ba_kpis"),p(class="context",label("base_note")),div(class="editorial-grid",chart_card("base_rank_title","ba_rank_plot",340),chart_card("base_share_title","ba_share",340)),
    pair(chart_card("base_month","ba_month_plot"),chart_card("base_weekday","ba_weekday_plot")))),
  nav_panel(label("nav_prediction"),value="model",div(class="page",heading("nav_prediction","prediction_subtitle"),
    if(model_available) tagList(h3(label("model_comparison")),uiOutput("model_kpis"),p(class="model-conclusion",textOutput("model_comparison")),p(class="context",label("metric_guide")),
      filter_panel(selectInput("prediction_model",label("model_selection"),localized_choices(model_series),selectize=FALSE)),
      chart_card("actual_predicted","model_actual",330),
      div(class="prose",h3(label("experiment_design")),p(label("model_design")),p(label("feature_comparison")),p(textOutput("model_period")),p(label("model_protocol"))),
      chart_card("residual_title","model_residual"),
      filter_panel(selectInput("importance_model",label("importance_model"),localized_choices(importance_models,all=FALSE),selectize=FALSE)),
      p(class="context",label("importance_note")),chart_card("importance_title","model_importance",420),table_section("model_comparison","model_table")) else p(label("model_missing")),
    div(class="prose",h3(label("limitations")),p(label("model_limitations"))))),
  anomaly_page(),
  assistant_page(),
  nav_panel(label("nav_explorer"),value="explorer",div(class="page",heading("nav_explorer","explorer_subtitle"),
    filter_panel(selectInput("de_dataset",label("Dataset"),localized_choices(names(explorer),all=FALSE),selectize=FALSE),downloadButton("de_download",label("download_rows"))),
    p(class="context",textOutput("de_description")),DTOutput("de_table"))),
  nav_panel(label("nav_method"),value="method",div(class="page methodology",heading("nav_method","method_subtitle"),
    section_title("01","method_dataset"),p(label("method_dataset_text")),textOutput("method_counts"),
    p(tags$a(href="https://github.com/fivethirtyeight/uber-tlc-foil-response",target="_blank",rel="noopener",label("method_source"))),
    section_title("02","method_cleaning"),p(label("method_cleaning_text")),p(label("method_duplicates")),p(label("method_time_text")),
    pair(table_section("Cleaning quality","quality_clean"),table_section("Coordinate quality","quality_coord")),
    section_title("03","method_eda"),p(label("method_temporal_text")),p(label("method_base_text")),p(label("method_geo_text")),p(label("method_grid_text")),DTOutput("quality_location"),
    section_title("04","method_architecture"),p(label("method_architecture_text")),
    section_title("05","method_prediction"),p(label("model_design")),p(label("feature_comparison")),
    if(model_available) tagList(p(textOutput("method_model_period")),p(textOutput("method_model_features"))),p(label("model_protocol")),p(label("metric_guide")),
    section_title("06","nav_anomaly"),p(label("anomaly_meaning")),p(label("anomaly_method")),p(label("anomaly_limits")),
    section_title("07","method_unsupervised"),p(label("cluster_method")),p(label("cluster_limits")),
    section_title("08","method_conversation"),p(label("method_conversation_text")),
    section_title("09","limitations"),p(label("method_limits_text")),p(label("model_limitations")))),
  nav_spacer(),nav_item(div(class="language-switch",radioButtons("language",NULL,choices=c("VI"="vi","EN"="en"),selected="vi",inline=TRUE))),
  footer=tagList(tags$script(src="language.js"),tags$script(src="assistant.js")))
server <- function(input,output,session) {
  lang <- reactive(if(is.null(input$language)) "vi" else input$language)
  ai <- ai_server(input,output,session,lang)
  data_assistant <- assistant_server(input,output,session,lang)
  t <- function(key,...) tr(key,lang(),...)
  number <- function(x,digits=0) fmt_number(x,lang(),digits)
  percent <- function(x,digits=2) fmt_percent(x,lang(),digits)
  peak <- function(df,dimension) {
    value <- peak_label(df,dimension)
    if(value=="No matching trips") return(t("no_trips"))
    if(dimension=="Date") return(fmt_date(value,lang()))
    display_values(value,lang(),dimension)
  }
  # Updating labels preserves canonical selected values and leaves navigation/date/Top N alone.
  observeEvent(lang(),{
    session$sendCustomMessage("dashboard-language",list(lang=lang(),strings=as.list(translations[[lang()]])))
    definitions <- list(ta_month=month_levels,ta_weekday=weekday_levels,ta_daytype=c("Weekday","Weekend"),ta_hour=0:23,ta_base=bases,
      geo_month=month_levels,geo_base=bases,ba_month=month_levels,ba_weekday=weekday_levels,ba_daytype=c("Weekday","Weekend"),ba_base=bases,de_dataset=names(explorer))
    if(model_available) definitions <- c(definitions,list(prediction_model=model_series,importance_model=importance_models))
    for(id in names(definitions)) {
      selected <- isolate(input[[id]])
      if(is.null(selected)) selected <- if(id=="de_dataset") "Time cube" else if(id=="importance_model") "Regression tree" else "All"
      updateSelectInput(session,id,choices=localized_choices(definitions[[id]],lang(),if(grepl("daytype",id)) "DayType" else NULL,all=!id %in% c("de_dataset","importance_model")),selected=selected)
    }
  })
  output$method_counts <- renderText(t("period_metadata",number(sum(time_cube$Total_Trips)),number(nrow(calendar)),number(length(bases))))
  output$ov_metadata <- renderText(t("period_metadata",number(sum(time_cube$Total_Trips)),number(nrow(calendar)),number(length(bases))))
  output$ov_kpis <- renderUI(kpis(
    kpi(t("total_trips"),number(sum(time_cube$Total_Trips)),t("observed_days",number(nrow(calendar)))),
    kpi(t("average_day"),number(sum(time_cube$Total_Trips)/nrow(calendar)),t("observed_average")),
    kpi(t("peak_hour"),peak(time_cube,"Hour"),t("pickup_count",number(max(aggregate_trips(time_cube,"Hour")$Total_Trips)))),
    kpi(t("top_base"),peak(time_cube,"Base"))))
  output$ov_secondary <- renderUI(div(class="secondary-metrics",
    div(span(t("peak_month")),strong(peak(time_cube,"Month"))),div(span(t("peak_weekday")),strong(peak(time_cube,"Weekday"))),
    div(span(t("busiest_date")),strong(peak(time_cube,"Date"))),div(span(t("coverage")),strong(percent(coverage)))))
  output$ov_daily <- renderPlotly(chart(aggregate_trips(time_cube,"Date"),"Date","line",lang=lang()))
  output$ov_hour <- renderPlotly(chart(aggregate_trips(time_cube,"Hour"),"Hour","line",lang=lang()))
  output$ov_weekday <- renderPlotly(chart(aggregate_trips(time_cube,"Weekday"),"Weekday",lang=lang()))
  output$ov_month <- renderPlotly(chart(aggregate_trips(time_cube,"Month"),"Month",lang=lang()))
  daytype_average <- aggregate_trips(time_cube,"DayType") %>% left_join(count(calendar,DayType,name="Days"),by="DayType") %>% mutate(Average_per_day=Total_Trips/Days)
  output$ov_daytype <- renderPlotly(chart(daytype_average,"DayType",y="Average_per_day",lang=lang()))
  output$ov_insights <- renderUI({
    wd <- daytype_average$Average_per_day[daytype_average$DayType=="Weekday"]
    we <- daytype_average$Average_per_day[daytype_average$DayType=="Weekend"]
    div(class="editorial-notes",div(class="editorial-note",strong(peak(time_cube,"Hour")),p(t("hour_annotation"))),
      div(class="editorial-note",strong(peak(time_cube,"Weekday")),p(t("weekday_annotation"))),
      div(class="editorial-note",strong(paste0("+",percent(100*(wd/we-1),1))),p(t("daytype_annotation")),tags$small(t("insight_daytype",number(wd),number(we),percent(100*(wd/we-1),1)))))
  })
  ta_filtered <- reactive({req(input$ta_dates); filter_cube(time_cube,input$ta_month,input$ta_weekday,input$ta_daytype,input$ta_hour,input$ta_base,input$ta_dates)})
  ta_calendar <- reactive({req(input$ta_dates); filter_cube(calendar,input$ta_month,input$ta_weekday,input$ta_daytype,dates=input$ta_dates)})
  ta_daily <- reactive({left_join(select(ta_calendar(),Date),aggregate_trips(ta_filtered(),"Date"),by="Date") %>% mutate(Total_Trips=replace_na(Total_Trips,0)) %>% arrange(Date)})
  observeEvent(input$ta_reset,{
    for(id in c("ta_month","ta_weekday","ta_daytype","ta_hour","ta_base")) updateSelectInput(session,id,selected="All")
    updateDateRangeInput(session,"ta_dates",start=min(calendar$Date),end=max(calendar$Date))
  })
  output$ta_kpis <- renderUI({df <- ta_filtered();days <- nrow(ta_calendar());kpis(
    kpi(t("filtered_trips"),number(sum(df$Total_Trips)),t("exact_intersection")),
    kpi(t("average_day"),if(days) number(sum(df$Total_Trips)/days) else t("no_dates"),t("eligible_days",number(days))),
    kpi(t("peak_hour"),peak(df,"Hour")),kpi(t("peak_day"),peak(df,"Date")),kpi(t("peak_base"),peak(df,"Base")))})
  output$ta_context <- renderText(if(!nrow(ta_filtered())) t("empty") else t("filtered_rows",number(nrow(ta_filtered()))))
  output$ta_hour_plot <- renderPlotly(chart(aggregate_trips(ta_filtered(),"Hour"),"Hour","line",lang=lang()))
  output$ta_month_plot <- renderPlotly(chart(aggregate_trips(ta_filtered(),"Month"),"Month",lang=lang()))
  output$ta_weekday_plot <- renderPlotly(chart(aggregate_trips(ta_filtered(),"Weekday"),"Weekday",lang=lang()))
  output$ta_daily <- renderPlotly(chart(ta_daily(),"Date","line",lang=lang()))
  output$ta_heatmap <- renderPlotly(heat_chart(aggregate_trips(ta_filtered(),c("Hour","Weekday")),"Hour","Weekday",lang()))
  output$ta_table <- renderDT(table_view(ta_filtered(),lang()))
  output$ta_download <- downloadHandler(filename=function() "filtered_demand.csv",content=function(file) write_csv(ta_filtered(),file))
  geo_all <- reactive({aggregate_trips(filter_cube(geo_cube,month=input$geo_month,base=input$geo_base),c("Lat_Grid","Lon_Grid")) %>%
    arrange(desc(Total_Trips),Lat_Grid,Lon_Grid) %>% mutate(Rank=row_number(),Share=100*Total_Trips/sum(Total_Trips))})
  geo_filtered <- reactive({req(input$geo_top_n); head(geo_all(),max(1,min(nrow(geo_all()),as.integer(input$geo_top_n))))})
  observeEvent(input$geo_reset,{updateSelectInput(session,"geo_month",selected="All");updateSelectInput(session,"geo_base",selected="All");updateNumericInput(session,"geo_top_n",value=20)})
  output$geo_kpis <- renderUI({all <- geo_all();selected <- geo_filtered();total <- sum(all$Total_Trips)
    kpis(kpi(t("geo_total"),number(total)),kpi(t("active_cells"),number(nrow(all))),kpi(t("displayed_cells"),number(nrow(selected))),kpi(t("displayed_share"),if(total) percent(100*sum(selected$Total_Trips)/total) else t("no_trips")))})
  output$geo_map <- renderLeaflet({
    df <- geo_filtered();l <- lang()
    map <- leaflet(options=leafletOptions(preferCanvas=FALSE,scrollWheelZoom=FALSE)) %>% addTiles() %>% setView(-73.98,40.75,11)
    if(!nrow(df)) return(map)
    labels <- paste0(t("Rank"),": ",number(df$Rank)," \u00b7 ",t("Total_Trips"),": ",number(df$Total_Trips)," \u00b7 ",t("popup_share"),": ",percent(df$Share)," \u00b7 ",t("Latitude"),": ",number(df$Lat_Grid,4)," \u00b7 ",t("Longitude"),": ",number(df$Lon_Grid,4))
    map <- map %>% addCircleMarkers(lng=df$Lon_Grid,lat=df$Lat_Grid,radius=3+18*sqrt(df$Total_Trips/max(df$Total_Trips)),color="#41413F",fillColor="#41413F",fillOpacity=.45,weight=1,label=labels,popup=labels) %>% addControl(t("map_note"),position="bottomleft")
    htmlwidgets::onRender(map,sprintf("function(el){el.querySelector('.leaflet-control-zoom-in').title=%s;el.querySelector('.leaflet-control-zoom-out').title=%s;}",jsonlite::toJSON(t("zoom_in"),auto_unbox=TRUE),jsonlite::toJSON(t("zoom_out"),auto_unbox=TRUE)))
  })
  output$geo_rank <- renderPlotly({df <- head(geo_filtered(),20);df$Cell <- paste0("#",df$Rank);df <- df[rev(seq_len(nrow(df))),];chart(df,"Cell",lang=lang(),horizontal=TRUE)})
  output$geo_table <- renderDT(table_view(geo_filtered(),lang()))
  output$geo_download <- downloadHandler(filename=function() "filtered_grid_cells.csv",content=function(file) write_csv(geo_filtered(),file))
  ba_context <- reactive(filter_cube(time_cube,month=input$ba_month,weekday=input$ba_weekday,daytype=input$ba_daytype))
  ba_filtered <- reactive(filter_cube(ba_context(),base=input$ba_base))
  ba_ranking <- reactive(aggregate_trips(ba_context(),"Base") %>% arrange(desc(Total_Trips),Base) %>% mutate(Rank=min_rank(desc(Total_Trips)),Share=100*Total_Trips/sum(Total_Trips)))
  observeEvent(input$ba_reset,{for(id in c("ba_base","ba_month","ba_weekday","ba_daytype")) updateSelectInput(session,id,selected="All")})
  output$ba_kpis <- renderUI({total <- sum(ba_filtered()$Total_Trips);denominator <- sum(ba_context()$Total_Trips)
    days <- nrow(filter_cube(calendar,month=input$ba_month,weekday=input$ba_weekday,daytype=input$ba_daytype))
    ranks <- ba_ranking();rank <- if(input$ba_base=="All") t("all_bases") else if(input$ba_base %in% ranks$Base) number(ranks$Rank[ranks$Base==input$ba_base]) else t("no_trips")
    kpis(kpi(t("Total_Trips"),number(total)),kpi(t("base_share"),if(denominator) percent(100*total/denominator) else t("no_trips"),t("same_calendar")),kpi(t("Rank"),rank),kpi(t("average_day"),if(days) number(total/days) else t("no_dates"),t("eligible_days",number(days))))})
  base_context_chart <- function(y) {df <- ba_ranking();df <- df[rev(seq_len(nrow(df))),];chart(df,"Base",y=y,lang=lang(),horizontal=TRUE,colors=ifelse(input$ba_base!="All" & df$Base==input$ba_base,"#276EF1","#3D3D3B"))}
  output$ba_rank_plot <- renderPlotly(base_context_chart("Total_Trips"))
  output$ba_share <- renderPlotly(base_context_chart("Share"))
  output$ba_month_plot <- renderPlotly(heat_chart(aggregate_trips(ba_filtered(),c("Base","Month")),"Month","Base",lang()))
  output$ba_weekday_plot <- renderPlotly(heat_chart(aggregate_trips(ba_filtered(),c("Base","Weekday")),"Weekday","Base",lang()))
  if(model_available) {
    output$model_kpis <- renderUI({
      best <- which.min(model_metrics$RMSE)
      tags$table(class="model-summary",tags$thead(tags$tr(lapply(c("Model","MAE","RMSE","R2","MAPE"),function(k) tags$th(t(k))),tags$th())),
        tags$tbody(lapply(seq_len(nrow(model_metrics)),function(i) tags$tr(class=if(i==best) "model-best" else NULL,tags$td(display_values(model_metrics$Model[i],lang())),tags$td(number(model_metrics$MAE[i],2)),tags$td(number(model_metrics$RMSE[i],2)),tags$td(number(model_metrics$R2[i],3)),tags$td(number(model_metrics$MAPE[i],2)),tags$td(if(i==best) t("best_rmse"))))))
    })
    output$model_comparison <- renderText({best <- model_metrics$Model[which.min(model_metrics$RMSE)];if(best=="Seasonal naive (last week)") t("model_baseline_wins") else t("model_result",display_values(best,lang()))})
    model_period_text <- reactive(t("model_period",fmt_date(model_metrics$Train_Start[1],lang()),fmt_date(model_metrics$Train_End[1],lang()),fmt_date(model_metrics$Test_Start[1],lang()),fmt_date(model_metrics$Test_End[1],lang()),number(nrow(predictions))))
    output$model_period <- renderText(model_period_text())
    output$method_model_period <- renderText(model_period_text())
    output$method_model_features <- renderText({
      features <- strsplit(model_metadata$Features[model_metadata$Model=="XGBoost"],"; ",fixed=TRUE)[[1]]
      paste0(t("Feature"),": ",paste(display_values(features,lang()),collapse="; "),".")
    })
    selected_prediction <- reactive({value <- input$prediction_model;if(is.null(value)) value <- "All";if(value=="All") model_series else {req(value %in% model_series);value}})
    selected_importance <- reactive({value <- input$importance_model;if(is.null(value)) value <- "Regression tree";req(value %in% importance_models);importance[importance$Model==value,]})
    output$model_actual <- renderPlotly({
      times <- as.POSIXct(predictions$Date,tz="UTC")+predictions$Hour*3600
      colors <- c(Actual="#171717",Seasonal_Naive="#93938F",Regression_Tree="#A3A8AF",Random_Forest="#39766F",XGBoost="#276EF1")
      p <- plot_ly()
      for(key in c("Actual",selected_prediction())) p <- add_trace(p,x=times,y=predictions[[key]],type="scatter",mode="lines",name=t(key),line=list(color=colors[[key]],width=if(key=="Actual") 1.6 else 1.2),text=paste0(fmt_dimension(times,"Time",lang()),"<br>",t(key),": ",number(predictions[[key]])),hovertemplate="%{text}<extra></extra>")
      p <- plot_style(p,lang(),t("Total_Trips"));idx <- unique(round(seq(1,length(times),length.out=5)));layout(p,xaxis=list(tickvals=times[idx],ticktext=fmt_date(as.Date(times[idx]),lang())))
    })
    output$model_residual <- renderPlotly({df <- predictions;df$Time <- as.POSIXct(df$Date,tz="UTC")+df$Hour*3600;chart(df,"Time","line","Residual",lang())})
    output$model_importance <- renderPlotly(chart(selected_importance()[rev(seq_len(nrow(selected_importance()))),],"Feature",y="Importance",lang=lang(),horizontal=TRUE))
    output$model_table <- renderDT(table_view(model_metrics,lang(),simple=TRUE) %>% formatRound(c("Runtime_Seconds","Tuning_Seconds","Fit_Seconds","Prediction_Seconds"),2,mark=if(lang()=="vi") "." else ",",dec.mark=if(lang()=="vi") "," else "."))
  }
  output$de_description <- renderText({req(input$de_dataset);key <- switch(input$de_dataset,"Time cube"="time_description","Geographic cube"="geo_description","aggregate_description");t("rows_description",number(nrow(explorer[[input$de_dataset]])),t(key))})
  output$de_table <- renderDT({req(input$de_dataset);table_view(explorer[[input$de_dataset]],lang())})
  output$de_download <- downloadHandler(filename=function() paste0(gsub(" ","_",tolower(input$de_dataset)),".csv"),content=function(file) {
    df <- explorer[[input$de_dataset]];rows <- input$de_table_rows_all
    if(!is.null(rows)) df <- df[rows,,drop=FALSE]
    write_csv(df,file)
  })
  output$quality_clean <- renderDT(table_view(cleaning_quality,lang(),simple=TRUE))
  output$quality_coord <- renderDT(table_view(coordinate_quality,lang(),simple=TRUE))
  output$quality_location <- renderDT(table_view(location_summary,lang(),simple=TRUE))
}
shinyApp(ui,server)
