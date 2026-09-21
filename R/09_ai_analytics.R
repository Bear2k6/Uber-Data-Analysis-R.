# Standalone: Rscript R/09_ai_analytics.R. Reuses saved forecasting outputs unchanged.
.libPaths(c(".r-library",.libPaths()))
for(pkg in c("readr","dplyr","dbscan")) if(!requireNamespace(pkg,quietly=TRUE)) stop("Run R/00_setup.R; missing ",pkg)
source("R/ai_helpers.R")
dir.create("output/anomaly",recursive=TRUE,showWarnings=FALSE)
dir.create("output/clusters",recursive=TRUE,showWarnings=FALSE)
p <- readr::read_csv("output/model/predictions.csv",show_col_types=FALSE)
tuning <- readr::read_csv("output/model/model_tuning.csv",show_col_types=FALSE)
selected <- tuning[tuning$Selected,]
stopifnot(selected$Model[which.min(selected$Validation_RMSE)]=="Random Forest",
          all(as.Date(selected$Validation_End)<as.Date(min(p$DateTime))))
a <- residual_anomalies(p)
time_cube <- readr::read_csv("output/dashboard/dashboard_time_cube.csv",show_col_types=FALSE)
recorded_hours <- unique(as.POSIXct(time_cube$Date,tz="UTC")+time_cube$Hour*3600)
a$Zero_Filled <- !a$DateTime %in% recorded_hours
readr::write_csv(a,"output/anomaly/anomalies.csv")
summary <- data.frame(Input_Hours=nrow(p),Calibration_Hours=168,Total_Observations=nrow(a),
  Anomalies=sum(a$Is_Anomaly),Zero_Filled_Hours=sum(a$Zero_Filled),Zero_Filled_Anomalies=sum(a$Is_Anomaly & a$Zero_Filled),Anomaly_Percent=100*mean(a$Is_Anomaly),
  Largest_Positive_Deviation=max(a$Residual),Largest_Negative_Deviation=min(a$Residual),
  Largest_Absolute_Deviation_Time=a$DateTime[which.max(abs(a$Residual))],
  Largest_Score_Time=a$DateTime[which.max(a$Anomaly_Score)],
  Threshold=3.5,Method="Absolute modified z-score of Random Forest residual; fixed prior 168-hour calibration",
  Calibration_Start=min(p$DateTime),Calibration_End=max(a$Calibration_End),
  Evaluation_Start=min(a$DateTime),Evaluation_End=max(a$DateTime),
  Calibration_Median=a$Calibration_Median[1],Calibration_MAD=a$Calibration_MAD[1],
  Model_Selection="Lowest August validation RMSE among saved tuned ensembles; not September test RMSE")
readr::write_csv(summary,"output/anomaly/anomaly_summary.csv")
g <- readr::read_csv("output/dashboard/dashboard_geo_cube.csv",show_col_types=FALSE)
c <- cluster_grid(g)
readr::write_csv(c$cells,"output/clusters/hotspot_clusters.csv")
readr::write_csv(c$summary,"output/clusters/cluster_summary.csv")
# Sensitivity describes parameter dependence; does not select parameters for attractive results.
sensitivity <- do.call(rbind,lapply(c(1.2,1.5,1.8),function(e) do.call(rbind,lapply(c(10000L,20000L,40000L),function(m) {
  x <- cluster_grid(g,e,m);noise <- x$cells$Cluster_ID==0
  data.frame(Epsilon_Km=e,Min_Pickups=m,Clusters=sum(x$summary$Cluster_ID>0),Noise_Cells=sum(noise),
    Noise_Trips=sum(x$cells$Total_Trips[noise]),Noise_Share=100*sum(x$cells$Total_Trips[noise])/sum(x$cells$Total_Trips),Primary=e==1.5 & m==20000)
}))))
readr::write_csv(sensitivity,"output/clusters/parameter_sensitivity.csv")
readr::write_csv(data.frame(Epsilon_Km=1.5,Min_Pickups=20000,Weight="Total_Trips",Noise_ID=0,
  Grid_Degrees=.01,Origin_Lat=40.75,Origin_Lon=-73.98,Earth_Radius_Km=6371.0088,
  Distance="Euclidean in local equirectangular kilometre coordinates",Border_Points=TRUE,
  Package_Version=as.character(utils::packageVersion("dbscan")),
  Geo_Cube_MD5=unname(tools::md5sum("output/dashboard/dashboard_geo_cube.csv")),
  Predictions_MD5=unname(tools::md5sum("output/model/predictions.csv"))),"output/clusters/analytics_metadata.csv")
print(summary);print(c$summary);print(sensitivity)
