.libPaths(c(".r-library",.libPaths()))
source("R/ai_helpers.R")
p <- readr::read_csv("output/model/predictions.csv",show_col_types=FALSE)
a <- readr::read_csv("output/anomaly/anomalies.csv",show_col_types=FALSE)
s <- readr::read_csv("output/anomaly/anomaly_summary.csv",show_col_types=FALSE)
stopifnot(nrow(a)==552,!anyDuplicated(a$DateTime),all(is.finite(a$Anomaly_Score)),
  all(is.finite(a$Expected)),is.logical(a$Is_Anomaly),all(a$Calibration_End<a$DateTime),
  all(a$Is_Anomaly==(a$Anomaly_Score>3.5)),all(a$Anomaly_Score>=0))
# Independently reconstruct calibration and scores; forecasts remain fixed, pre-trained.
r <- p$Actual-p$Random_Forest
center <- median(r[1:168]);mad0 <- median(abs(r[1:168]-center))
stopifnot(max(abs(a$Anomaly_Score-abs(qnorm(.75)*(r[169:720]-center)/mad0)))<1e-10,
  max(abs(a$Residual-r[169:720]))<1e-9,max(abs(a$Expected-p$Random_Forest[169:720]))<1e-9,
  sum(a$Is_Anomaly)==s$Anomalies,abs(100*mean(a$Is_Anomaly)-s$Anomaly_Percent)<1e-9)
# Poison current and future observations. Past scores and every calibration parameter must stay unchanged.
for(i in c(169L,200L,500L,720L)) {
  poisoned <- p;poisoned$Actual[i:720] <- poisoned$Actual[i:720]+1000000
  changed <- residual_anomalies(poisoned)
  stopifnot(all(changed$Calibration_Median==center),all(changed$Calibration_MAD==mad0))
  if(i>169) stopifnot(max(abs(changed$Anomaly_Score[1:(i-169)]-a$Anomaly_Score[1:(i-169)]))<1e-10)
}
cube <- readr::read_csv("output/dashboard/dashboard_time_cube.csv",show_col_types=FALSE)
recorded <- unique(as.POSIXct(cube$Date,tz="UTC")+cube$Hour*3600)
stopifnot(identical(a$Zero_Filled,!a$DateTime %in% recorded),all(a$Observed[a$Zero_Filled]==0))
tuning <- readr::read_csv("output/model/model_tuning.csv",show_col_types=FALSE)
meta <- readr::read_csv("output/model/model_metadata.csv",show_col_types=FALSE)
selected <- tuning[tuning$Selected,]
stopifnot(selected$Model[which.min(selected$Validation_RMSE)]=="Random Forest",
  all(as.Date(selected$Validation_End)<as.Date(min(p$DateTime))),
  as.Date(meta$Train_End[meta$Model=="Random Forest"])<as.Date(min(p$DateTime)))
g <- readr::read_csv("output/dashboard/dashboard_geo_cube.csv",show_col_types=FALSE)
cells <- readr::read_csv("output/clusters/hotspot_clusters.csv",show_col_types=FALSE)
cs <- readr::read_csv("output/clusters/cluster_summary.csv",show_col_types=FALSE)
stopifnot(all(cells$Lat>=40.5 & cells$Lat<=41),all(cells$Lon>=-74.3 & cells$Lon<=-73.6),
  all(cells$Cluster_ID>=0 & cells$Cluster_ID==as.integer(cells$Cluster_ID)),0 %in% cs$Cluster_ID,
  all(cs$Share>=0 & cs$Share<=100),abs(sum(cs$Share)-100)<1e-9,
  sum(cells$Total_Trips)==sum(g$Total_Trips),sum(cs$Total_Trips)==sum(g$Total_Trips),
  !anyDuplicated(paste(cells$Lat,cells$Lon)),all(cs$Rank[cs$Cluster_ID==0]==0))
for(id in cs$Cluster_ID) {
  d <- cells[cells$Cluster_ID==id,];ss <- cs[cs$Cluster_ID==id,]
  stopifnot(sum(d$Total_Trips)==ss$Total_Trips,nrow(d)==ss$Grid_Cells,
    all(d$Cluster_Total_Trips==ss$Total_Trips),max(abs(d$Cluster_Share-ss$Share))<1e-9,
    abs(ss$Share-100*ss$Total_Trips/sum(cells$Total_Trips))<1e-9,
    abs(ss$Center_Lat-weighted.mean(d$Lat,d$Total_Trips))<1e-10)
}
# Independent all-pairs neighborhood mass validates weighted minPts and explicit noise.
xy <- nyc_xy_km(cells$Lat,cells$Lon)
distance <- as.matrix(dist(xy))
mass <- as.vector((distance<=1.5)%*%cells$Total_Trips)
stopifnot(all(mass==cells$Neighborhood_Trips),all(cells$Is_Core==(mass>=20000)),
  all(!cells$Is_Core[cells$Cluster_ID==0]))
for(i in which(cells$Cluster_ID==0)) stopifnot(!any(cells$Is_Core & distance[i,]<=1.5))
# Local projection scale sanity: 0.01 latitude ~1.112 km, longitude ~0.842 km.
z <- nyc_xy_km(c(40.75,40.76,40.75),c(-73.98,-73.98,-73.97))
stopifnot(abs(z[2,2]-1.11195)<.001,abs(z[3,1]-.842)<.002)
repeat_fit <- cluster_grid(g)
stopifnot(identical(as.integer(cells$Cluster_ID),as.integer(repeat_fit$cells$Cluster_ID)))
cat("PASS: residual calibration, future poisoning, coordinates, weighted density, totals, noise and repeatability.\n")
source("app/app.R",encoding="UTF-8")
shiny::testServer(server,{
  session$setInputs(language="vi",geo_month="All",geo_base="All",geo_top_n=20,geo_mode="AI Clusters",
    an_month="All",an_direction="All",an_score=0,
    ta_dates=as.Date(c("2014-04-01","2014-09-30")),ta_month="All",ta_weekday="All",ta_daytype="All",ta_hour="All",ta_base="All",
    ba_month="All",ba_weekday="All",ba_daytype="All",ba_base="All",de_dataset="Time cube",prediction_model="All",importance_model="Regression tree")
  stopifnot(nrow(ai$an_filtered())==552,sum(ai$an_filtered()$Is_Anomaly)==11,
    sum(ai$selected_clusters()$Total_Trips)==4462626)
  for(l in c("vi","en")) {
    session$setInputs(language=l)
    for(id in c("an_kpis","an_chart","an_table","cluster_kpis","cluster_insight","cluster_map","cluster_table")) stopifnot(!is.null(output[[id]]))
  }
  session$setInputs(an_direction="Lower than expected",an_score=3.5,geo_month="Sep",geo_base="B02617")
  expected <- anomaly_data[anomaly_data$Direction=="Lower than expected" & anomaly_data$Anomaly_Score>=3.5,]
  stopifnot(identical(ai$an_filtered()$DateTime,expected$DateTime),
    sum(ai$selected_clusters()$Total_Trips)==sum(filter_cube(geo_cube,month="Sep",base="B02617")$Total_Trips))
  before <- ai$selected_clusters();session$setInputs(language="vi")
  stopifnot(identical(before,ai$selected_clusters()),input$geo_mode=="AI Clusters",input$an_direction=="Lower than expected")
  session$setInputs(an_score=999)
  stopifnot(nrow(ai$an_filtered())==0,!is.null(output$an_kpis),!is.null(output$an_chart),!is.null(output$an_table))
})
cat("PASS: AI dashboard bilingual renderers, filters, empty results, fixed membership and filtered totals.\n")
