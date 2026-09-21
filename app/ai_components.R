# Saved analytical outputs only; DBSCAN and forecasting never run in a Shiny session.
ai_available <- all(file.exists(out(c("anomaly/anomalies.csv","clusters/hotspot_clusters.csv","clusters/cluster_summary.csv"))))
if(ai_available) {
  anomaly_data <- read_checked(out("anomaly/anomalies.csv"),c("DateTime","Observed","Expected","Residual","Residual_Percent","Anomaly_Score","Is_Anomaly","Direction"))
  cluster_cells <- read_checked(out("clusters/hotspot_clusters.csv"),c("Cluster_ID","Lat","Lon","Total_Trips","Cluster_Total_Trips","Cluster_Share"))
  cluster_summary <- read_checked(out("clusters/cluster_summary.csv"),c("Cluster_ID","Grid_Cells","Total_Trips","Share","Center_Lat","Center_Lon","Rank"))
}
anomaly_page <- function() nav_panel(label("nav_anomaly"),value="anomaly",div(class="page",
  heading("nav_anomaly","anomaly_subtitle"),
  if(ai_available) tagList(p(class="prose",label("anomaly_meaning")),p(class="context",label("anomaly_method")),
    filter_panel(choice("an_month","Month","Sep"),choice("an_direction","Direction",c("Higher than expected","Lower than expected")),
      numericInput("an_score",label("min_score"),value=0,min=0,step=.5),reset_button("an_reset")),
    uiOutput("an_kpis"),p(class="context",label("anomaly_filter_note")),
    chart_card("anomaly_chart","an_chart",360),table_section("anomaly_observations","an_table"),
    p(class="prose",label("anomaly_limits")),p(class="context",textOutput("an_zero_note"))) else p(label("ai_missing"))))
cluster_panel <- function() if(ai_available) tagList(p(class="context",label("cluster_method")),
  uiOutput("cluster_kpis"),p(class="context",textOutput("cluster_insight")),
  div(class="chart-frame",h4(label("AI Clusters")),leafletOutput("cluster_map",height="520px")),
  table_section("cluster_summary","cluster_table"),p(class="prose",label("cluster_limits"))) else p(label("ai_missing"))
ai_server <- function(input,output,session,lang) {
  t <- function(key,...) tr(key,lang(),...)
  number <- function(x,digits=0) fmt_number(x,lang(),digits)
  percent <- function(x) fmt_percent(x,lang())
  observeEvent(lang(),{
    defs <- list(geo_mode=c("Grid Density","AI Clusters"),an_month="Sep",an_direction=c("Higher than expected","Lower than expected"))
    for(id in names(defs)) {
      value <- isolate(input[[id]])
      if(is.null(value)) value <- if(id=="geo_mode") "Grid Density" else "All"
      updateSelectInput(session,id,choices=localized_choices(defs[[id]],lang(),all=id!="geo_mode"),selected=value)
    }
  })
  if(!ai_available) return(invisible(NULL))
  observeEvent(input$an_reset,{
    updateSelectInput(session,"an_month",selected="All");updateSelectInput(session,"an_direction",selected="All");updateNumericInput(session,"an_score",value=0)
  })
  an_context <- reactive({
    df <- anomaly_data
    if(!is.null(input$an_month) && input$an_month!="All") df <- df[month_levels[as.integer(format(df$DateTime,"%m"))-3L]==input$an_month,]
    df
  })
  an_filtered <- reactive({
    df <- an_context()
    if(!is.null(input$an_direction) && input$an_direction!="All") df <- df[df$Direction==input$an_direction,]
    minimum <- input$an_score;if(is.null(minimum)||!is.finite(minimum)) minimum <- 0
    df[df$Anomaly_Score>=max(0,minimum),]
  })
  output$an_zero_note <- renderText(t("zero_note",number(sum(anomaly_data$Zero_Filled))))
  output$an_kpis <- renderUI({
    df <- an_filtered();pos <- df$Residual[df$Residual>0];neg <- df$Residual[df$Residual<0]
    kpis(kpi(t("anomaly_count"),number(sum(df$Is_Anomaly)),t("scored_hours",number(nrow(df)))),
      kpi(t("anomaly_rate"),if(nrow(df)) percent(100*mean(df$Is_Anomaly)) else t("no_trips")),
      kpi(t("positive_deviation"),if(length(pos)) number(max(pos),1) else t("not_available")),
      kpi(t("negative_deviation"),if(length(neg)) number(min(neg),1) else t("not_available")))
  })
  output$an_chart <- renderPlotly({
    df <- an_context();validate(need(nrow(df)>0,t("empty")))
    p <- plot_ly()
    for(key in c("Observed","Expected")) p <- add_trace(p,x=df$DateTime,y=df[[key]],type="scatter",mode="lines",name=t(key),
      line=list(color=if(key=="Observed") "#252525" else "#39766F",width=1.4),
      text=paste0(fmt_dimension(df$DateTime,"Time",lang()),"<br>",t(key),": ",number(df[[key]],1)),hovertemplate="%{text}<extra></extra>")
    flagged <- an_filtered();flagged <- flagged[flagged$Is_Anomaly,]
    if(nrow(flagged)) p <- add_trace(p,x=flagged$DateTime,y=flagged$Observed,type="scatter",mode="markers",name=t("anomaly_count"),
      marker=list(color="#B65335",size=8,symbol="diamond"),text=paste0(fmt_dimension(flagged$DateTime,"Time",lang()),"<br>",t("Residual"),": ",number(flagged$Residual,1),"<br>",t("Anomaly_Score"),": ",number(flagged$Anomaly_Score,2)),hovertemplate="%{text}<extra></extra>")
    idx <- unique(round(seq(1,nrow(df),length.out=5)))
    layout(plot_style(p,lang(),t("Total_Trips")),yaxis=list(tickvals=pretty(range(c(0,df$Observed,df$Expected)),4),ticktext=number(pretty(range(c(0,df$Observed,df$Expected)),4))),xaxis=list(tickvals=df$DateTime[idx],ticktext=fmt_date(as.Date(df$DateTime[idx]),lang())))
  })
  output$an_table <- renderDT({
    df <- an_filtered()[,c("DateTime","Observed","Expected","Residual","Residual_Percent","Anomaly_Score","Is_Anomaly","Direction","Zero_Filled")]
    df$DateTime <- format(df$DateTime,"%Y-%m-%d %H:%M",tz="UTC")
    df$Is_Anomaly <- ifelse(df$Is_Anomaly,t("flagged"),t("not_flagged"))
    df$Zero_Filled <- ifelse(df$Zero_Filled,t("zero_filled"),t("recorded_hour"))
    table_view(df,lang())
  })
  # Membership is learned once from Apr-Sep; existing filters change volume only.
  selected_cells <- reactive({
    volumes <- aggregate_trips(filter_cube(geo_cube,month=input$geo_month,base=input$geo_base),c("Lat_Grid","Lon_Grid")) |>
      mutate(Lat=round(Lat_Grid,2),Lon=round(Lon_Grid,2))
    inner_join(select(cluster_cells,Cluster_ID,Lat,Lon),select(volumes,Lat,Lon,Total_Trips),by=c("Lat","Lon"))
  })
  selected_clusters <- reactive({
    df <- selected_cells()
    df |> group_by(Cluster_ID) |> summarise(Grid_Cells=n(),Center_Lat=weighted.mean(Lat,Total_Trips),Center_Lon=weighted.mean(Lon,Total_Trips),Total_Trips=sum(Total_Trips),.groups="drop") |>
      mutate(Share=100*Total_Trips/sum(Total_Trips)) |> arrange(Cluster_ID==0,desc(Total_Trips))
  })
  cluster_name <- function(id) ifelse(id==0,t("noise"),paste(t("Cluster_ID"),id))
  output$cluster_kpis <- renderUI({df <- selected_clusters();noise <- df[df$Cluster_ID==0,]
    kpis(kpi(t("geo_total"),number(sum(df$Total_Trips))),kpi(t("cluster_count"),number(sum(df$Cluster_ID>0))),
      kpi(t("noise_cells"),number(sum(noise$Grid_Cells))),kpi(t("noise_share"),percent(sum(noise$Share))))
  })
  output$cluster_insight <- renderText({df <- selected_clusters();df <- df[df$Cluster_ID>0,];if(!nrow(df)) return(t("empty"));t("cluster_insight",number(df$Cluster_ID[1]),percent(df$Share[1]))})
  output$cluster_map <- renderLeaflet({
    df <- selected_cells() |> left_join(select(selected_clusters(),Cluster_ID,Cluster_Total_Trips=Total_Trips,Share,Center_Lat,Center_Lon),by="Cluster_ID")
    map <- leaflet(options=leafletOptions(scrollWheelZoom=FALSE,preferCanvas=FALSE)) |> addTiles() |> setView(-73.98,40.75,11)
    if(!nrow(df)) return(map)
    ids <- sort(unique(cluster_cells$Cluster_ID));palette <- c("#ADADA8","#276EF1","#39766F","#A86435")
    colors <- setNames(rep(palette,length.out=length(ids)),ids)
    pop <- paste0(cluster_name(df$Cluster_ID),"<br>",t("Total_Trips"),": ",number(df$Cluster_Total_Trips),"<br>",t("Share"),": ",percent(df$Share),"<br>",t("Center_Lat"),": ",number(df$Center_Lat,4),"<br>",t("Center_Lon"),": ",number(df$Center_Lon,4))
    map <- map |> addCircleMarkers(lng=df$Lon,lat=df$Lat,radius=ifelse(df$Cluster_ID==0,2,3+8*sqrt(df$Total_Trips/max(df$Total_Trips))),
      color=unname(colors[as.character(df$Cluster_ID)]),fillOpacity=.65,stroke=FALSE,label=cluster_name(df$Cluster_ID),popup=pop) |>
      addLegend(position="bottomleft",colors=unname(colors),labels=cluster_name(ids),opacity=1)
    htmlwidgets::onRender(map,sprintf("function(el){el.querySelector('.leaflet-control-zoom-in').title=%s;el.querySelector('.leaflet-control-zoom-out').title=%s;}",jsonlite::toJSON(t("zoom_in"),auto_unbox=TRUE),jsonlite::toJSON(t("zoom_out"),auto_unbox=TRUE)))
  })
  output$cluster_table <- renderDT({df <- selected_clusters();df$Cluster_ID <- cluster_name(df$Cluster_ID);table_view(df,lang())})
  # Return reactives for direct server verification without exposing app internals to the browser.
  list(an_filtered=an_filtered,an_context=an_context,selected_cells=selected_cells,selected_clusters=selected_clusters)
}
