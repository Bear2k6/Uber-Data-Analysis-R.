# Presentation only: canonical data never leave the analytical layer modified.
label <- function(key) span(`data-i18n`=key,tr(key))
heading <- function(title,subtitle) div(class="dashboard-header",h2(label(title)),p(label(subtitle)))
section_title <- function(n,key) h3(class="section-heading",span(class="section-number",n),label(key))
chart_card <- function(title,id,height=280) div(class="chart-frame",h4(label(title)),plotlyOutput(id,height=paste0(height,"px")))
pair <- function(...) div(class="chart-grid",...)
kpi <- function(label,value,note="") div(class="metric-item",div(class="metric-label",label),div(class="metric-value",value),div(class="metric-note",note))
kpis <- function(...) div(class="metric-strip",...)
choice <- function(id,key,values) selectInput(id,label(key),localized_choices(values,dimension=key),selectize=FALSE)
reset_button <- function(id) actionButton(id,label("reset"),class="reset-action")
filter_panel <- function(...) div(class="filter-panel",div(class="filter-caption",label("filters")),div(class="filter-controls",...))
table_section <- function(key,id,download=NULL,download_key=NULL) div(class="table-section",div(class="table-heading",h4(label(key)),if(!is.null(download)) downloadButton(download,label(download_key))),DTOutput(id))
plot_style <- function(p,lang,ytitle=NULL) {
  config(layout(p,paper_bgcolor="rgba(0,0,0,0)",plot_bgcolor="rgba(0,0,0,0)",
    font=list(family="Segoe UI, Arial, sans-serif",size=12,color="#252525"),
    margin=list(l=65,r=20,t=15,b=65),hoverlabel=list(bgcolor="white",font=list(color="#111111")),
    separators=if(lang=="vi") ",." else ".,",
    xaxis=list(title="",showgrid=FALSE,zeroline=FALSE,automargin=TRUE),
    yaxis=list(title=ytitle,gridcolor="#E8E8E4",zeroline=FALSE,automargin=TRUE),
    legend=list(orientation="h",x=0,y=1.12,title=list(text=""))),displayModeBar=FALSE,responsive=TRUE)
}
chart <- function(df,x,kind="bar",y="Total_Trips",lang="vi",colors=NULL,horizontal=FALSE) {
  validate(need(nrow(df)>0,tr("empty",lang)))
  labels <- fmt_dimension(df[[x]],x,lang)
  digits <- if(y %in% c("Share","Average_per_day")) 1 else 0
  hover <- paste0(labels,"<br>",fmt_number(df[[y]],lang,digits)," \u00b7 ",tr(y,lang))
  xx <- if(inherits(df[[x]],c("Date","POSIXct")) || is.numeric(df[[x]])) df[[x]] else labels
  if(is.null(colors)) colors <- "#3D3D3B"
  if(kind=="line" && nrow(df)==1) p <- plot_ly(x=xx,y=df[[y]],type="scatter",mode="markers",marker=list(color="#333331",size=6),text=hover,hovertemplate="%{text}<extra></extra>")
  else if(kind=="line") p <- plot_ly(x=xx,y=df[[y]],type="scatter",mode=if(nrow(df)>1) "lines" else "markers",line=list(color="#333331",width=1.6),text=hover,hovertemplate="%{text}<extra></extra>")
  else if(horizontal) p <- plot_ly(x=df[[y]],y=labels,type="bar",textposition="none",orientation="h",marker=list(color=colors),text=hover,hovertemplate="%{text}<extra></extra>")
  else p <- plot_ly(x=xx,y=df[[y]],type="bar",textposition="none",marker=list(color=colors),text=hover,hovertemplate="%{text}<extra></extra>")
  p <- plot_style(p,lang,if(horizontal) NULL else tr(y,lang))
  ticks <- pretty(range(c(if(kind=="bar") 0,df[[y]]),finite=TRUE),4)
  if(y=="Importance") ticks <- signif(seq(0,max(df[[y]]),length.out=3),2)
  axis <- list(tickvals=ticks,ticktext=fmt_number(ticks,lang,if(y=="Share") 0 else 0))
  if(horizontal) p <- layout(p,xaxis=c(axis,list(title=tr(y,lang))),yaxis=list(categoryorder="array",categoryarray=labels)) else p <- layout(p,yaxis=axis)
  if(is.character(xx)) p <- layout(p,xaxis=list(categoryorder="array",categoryarray=unique(labels)))
  if(inherits(df[[x]],"Date")) {idx <- unique(round(seq(1,nrow(df),length.out=min(6,nrow(df)))));p <- layout(p,xaxis=list(tickvals=df[[x]][idx],ticktext=fmt_date(df[[x]][idx],lang)))}
  if(inherits(df[[x]],"POSIXct")) {idx <- unique(round(seq(1,nrow(df),length.out=min(5,nrow(df)))));p <- layout(p,xaxis=list(tickvals=df[[x]][idx],ticktext=fmt_date(as.Date(df[[x]][idx]),lang)))}
  p
}
heat_chart <- function(df,x,y,lang="vi") {
  validate(need(nrow(df)>0,tr("empty",lang)))
  # Preserve the aggregation; this reshape is used only by the heatmap widget.
  xs <- unique(df[[x]]);ys <- unique(df[[y]])
  z <- matrix(NA_real_,length(ys),length(xs));text <- matrix("",length(ys),length(xs))
  for(i in seq_len(nrow(df))) {r <- match(df[[y]][i],ys);c <- match(df[[x]][i],xs);z[r,c] <- df$Total_Trips[i];text[r,c] <- paste0(fmt_dimension(df[[x]][i],x,lang)," \u00b7 ",fmt_dimension(df[[y]][i],y,lang),"<br>",tr("pickup_count",lang,fmt_number(df$Total_Trips[i],lang)))}
  ticks <- pretty(range(z,na.rm=TRUE),3)
  p <- plot_ly(x=fmt_dimension(xs,x,lang),y=fmt_dimension(ys,y,lang),z=z,type="heatmap",colorscale=list(list(0,"#F0F0EC"),list(1,"#353533")),text=text,hovertemplate="%{text}<extra></extra>",colorbar=list(title=list(text=tr("Total_Trips",lang)),tickvals=ticks,ticktext=fmt_number(ticks,lang),thickness=10))
  plot_style(p,lang)
}
display_table <- function(df,lang) {
  for(n in names(df)) {
    if(inherits(df[[n]],"Date")) df[[n]] <- as.character(df[[n]])
    else if(is.character(df[[n]]) || is.factor(df[[n]])) df[[n]] <- display_values(df[[n]],lang,n)
  }
  df
}
table_view <- function(df,lang="vi",simple=FALSE) {
  shown <- display_table(df,lang)
  widget <- datatable(shown,rownames=FALSE,filter=if(simple) "none" else "top",colnames=display_values(names(df),lang),
    options=list(pageLength=10,scrollX=TRUE,stateSave=TRUE,
      stateSaveCallback=JS("function(settings,data){var host=settings.nTable.closest('.datatables');var key=host.id+(host.id==='de_table'?':'+document.getElementById('de_dataset').value:'');window.dashboardTableStates=window.dashboardTableStates||{};window.dashboardTableStates[key]=data;}"),
      stateLoadCallback=JS("function(settings){var host=settings.nTable.closest('.datatables');var key=host.id+(host.id==='de_table'?':'+document.getElementById('de_dataset').value:'');return (window.dashboardTableStates||{})[key]||null;}"),dom=if(simple) "t" else "lftip",language=dt_language(lang)),
    callback=JS(sprintf("table.table().container().querySelectorAll('input').forEach(function(x){x.placeholder=%s; x.setAttribute('aria-label',%s);});",jsonlite::toJSON(tr("All",lang),auto_unbox=TRUE),jsonlite::toJSON(tr("dt_search",lang),auto_unbox=TRUE))))
  for(n in names(df)[vapply(df,inherits,logical(1),what="Date")]) {
    dates <- setNames(fmt_date(unique(df[[n]]),lang),as.character(unique(df[[n]])))
    mapping <- jsonlite::toJSON(as.list(dates),auto_unbox=TRUE)
    widget$x$options$columnDefs <- c(widget$x$options$columnDefs,list(list(targets=match(n,names(df))-1,render=JS(paste0("function(data,type){var dates=",mapping,";return type==='display' ? (dates[data] || data) : data;}")))))
  }
  if(all(c("Metric","Value") %in% names(df))) {
    values <- vapply(seq_len(nrow(df)),function(i) fmt_number(df$Value[i],lang,if(grepl("Latitude|Longitude",df$Metric[i])) 4 else if(grepl("Percentage",df$Metric[i])) 2 else 0),character(1))
    mapping <- jsonlite::toJSON(as.list(setNames(values,as.character(df$Value))),auto_unbox=TRUE)
    widget$x$options$columnDefs <- c(widget$x$options$columnDefs,list(list(targets=match("Value",names(df))-1,render=JS(paste0("function(data,type){var values=",mapping,";return type==='display' ? (values[data] || data) : data;}")))))
  }
  for(n in names(df)[vapply(df,is.numeric,logical(1))]) {
    if(n=="Value" && "Metric" %in% names(df)) next
    digits <- if(n %in% c("Lat_Grid","Lon_Grid","Latitude","Longitude")) 4 else if(n %in% c("MAE","RMSE","MAPE","Share")) 2 else if(n=="R2") 3 else if(n=="Value") 4 else 0
    widget <- formatRound(widget,n,digits,mark=if(lang=="vi") "." else ",",dec.mark=if(lang=="vi") "," else ".")
  }
  widget
}

