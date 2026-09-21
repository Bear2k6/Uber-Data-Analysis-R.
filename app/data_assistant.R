# Deterministic, allowlisted analytics. Input is the startup cache, never user code.
da_text <- function(en,vi,lang) if(identical(lang,"vi")) vi else en
da_normalize <- function(x) tolower(stringi::stri_trans_general(enc2utf8(x),"Latin-ASCII"))
da_language <- function(question,default="vi") {
  q <- da_normalize(question)
  if(grepl("\\b(khung|gio|thang|thu|nhieu|luot|tom tat|bat thuong|mo hinh|du lieu|bao nhieu|ngay|tai sao|thu hai|han che|do an|con hang|so sanh|khac nhau|vi sao|cum)\\b",q)) return("vi")
  if(grepl("\\b(what|which|how|compare|summarize|summary|why|show|rank|second|limitations|findings)\\b",q)) return("en")
  default
}
da_context <- function() list(Month="All",Base="All",Weekday="All",DayType="All",Hour="All",Dates=NULL,Direction="All",Min_Score=0)
da_validate_context <- function(ctx,data) {
  defaults <- da_context();ctx <- utils::modifyList(defaults,ctx)
  allowed <- list(Month=month_levels,Base=sort(unique(data$time$Base)),Weekday=weekday_levels,DayType=c("Weekday","Weekend"),Hour=as.character(0:23),Direction=c("Higher than expected","Lower than expected"))
  for(k in names(allowed)) if(!length(ctx[[k]]) || anyNA(ctx[[k]]) || any(!as.character(ctx[[k]]) %in% c("All",allowed[[k]]))) stop("Unsupported filter")
  if(!is.null(ctx$Dates)) {ctx$Dates <- as.Date(ctx$Dates);if(length(ctx$Dates)!=2 || anyNA(ctx$Dates)||ctx$Dates[1]>ctx$Dates[2]) stop("Invalid dates")}
  if(length(ctx$Min_Score)!=1 || !is.finite(ctx$Min_Score) || ctx$Min_Score<0) stop("Invalid score")
  ctx
}
da_filter <- function(df,ctx,dimensions=c("Month","Base","Weekday","DayType","Hour")) {
  for(k in intersect(dimensions,names(df))) if(!identical(as.character(ctx[[k]]),"All")) df <- df[as.character(df[[k]]) %in% as.character(ctx[[k]]),,drop=FALSE]
  if("Date" %in% names(df) && !is.null(ctx$Dates)) df <- df[df$Date>=ctx$Dates[1]&df$Date<=ctx$Dates[2],,drop=FALSE]
  df
}
da_result <- function(intent,context,facts=list(),sources="dashboard_time_cube.csv",status="ok",notes=character()) {
  list(intent=intent,status=status,scope=context,facts=facts,sources=unique(sources),notes=notes)
}
da_rank <- function(df,dimension) {
  d <- aggregate_trips(df,dimension)
  d <- d[order(-d$Total_Trips,as.character(d[[dimension]])),,drop=FALSE]
  d$Rank <- rank(-d$Total_Trips,ties.method="min")
  d$Share <- if(sum(d$Total_Trips)>0) 100*d$Total_Trips/sum(d$Total_Trips) else numeric(nrow(d))
  d
}
query_total_trips <- function(data,context=da_context()) da_result("total_trips",context,list(total=sum(da_filter(data$time,context)$Total_Trips)))
query_peak_dimension <- function(data,context,dimension,intent) {
  d <- da_rank(da_filter(data$time,context),dimension)
  da_result(intent,context,list(rows=d[d$Rank==1,,drop=FALSE],dimension=dimension),status=if(nrow(d)) "ok" else "empty")
}
query_peak_hour <- function(data,context=da_context()) query_peak_dimension(data,context,"Hour","peak_hour")
query_peak_month <- function(data,context=da_context()) query_peak_dimension(data,context,"Month","peak_month")
query_peak_weekday <- function(data,context=da_context()) query_peak_dimension(data,context,"Weekday","peak_weekday")
query_busiest_date <- function(data,context=da_context()) query_peak_dimension(data,context,"Date","busiest_date")
query_weekday_weekend <- function(data,context=da_context()) {
  df <- da_filter(data$time,context)
  # Denominators use eligible calendar days, including dates with zero pickups for the selected Base/hour.
  days <- da_filter(unique(data$time[c("Date","Month","Weekday","DayType")]),context)
  d <- merge(aggregate_trips(df,"DayType"),as.data.frame(table(days$DayType)),by.x="DayType",by.y="Var1",all.y=TRUE)
  names(d)[names(d)=="Freq"] <- "Days";d$Total_Trips[is.na(d$Total_Trips)] <- 0
  d$Average_per_day <- ifelse(d$Days>0,d$Total_Trips/d$Days,0)
  da_result("weekday_vs_weekend",context,list(rows=d),status=if(nrow(days)) "ok" else "empty",notes="daily_denominator")
}
query_base_rank <- function(data,context=da_context(),place=NULL) {
  d <- da_rank(da_filter(data$time,context),"Base")
  if(!is.null(place)) d <- d[d$Rank==place,,drop=FALSE]
  da_result("base_rank",context,list(rows=d,place=place),status=if(nrow(d)) "ok" else "empty")
}
query_compare_bases <- function(data,context=da_context(),bases) {
  denominator_context <- context;denominator_context$Base <- "All"
  d <- da_rank(da_filter(data$time,denominator_context),"Base")
  d <- d[d$Base %in% bases,,drop=FALSE]
  context$Base <- bases
  da_result("compare_bases",context,list(rows=d,denominator=sum(da_filter(data$time,denominator_context)$Total_Trips)),notes="base_share_denominator")
}
query_compare_months <- function(data,context=da_context(),months) {
  context$Month <- months;d <- da_rank(da_filter(data$time,context),"Month")
  d <- d[match(months,as.character(d$Month),nomatch=0),,drop=FALSE]
  da_result("compare_months",context,list(rows=d),status=if(nrow(d)) "ok" else "empty")
}
query_hotspots <- function(data,context=da_context(),limit=5L) {
  if(any(vapply(c("Weekday","DayType","Hour"),function(k)!identical(context[[k]],"All"),logical(1))) || !is.null(context$Dates))
    return(da_result("geographic_hotspots",context,sources="dashboard_geo_cube.csv",status="geo_scope"))
  df <- da_filter(data$geo,context,c("Month","Base"))
  d <- aggregate_trips(df,c("Lat_Grid","Lon_Grid"));d <- d[order(-d$Total_Trips,d$Lat_Grid,d$Lon_Grid),,drop=FALSE]
  d$Share <- if(sum(d$Total_Trips)>0)100*d$Total_Trips/sum(d$Total_Trips) else numeric(nrow(d))
  da_result("geographic_hotspots",context,list(rows=head(d,limit),total=sum(df$Total_Trips)),"dashboard_geo_cube.csv",if(nrow(d)) "ok" else "empty",notes="grid")
}
query_bbox <- function(data,context=da_context()) {
  r <- query_hotspots(data,context)
  if(r$status!="ok") return(r)
  r$intent <- "bbox_count";r$facts <- list(total=r$facts$total,all_pickups=sum(da_filter(data$time,context)$Total_Trips))
  r$facts$percent <- if(r$facts$all_pickups)100*r$facts$total/r$facts$all_pickups else 0;r
}
query_cluster_summary <- function(data,context=da_context(),limit=3L) {
  r <- query_hotspots(data,context)
  r$intent <- "cluster_summary";r$sources <- c("hotspot_clusters.csv","cluster_summary.csv","dashboard_geo_cube.csv")
  if(r$status!="ok") return(r)
  if(is.null(data$clusters)) return(da_result("cluster_summary",context,status="unavailable",sources=r$sources))
  v <- da_filter(data$geo,context,c("Month","Base")) |>
    dplyr::mutate(Lat=round(Lat_Grid,2),Lon=round(Lon_Grid,2)) |>
    dplyr::group_by(Lat,Lon) |> dplyr::summarise(Total_Trips=sum(Total_Trips),.groups="drop")
  joined <- dplyr::inner_join(v,data$clusters[c("Lat","Lon","Cluster_ID")],by=c("Lat","Lon"))
  d <- aggregate_trips(joined,"Cluster_ID");total <- sum(d$Total_Trips)
  d$Share <- 100*d$Total_Trips/total;d <- d[order(-d$Total_Trips,d$Cluster_ID),]
  positive <- d[d$Cluster_ID>0,];top <- head(positive,limit)
  da_result("cluster_summary",context,list(rows=top,clusters=nrow(positive),top_share=sum(top$Share),top_n=nrow(top),
    noise_trips=sum(d$Total_Trips[d$Cluster_ID==0]),noise_share=sum(d$Share[d$Cluster_ID==0]),total=total),r$sources,notes="clusters")
}
query_model_metrics <- function(data,context=da_context(),models=NULL) {
  if(is.null(data$metrics)) return(da_result("model_comparison",context,status="unavailable",sources="model_metrics.csv"))
  d <- data$metrics;if(!is.null(models)) d <- d[d$Model %in% models,]
  d <- d[order(d$RMSE,d$Model),]
  # Forecast comparison is a frozen all-city experiment; never pretend filters re-evaluate it.
  fixed <- da_context();fixed$Month <- "Sep"
  da_result("model_comparison",fixed,list(rows=d,requested_scope=context),"model_metrics.csv",notes=c("fixed_models","no_causality"))
}
query_feature_importance <- function(data,context=da_context(),model="XGBoost",limit=5L) {
  if(is.null(data$importance)) return(da_result("feature_importance",context,status="unavailable",sources="feature_importance.csv"))
  if(model=="Seasonal naive (last week)") return(da_result("feature_importance",context,status="baseline_features",sources="feature_importance.csv"))
  d <- data$importance[data$importance$Model==model,];d <- d[order(d$Rank),]
  fixed <- da_context();fixed$Month <- month_levels[1:5]
  da_result("feature_importance",fixed,list(model=model,rows=head(d,limit)),"feature_importance.csv",notes=c("importance","fixed_models"))
}
query_anomalies <- function(data,context=da_context(),kind="summary",limit=5L) {
  sources <- c("anomalies.csv","anomaly_summary.csv")
  if(is.null(data$anomalies)) return(da_result("anomaly_summary",context,status="unavailable",sources=sources))
  if(!identical(context$Base,"All")) return(da_result("anomaly_summary",context,status="anomaly_scope",sources=sources))
  df <- data$anomalies;df$Date <- as.Date(df$DateTime,tz="UTC");df$Hour <- as.integer(format(df$DateTime,"%H",tz="UTC"))
  calendar <- unique(data$time[c("Date","Month","Weekday","DayType")]);df <- merge(df,calendar,by="Date",all.x=TRUE)
  df <- da_filter(df,context);df <- df[df$Anomaly_Score>=context$Min_Score,]
  if(context$Direction!="All") df <- df[df$Direction==context$Direction,]
  flagged <- df[df$Is_Anomaly,]
  if(kind=="positive") flagged <- flagged[flagged$Residual>0,]
  if(kind=="negative") flagged <- flagged[flagged$Residual<0,]
  flagged <- flagged[if(kind=="positive") order(-flagged$Residual) else if(kind=="negative") order(flagged$Residual) else order(-flagged$Anomaly_Score),]
  scope <- context;scope$Month <- intersect(if(identical(context$Month,"All")) month_levels else context$Month,"Sep")
  if(!length(scope$Month)) scope$Month <- context$Month
  scope$Dates <- if(is.null(context$Dates)) as.Date(c("2014-09-08","2014-09-30")) else c(max(context$Dates[1],as.Date("2014-09-08")),min(context$Dates[2],as.Date("2014-09-30")))
  da_result("anomaly_summary",scope,list(evaluated=nrow(df),count=sum(df$Is_Anomaly),rate=if(nrow(df))100*mean(df$Is_Anomaly) else 0,
    rows=head(flagged,limit)[,c("DateTime","Observed","Expected","Residual","Anomaly_Score","Zero_Filled"),drop=FALSE],kind=kind),sources,if(nrow(df)) "ok" else "empty",notes=c("anomalies","zero_fill"))
}
query_dataset_summary <- function(data,context=da_context()) {
  df <- da_filter(data$time,context)
  da_result("dataset_summary",context,list(total=sum(df$Total_Trips),days=nrow(da_filter(unique(data$time[c("Date","Month","Weekday","DayType")]),context)),
    bases=length(unique(df$Base)),peak_hour=query_peak_hour(data,context)$facts$rows,
    peak_month=query_peak_month(data,context)$facts$rows,peak_base=query_base_rank(data,context,1)$facts$rows),status=if(nrow(df)) "ok" else "empty",notes="no_causality")
}
# The parser only produces values for this fixed registry. It never emits R/SQL.
da_intents <- c("dataset_summary","main_findings","total_trips","peak_hour","peak_month","peak_weekday","busiest_date","weekday_vs_weekend", "base_rank","compare_bases","compare_months","geographic_hotspots","bbox_count","cluster_summary","model_comparison","feature_importance","anomaly_summary","methodology","limitations","causal_limit","unsupported")
da_parse <- function(question,previous=NULL) {
  q <- da_normalize(trimws(question))
  answer <- list(intent="unsupported",months=character(),bases=character(),models=character(),kind="summary",limit=5L,place=NULL,dates=NULL)
  if(!nzchar(q)||nchar(q)>1000) return(answer)
  # Injection and unavailable-data questions fail closed even when they include a supported keyword.
  if(grepl("system\\s*\\(|eval\\s*\\(|source\\s*\\(|readlines\\s*\\(|sys.getenv|api.?key|secret|password|ignore .*instruction|bo qua .*huong dan|execute|run .*code|chay .*ma|<script|javascript:|\\b(sql|delete|unlink|revenue|fare|profit|income|earnings|doanh thu|gia cuoc|loi nhuan|driver|tai xe|manhattan|brooklyn|queens|bronx|airport|neighborhood|khu pho|202[0-9])\\b",q)) return(answer)
  if(grepl("\\b(january|february|march|october|november|december|oct|nov|dec|thang (1|2|3|10|11|12))\\b|\\b(201[0-35-9]|20[2-9][0-9])\\b",q)) return(answer)
  if(grepl("\\b(second|2nd|thu hai|hang hai|hang 2|vi tri 2)\\b",q) && grepl("place|rank|hang|vi tri",q)) {
    if(!is.null(previous) && previous$intent=="base_rank") {answer$intent <- "base_rank";answer$place <- 2L;answer$followup <- TRUE}
    return(answer)
  }
  month_patterns <- c("\\b(april|apr|thang 4|thang tu)\\b","\\b(may|thang 5|thang nam)\\b","\\b(june|jun|thang 6|thang sau)\\b","\\b(july|jul|thang 7|thang bay)\\b","\\b(august|aug|thang 8|thang tam)\\b","\\b(september|sep|thang 9|thang chin)\\b")
  answer$months <- month_levels[vapply(month_patterns,grepl,logical(1),x=q)]
  bm <- regmatches(toupper(q),gregexpr("B[0-9]{5}",toupper(q)))[[1]];answer$bases <- unique(bm)
  mp <- c("Seasonal naive (last week)"="baseline|seasonal|naive|co so|tuan truoc","Regression tree"="regression tree|cay hoi quy","Random Forest"="random forest|rung ngau nhien","XGBoost"="xgboost")
  answer$models <- names(mp)[vapply(mp,grepl,logical(1),x=q)]
  lim <- regmatches(q,regexec("(?:top|hang dau)\\s*([0-9]+)",q))[[1]];if(length(lim)>1) answer$limit <- max(1L,min(20L,as.integer(lim[2])))
  iso <- regmatches(q,regexpr("2014-[0-9]{2}-[0-9]{2}",q));if(length(iso)&&nzchar(iso)) answer$dates <- iso
  if(grepl("september 13|sep 13|13/9|13/09|13 thang 9",q)) answer$dates <- "2014-09-13"
  choose <- function(x) {answer$intent <- x;answer}
  if(grepl("why|cause|caused|tai sao|vi sao|nguyen nhan",q) && !grepl("model|baseline|mo hinh",q)) return(choose("causal_limit"))
  if(grepl("limitation|han che|gioi han",q)) return(choose("limitations"))
  if(grepl("method|phuong phap|thuat toan|ai .*used|ai .*dung",q)) return(choose("methodology"))
  if(grepl("feature|importance|dac trung|bien .*quan trong",q)) return(choose("feature_importance"))
  if(grepl("anomal|unusual|unexpected|bat thuong|higher than expected|cao hon ky vong",q)) {
    if(grepl("positive|higher|duong|cao hon",q)) answer$kind <- "positive"
    if(grepl("negative|lower|\\bam\\b|thap hon",q)) answer$kind <- "negative"
    return(choose("anomaly_summary"))
  }
  if(grepl("cluster|cum",q)) {if(!grepl("top|hang dau",q)) answer$limit <- if(grepl("most|largest|nhieu.*nhat|lon.*nhat",q))1L else 3L;return(choose("cluster_summary"))}
  if(grepl("model|forecast|rmse|baseline|xgboost|random forest|mo hinh|du bao",q)) return(choose("model_comparison"))
  if(grepl("bounding|bbox|inside .*nyc|trong .*nyc|khung .*nyc",q)) return(choose("bbox_count"))
  if(grepl("hotspot|grid|luoi|o don|diem don",q)) return(choose("geographic_hotspots"))
  if(length(answer$months)>1 && grepl("compare|so sanh|versus|vs",q)) return(choose("compare_months"))
  if(grepl("weekday.*weekend|weekend.*weekday|ngay thuong.*cuoi tuan|cuoi tuan.*ngay thuong",q)) return(choose("weekday_vs_weekend"))
  if(grepl("peak hour|busiest hour|khung gio|gio .*nhieu|gio cao diem",q)) return(choose("peak_hour"))
  if(grepl("which month|peak month|busiest month|thang nao|thang .*nhieu nhat",q)) return(choose("peak_month"))
  if(grepl("weekday|thu nao|thu .*nhieu nhat",q)) return(choose("peak_weekday"))
  if(grepl("busiest date|busiest day|ngay nao|ngay .*nhieu nhat",q)) return(choose("busiest_date"))
  if(grepl("base|dispatch|dieu phoi",q) || length(answer$bases)) return(choose(if(length(answer$bases)) "compare_bases" else "base_rank"))
  if(grepl("main findings|ket qua chinh|do an",q)) return(choose("main_findings"))
  if(grepl("summar|finding|tom tat|dang chu y|ket qua chinh",q)) return(choose("dataset_summary"))
  if(grepl("how many|total|bao nhieu|tong.*luot|tong.*chuyen",q) && grepl("pickup|trip|luot|chuyen|record|ban ghi",q)) return(choose("total_trips"))
  answer
}
da_execute <- function(parsed,data,context=da_context(),previous=NULL) {
  if(!parsed$intent %in% da_intents) return(da_result("unsupported",context,status="unsupported",sources="Data Assistant intent registry"))
  if(isTRUE(parsed$followup) && !is.null(previous)) context <- previous$scope
  if(length(parsed$months)) {context$Month <- parsed$months;context$Dates <- NULL}
  if(length(parsed$bases)) context$Base <- parsed$bases
  if(length(parsed$dates)) {date <- tryCatch(suppressWarnings(as.Date(parsed$dates)),error=function(e) as.Date(NA));if(anyNA(date)) return(da_result("unsupported",context,status="unsupported",sources="Data Assistant intent registry"));context$Dates <- rep(date,2);context$Month <- "All"}
  context <- tryCatch(da_validate_context(context,data),error=function(e) NULL)
  if(is.null(context)) return(da_result("unsupported",da_context(),status="unsupported",sources="Data Assistant intent registry"))
  intent <- parsed$intent
  if((context$Direction!="All" || context$Min_Score>0) && !intent %in% c("anomaly_summary","model_comparison","feature_importance","methodology","limitations","unsupported"))
    return(da_result(intent,context,status="anomaly_controls",sources="Data Assistant filter contract"))
  result <- switch(intent,
    total_trips=query_total_trips(data,context),peak_hour=query_peak_hour(data,context),peak_month=query_peak_month(data,context),
    peak_weekday=query_peak_weekday(data,context),busiest_date=query_busiest_date(data,context),weekday_vs_weekend=query_weekday_weekend(data,context),
    base_rank=query_base_rank(data,context,parsed$place),compare_bases=query_compare_bases(data,context,parsed$bases),
    compare_months=query_compare_months(data,context,parsed$months),geographic_hotspots=query_hotspots(data,context,parsed$limit),bbox_count=query_bbox(data,context),
    cluster_summary=query_cluster_summary(data,context,parsed$limit),model_comparison=query_model_metrics(data,context,if(length(parsed$models)>1)parsed$models else NULL),
    feature_importance=query_feature_importance(data,context,if(length(parsed$models))parsed$models[1] else "XGBoost",parsed$limit),
    anomaly_summary=query_anomalies(data,context,parsed$kind,parsed$limit),dataset_summary=query_dataset_summary(data,context),
    main_findings={
      parts <- list(query_dataset_summary(data,context),query_model_metrics(data,context),query_anomalies(data,context),query_cluster_summary(data,context))
      da_result("main_findings",context,list(parts=parts),unique(unlist(lapply(parts,`[[`,"sources"))))
    },
    causal_limit={x <- query_total_trips(data,context);x$intent <- "causal_limit";x$notes <- "no_causality";x},
    methodology=da_result(intent,da_context(),sources=c("model_metadata.csv","analytics_metadata.csv","anomaly_summary.csv")),
    limitations=da_result(intent,da_context(),sources=c("cleaning_quality.csv","coordinate_quality.csv","model_metadata.csv","anomaly_summary.csv","analytics_metadata.csv")),
    da_result("unsupported",context,status="unsupported",sources="Data Assistant intent registry"))
  result
}
# Facts-to-language rendering is deterministic; formatted values come only from query results.
da_scope_label <- function(ctx,lang) {
  parts <- c(da_text("April–September 2014","Tháng 4–9/2014",lang))
  for(k in c("Month","Base","Weekday","DayType","Hour")) if(!identical(as.character(ctx[[k]]),"All")) {
    values <- if(k=="Hour") sprintf("%02d:00",as.integer(ctx[[k]])) else display_values(ctx[[k]],lang,k)
    parts <- c(parts,paste0(tr(k,lang)," = ",paste(values,collapse=", ")))
  }
  if(!is.null(ctx$Dates)) parts <- c(parts,paste(fmt_date(ctx$Dates,lang),collapse=" – "))
  if(!identical(ctx$Direction,"All")) parts <- c(parts,display_values(ctx$Direction,lang))
  if(ctx$Min_Score>0) parts <- c(parts,paste0(tr("Anomaly_Score",lang)," ≥ ",fmt_number(ctx$Min_Score,lang,1)))
  paste(parts,collapse=" · ")
}
da_notes <- function(keys,lang) {
  vapply(keys,function(k) switch(k,
    daily_denominator=da_text("Daily averages use eligible calendar days, including zero-pickup days within the selected Base/hour scope.","Trung bình ngày dùng số ngày hợp lệ, kể cả ngày không có lượt trong phạm vi Base/giờ đã chọn.",lang),
    base_share_denominator=da_text("Shares use all Bases under the same time filters as denominator.","Mẫu số tỷ trọng là tổng của mọi Base với cùng bộ lọc thời gian.",lang),
    grid=da_text("Coordinates are fixed grid centers, not verified neighborhood names; shares include every represented NYC grid cell.","Tọa độ là tâm ô lưới, không phải tên khu phố đã xác minh; tỷ trọng tính trên toàn bộ ô NYC được biểu diễn.",lang),
    clusters=da_text("Membership is fixed from April–September weighted DBSCAN. Filters update pickup volume only. Cluster 0 is noise; all shares include noise in the denominator.","Nhãn cụm cố định từ DBSCAN có trọng số tháng 4–9. Bộ lọc chỉ cập nhật số lượt. Cụm 0 là nhiễu; mẫu số mọi tỷ trọng đều gồm nhiễu.",lang),
    fixed_models=da_text("This is the saved all-city experiment; dashboard Month/Base/hour filters do not re-evaluate models. September test RMSE ranks forecasting performance; anomaly model selection used August validation.","Đây là thí nghiệm toàn thành phố đã lưu; bộ lọc Tháng/Base/giờ không tính lại mô hình. RMSE kiểm thử tháng 9 xếp hạng dự báo; mô hình phát hiện bất thường được chọn bằng tập xác thực tháng 8.",lang),
    importance=da_text("Importance is normalized within each fitted model, not a causal effect or directly comparable across algorithms. XGBoost is the default when no model is named.","Mức quan trọng được chuẩn hóa trong từng mô hình, không phải tác động nhân quả hay thước đo so sánh trực tiếp giữa thuật toán. Mặc định là XGBoost nếu chưa nêu mô hình.",lang),
    anomalies=da_text("Absolute modified residual z-score > 3.5; September 1–7 calibrates, September 8–30 is evaluated. Rate uses selected scored hours; filters never change the detection threshold.","Modified z-score tuyệt đối của sai số > 3,5; ngày 1–7/9 hiệu chỉnh, ngày 8–30/9 được đánh giá. Tỷ lệ dùng các giờ đã chấm điểm trong phạm vi; bộ lọc không đổi ngưỡng phát hiện.",lang),
    zero_fill=da_text("Zero-filled hours are marked in the saved results; they may reflect missing coverage rather than confirmed zero demand.","Giờ được điền 0 được đánh dấu trong kết quả đã lưu; chúng có thể phản ánh thiếu dữ liệu thay vì nhu cầu thực sự bằng 0.",lang),
    no_causality=da_text("The dataset contains no weather, event or traffic variables, so causes cannot be established from these observations.","Dữ liệu không có biến thời tiết, sự kiện hay giao thông nên không thể xác định nguyên nhân từ các quan sát này.",lang),
    ""),character(1),USE.NAMES=TRUE)
}
da_render <- function(result,lang="vi") {
  say <- function(en,vi,...) sprintf(da_text(en,vi,lang),...)
  num <- function(x,d=0) fmt_number(x,lang,d)
  f <- result$facts;intent <- result$intent
  if(result$status!="ok") {
    response <- switch(result$status,
      empty=say("No evaluated observations match this scope. Try broader filters.","Không có quan sát được đánh giá phù hợp phạm vi này. Hãy mở rộng bộ lọc."),
      anomaly_controls=say("Direction/score filters apply only to anomaly queries. Turn off current filters or select a different context for this question.","Bộ lọc hướng/điểm chỉ áp dụng cho câu hỏi bất thường. Hãy tắt bộ lọc hiện tại hoặc chọn ngữ cảnh khác cho câu hỏi này."),
      geo_scope=say("The geographic cube supports Month and Base only. Date, weekday or hour filters cannot be applied reliably; turn off current filters or choose Geography context.","Bảng địa lý chỉ hỗ trợ Tháng và Base. Không thể áp dụng chính xác bộ lọc ngày, thứ hoặc giờ; hãy tắt bộ lọc hiện tại hoặc chọn ngữ cảnh Phân bố địa lý."),
      anomaly_scope=say("Saved anomalies describe all-city demand, not individual Bases. Set Base to All or turn off current filters.","Bất thường đã lưu mô tả nhu cầu toàn thành phố, không tách riêng Base. Hãy chọn tất cả Base hoặc tắt bộ lọc hiện tại."),
      unavailable=say("The required saved analysis output is unavailable. Generate that module's outputs before asking this question.","Chưa có kết quả phân tích đã lưu cần thiết. Hãy tạo kết quả của mô-đun tương ứng trước khi hỏi."),
      baseline_features=say("The seasonal-naive baseline copies the previous week's hour; it has no fitted feature-importance ranking.","Mô hình cơ sở sao chép giờ tương ứng tuần trước; không có bảng mức quan trọng đặc trưng đã huấn luyện."),
      say("I could not map this question safely to a supported query. Ask about pickups, time patterns, Bases, grids, clusters, saved forecasts or anomalies. I cannot run code or infer unavailable data.","Chưa thể ánh xạ an toàn câu hỏi này sang truy vấn hỗ trợ. Bạn có thể hỏi về lượt đón, thời gian, Base, ô lưới, cụm, dự báo đã lưu hoặc bất thường. Trợ lý không chạy mã hay suy đoán dữ liệu không có."))
    return(list(lines=response,notes=character(),scope=da_scope_label(result$scope,lang),sources=result$sources))
  }
  rows <- f$rows
  lines <- switch(intent,
    main_findings=unlist(lapply(f$parts,function(part) {x<-da_render(part,lang);c(paste0(say("Scope: ","Phạm vi: "),x$scope),x$lines,x$notes)}),use.names=FALSE),
    total_trips=say("There are %s recorded pickups in this scope.","Có %s lượt đón được ghi nhận trong phạm vi này.",num(f$total)),
    dataset_summary={
      c(say("This scope contains %s pickups across %s eligible days and %s Bases with records.","Phạm vi này có %s lượt đón, %s ngày hợp lệ và %s Base có bản ghi.",num(f$total),num(f$days),num(f$bases)),
        if(nrow(f$peak_hour)) say("Peak hour: %s, with %s pickups.","Giờ cao điểm: %s, với %s lượt đón.",paste(fmt_dimension(f$peak_hour$Hour,"Hour",lang),collapse=", "),num(f$peak_hour$Total_Trips[1])),
        if(nrow(f$peak_base)) say("Leading Base: %s, with %s pickups.","Base dẫn đầu: %s, với %s lượt đón.",paste(f$peak_base$Base,collapse=", "),num(f$peak_base$Total_Trips[1])))
    },
    peak_hour=,peak_month=,peak_weekday=,busiest_date={
      values <- fmt_dimension(rows[[f$dimension]],f$dimension,lang)
      say("Highest %s: %s, with %s pickups%s.","%s cao nhất: %s, với %s lượt đón%s.",tr(f$dimension,lang),paste(values,collapse=", "),num(rows$Total_Trips[1]),if(nrow(rows)>1)say(" each (tie)"," mỗi giá trị (đồng hạng)") else "")
    },
    weekday_vs_weekend=vapply(seq_len(nrow(rows)),function(i) say("%s: %s pickups / %s days = %s per day.","%s: %s lượt / %s ngày = %s lượt/ngày.",display_values(rows$DayType[i],lang,"DayType"),num(rows$Total_Trips[i]),num(rows$Days[i]),num(rows$Average_per_day[i],2)),character(1)),
    base_rank=vapply(seq_len(nrow(rows)),function(i) say("Rank %s — %s: %s pickups (%s%% of this scope).","Hạng %s — %s: %s lượt đón (%s%% phạm vi này).",num(rows$Rank[i]),rows$Base[i],num(rows$Total_Trips[i]),num(rows$Share[i],2)),character(1)),
    compare_bases=vapply(seq_len(nrow(rows)),function(i) say("%s: %s pickups; %s%% of %s pickups across all Bases under the same time filters.","%s: %s lượt; %s%% trong tổng %s lượt của mọi Base với cùng bộ lọc thời gian.",rows$Base[i],num(rows$Total_Trips[i]),num(rows$Share[i],2),num(f$denominator)),character(1)),
    compare_months=vapply(seq_len(nrow(rows)),function(i) say("%s: %s pickups.","%s: %s lượt đón.",display_values(rows$Month[i],lang),num(rows$Total_Trips[i])),character(1)),
    bbox_count=say("%s of %s pickups are represented inside the NYC bounding box (%s%%).","%s trong %s lượt được biểu diễn trong khung tọa độ NYC (%s%%).",num(f$total),num(f$all_pickups),num(f$percent,2)),
    geographic_hotspots=c(say("Top %s grid cells among %s represented pickups:","%s ô lưới đứng đầu trong %s lượt được biểu diễn:",num(nrow(rows)),num(f$total)),vapply(seq_len(nrow(rows)),function(i)say("(%s, %s): %s pickups; %s%%.","(%s, %s): %s lượt; %s%%.",num(rows$Lat_Grid[i],4),num(rows$Lon_Grid[i],4),num(rows$Total_Trips[i]),num(rows$Share[i],2)),character(1))),
    cluster_summary=c(say("The top %s of %s clusters account for %s%% of %s represented pickups. Noise: %s pickups (%s%%).","%s cụm đứng đầu trong %s cụm chiếm %s%% của %s lượt được biểu diễn. Nhiễu: %s lượt (%s%%).",num(f$top_n),num(f$clusters),num(f$top_share,2),num(f$total),num(f$noise_trips),num(f$noise_share,2)),
      vapply(seq_len(nrow(rows)),function(i)say("Cluster %s: %s pickups (%s%%).","Cụm %s: %s lượt (%s%%).",num(rows$Cluster_ID[i]),num(rows$Total_Trips[i]),num(rows$Share[i],2)),character(1))),
    model_comparison=c(say("Lowest September test RMSE among these models: %s (%s).","RMSE kiểm thử tháng 9 thấp nhất trong các mô hình này: %s (%s).",display_values(rows$Model[1],lang),num(rows$RMSE[1],2)),
      vapply(seq_len(nrow(rows)),function(i)say("%s — RMSE %s; MAE %s; MAPE %s%%; R² %s.","%s — RMSE %s; MAE %s; MAPE %s%%; R² %s.",display_values(rows$Model[i],lang),num(rows$RMSE[i],2),num(rows$MAE[i],2),num(rows$MAPE[i],2),num(rows$R2[i],3)),character(1)),
      say("Lower RMSE means smaller squared forecast errors on the same held-out hours; this comparison alone cannot establish why an algorithm wins. The tree and ensembles use different feature sets.","RMSE thấp hơn nghĩa là sai số bình phương dự báo nhỏ hơn trên cùng giờ kiểm thử; riêng so sánh này không xác định được vì sao thuật toán thắng. Cây và các mô hình tổ hợp dùng bộ đặc trưng khác nhau.")),
    feature_importance=c(say("Top features in %s:","Đặc trưng quan trọng nhất trong %s:",display_values(f$model,lang)),vapply(seq_len(nrow(rows)),function(i)paste0(display_values(rows$Feature[i],lang),": ",num(rows$Importance[i],2),"%"),character(1))),
    anomaly_summary=c(say("%s anomalies among %s selected scored hours (%s%%).","%s giờ bất thường trong %s giờ đã chấm điểm được chọn (%s%%).",num(f$count),num(f$evaluated),num(f$rate,2)),
      if(nrow(rows))vapply(seq_len(nrow(rows)),function(i)say("%s — observed %s; expected %s; deviation %s; score %s%s.","%s — quan sát %s; kỳ vọng %s; sai lệch %s; điểm %s%s.",fmt_dimension(rows$DateTime[i],"Time",lang),num(rows$Observed[i]),num(rows$Expected[i],2),num(rows$Residual[i],2),num(rows$Anomaly_Score[i],2),if(rows$Zero_Filled[i])say(" (zero-filled hour)"," (giờ được điền 0)")else""),character(1)) else say("No flagged hours match the requested direction.","Không có giờ bị đánh dấu phù hợp hướng yêu cầu.")),
    causal_limit=c(say("%s pickups are recorded in the stated scope.","Ghi nhận %s lượt đón trong phạm vi nêu trên.",num(f$total)),say("These observations do not establish a cause.","Các quan sát này không xác định được nguyên nhân.")),
    methodology=c(say("Supervised forecasting compares Seasonal Naive, Regression Tree, Random Forest and XGBoost using chronological training, validation and testing.","Dự báo so sánh cơ sở theo mùa, cây hồi quy, Random Forest và XGBoost với phân chia huấn luyện, xác thực và kiểm thử theo thời gian."),
      say("Unsupervised weighted DBSCAN groups pickup-density-connected grid centers. Fixed grid aggregation itself is not machine learning.","DBSCAN không giám sát có trọng số nhóm tâm ô liên thông theo mật độ lượt đón. Bản thân tổng hợp lưới cố định không phải học máy."),
      say("Residual anomaly screening uses Random Forest forecasts and a prior-week median/MAD reference; the local assistant uses an allowlisted query parser, not an independently trained forecasting model.","Sàng lọc bất thường dùng dự báo Random Forest và trung vị/MAD của sai số tuần trước; trợ lý cục bộ dùng bộ phân tích truy vấn giới hạn, không phải mô hình dự báo được huấn luyện riêng.")),
    limitations=c(say("Coverage is April–September 2014 Uber pickups, not all NYC transport. Pickup time, location and dispatch Base do not provide fares, trip duration, destinations or causal weather/event/traffic information.","Phạm vi là lượt đón Uber tháng 4–9/2014, không phải toàn bộ giao thông NYC. Giờ, vị trí và Base điều phối không cung cấp giá cước, thời lượng, điểm đến hay thông tin nhân quả về thời tiết/sự kiện/giao thông."),
      say("Duplicates are retained; grid centers are coarse; DBSCAN depends on parameters; forecasts are a historical experiment; anomaly reference uses one week and includes an explicitly marked zero-filled hour.","Giữ lại bản ghi trùng; tâm lưới là xấp xỉ; DBSCAN phụ thuộc tham số; dự báo là thí nghiệm lịch sử; hiệu chỉnh bất thường dùng một tuần và có giờ điền 0 được đánh dấu rõ.")),
    character())
  list(lines=unname(lines),notes=unname(da_notes(result$notes,lang)),scope=da_scope_label(result$scope,lang),sources=result$sources)
}
