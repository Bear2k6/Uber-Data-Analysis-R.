# Pure, auditable analytics. No model fitting and no raw pickup reads.
residual_anomalies <- function(predictions, calibration_hours=168L, threshold=3.5) {
  p <- predictions[order(predictions$DateTime),]
  stopifnot(nrow(p)>calibration_hours, !anyDuplicated(p$DateTime),
            all(diff(as.numeric(p$DateTime))==3600), all(is.finite(p$Random_Forest)),
            all(is.finite(p$Actual)), threshold>0)
  residual <- p$Actual-p$Random_Forest
  calibration <- seq_len(calibration_hours)
  center <- median(residual[calibration])
  raw_mad <- median(abs(residual[calibration]-center))
  if(!is.finite(raw_mad) || raw_mad<=0) stop("Calibration MAD must be positive; no silent fallback.")
  idx <- seq.int(calibration_hours+1L,nrow(p))
  score <- abs(.6744897501960817*(residual[idx]-center)/raw_mad)
  data.frame(DateTime=p$DateTime[idx],Observed=p$Actual[idx],Expected=p$Random_Forest[idx],
    Residual=residual[idx],Residual_Percent=ifelse(p$Random_Forest[idx]>0,100*residual[idx]/p$Random_Forest[idx],NA_real_),
    Anomaly_Score=score,Is_Anomaly=score>threshold,
    Direction=ifelse(residual[idx]>=0,"Higher than expected","Lower than expected"),
    Calibration_Start=p$DateTime[1],Calibration_End=p$DateTime[calibration_hours],
    Calibration_Median=center,Calibration_MAD=raw_mad,Threshold=threshold,Model="Random Forest")
}
# Local equirectangular projection, fixed origin, kilometres. Suitable only for NYC bbox.
nyc_xy_km <- function(lat,lon) {
  stopifnot(all(is.finite(lat)),all(is.finite(lon)),all(lat>=40.5 & lat<=41),all(lon>=-74.3 & lon<=-73.6))
  cbind(X_Km=6371.0088*(lon+73.98)*pi/180*cos(40.75*pi/180),Y_Km=6371.0088*(lat-40.75)*pi/180)
}
cluster_grid <- function(cube,eps_km=1.5,min_pickups=20000L) {
  cells <- cube |>
    dplyr::mutate(Lat=round(Lat_Grid,2),Lon=round(Lon_Grid,2)) |>
    dplyr::group_by(Lat,Lon) |> dplyr::summarise(Total_Trips=sum(Total_Trips),.groups="drop") |>
    dplyr::arrange(Lat,Lon)
  xy <- nyc_xy_km(cells$Lat,cells$Lon)
  # Integer pickup weights: minPts is pickup mass, NOT a count of grid cells.
  fit <- dbscan::dbscan(xy,eps=eps_km,minPts=min_pickups,weights=cells$Total_Trips,borderPoints=TRUE)
  cells$Cluster_ID <- fit$cluster
  # Stable, interpretable IDs ranked by all-period volume; 0 remains noise.
  ranks <- cells |> dplyr::filter(Cluster_ID>0) |> dplyr::group_by(Cluster_ID) |>
    dplyr::summarise(Total=sum(Total_Trips),.groups="drop") |> dplyr::arrange(dplyr::desc(Total),Cluster_ID)
  cells$Cluster_ID <- ifelse(cells$Cluster_ID==0L,0L,match(cells$Cluster_ID,ranks$Cluster_ID))
  nn <- dbscan::frNN(xy,eps=eps_km)
  cells$Neighborhood_Trips <- vapply(seq_len(nrow(cells)),function(i) sum(cells$Total_Trips[unique(c(i,nn$id[[i]]))]),numeric(1))
  cells$Is_Core <- cells$Neighborhood_Trips>=min_pickups
  cells$X_Km <- xy[,1];cells$Y_Km <- xy[,2]
  summary <- cells |> dplyr::group_by(Cluster_ID) |>
    dplyr::summarise(Grid_Cells=dplyr::n(),
      Center_Lat=weighted.mean(Lat,Total_Trips),Center_Lon=weighted.mean(Lon,Total_Trips),Total_Trips=sum(Total_Trips),.groups="drop") |>
    dplyr::mutate(Share=100*Total_Trips/sum(Total_Trips),Rank=Cluster_ID) |>
    dplyr::arrange(Cluster_ID==0,Rank)
  cells <- cells |> dplyr::left_join(dplyr::select(summary,Cluster_ID,Cluster_Total_Trips=Total_Trips,Cluster_Share=Share,Center_Lat,Center_Lon),by="Cluster_ID")
  list(cells=cells,summary=summary)
}

