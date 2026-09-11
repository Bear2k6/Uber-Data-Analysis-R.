# Run from repository root after Main.R. Independently checks raw September records.
.libPaths(c(".r-library",.libPaths()))
library(dplyr)
library(readr)
source("app/helpers.R")
tm <- read_csv("output/dashboard/dashboard_time_cube.csv",show_col_types=FALSE)
gc <- read_csv("output/dashboard/dashboard_geo_cube.csv",show_col_types=FALSE)
raw <- read_csv("data/uber-raw-data-sep14.csv",show_col_types=FALSE)
stamp <- as.POSIXct(raw$`Date/Time`,format="%m/%d/%Y %H:%M:%S",tz="UTC")
raw$Hour <- as.integer(format(stamp,"%H"))
raw$Weekday <- weekday_levels[as.integer(format(stamp,"%u"))]
raw$Date <- as.Date(stamp)
raw$DayType <- ifelse(raw$Weekday %in% c("Sat","Sun"),"Weekend","Weekday")
selected <- filter_cube(tm,month="Sep",weekday="Thu",daytype="Weekday",hour="17",base="B02617")
expected <- sum(raw$Weekday=="Thu" & raw$Hour==17 & raw$Base=="B02617")
stopifnot(sum(selected$Total_Trips)==expected)
cat("Exact Sep / Weekday / Thu / 17 / B02617:",expected,"trips\n")
for(base in unique(raw$Base)) for(day in weekday_levels) for(hour in c(0,8,17,23)) {
  actual <- sum(filter_cube(tm,month="Sep",weekday=day,hour=as.character(hour),base=base)$Total_Trips)
  stopifnot(actual==sum(raw$Base==base & raw$Weekday==day & raw$Hour==hour))
}
nyc <- raw %>% filter(Lat>=40.5774,Lat<=40.9176,Lon>=-74.15,Lon<=-73.7004) %>%
  mutate(Lat_Grid=round(Lat/.01)*.01,Lon_Grid=round(Lon/.01)*.01) %>% count(Base,Lat_Grid,Lon_Grid,name="Expected")
actual <- filter_cube(gc,month="Sep")
actual <- mutate(actual, Lat_Grid = round(Lat_Grid, 2), Lon_Grid = round(Lon_Grid, 2))
nyc <- mutate(nyc, Lat_Grid = round(Lat_Grid, 2), Lon_Grid = round(Lon_Grid, 2))
joined <- full_join(actual,nyc,by=c("Base","Lat_Grid","Lon_Grid"))
stopifnot(!anyNA(joined),all(joined$Expected==joined$Total_Trips))
stopifnot(sum(tm$Total_Trips)==sum(read_csv("output/results/trips_by_hour.csv",show_col_types=FALSE)$Total_Trips))
stopifnot(nrow(filter_cube(tm,weekday="Thu",daytype="Weekend"))==0)
# Date-range intersection independently checked against raw records.
stopifnot(sum(filter_cube(tm,month="Sep",dates=as.Date(c("2014-09-10","2014-09-12")))$Total_Trips)==sum(raw$Date>=as.Date("2014-09-10") & raw$Date<=as.Date("2014-09-12")))
# Every original single-dimension aggregate is preserved.
for(dim in c(Hour="hour",Date="date",Month="month",Weekday="weekday",Base="base")) {
  key <- names(c(Hour="hour",Date="date",Month="month",Weekday="weekday",Base="base"))[match(dim,c("hour","date","month","weekday","base"))]
  original <- read_csv(paste0("output/results/trips_by_",dim,".csv"),show_col_types=FALSE)
  observed <- aggregate_trips(tm,key)
  check <- left_join(original,observed,by=key,suffix=c("_original","_cube"))
  stopifnot(all(check$Total_Trips_original==check$Total_Trips_cube))
}
# Missing files and invalid schemas fail with actionable instructions.
err <- tryCatch(read_checked("output/dashboard/absent.csv","Date"),error=function(e) conditionMessage(e))
stopifnot(grepl("Rscript Main.R",err,fixed=TRUE))
source("app/app.R",local=TRUE)
shiny::testServer(server,{
  session$setInputs(ta_dates=as.Date(c("2014-04-01","2014-09-30")),ta_month="Sep",ta_weekday="Thu",ta_daytype="Weekday",ta_hour="17",ta_base="B02617",
    geo_month="Sep",geo_base="B02617",geo_top_n=10,ba_month="Sep",ba_weekday="Thu",ba_daytype="Weekday",ba_base="B02617",de_dataset="Time cube")
  stopifnot(sum(ta_filtered()$Total_Trips)==expected,nrow(ta_daily())==4,nrow(geo_filtered())==10)
  stopifnot(sum(geo_all()$Total_Trips)==sum(nyc$Expected[nyc$Base=="B02617"]))
  session$setInputs(geo_top_n=20);stopifnot(nrow(geo_filtered())==20)
  session$setInputs(ta_daytype="Weekend");stopifnot(nrow(ta_filtered())==0,nrow(ta_calendar())==0)
})
if(model_available) {
  stopifnot(all(model_metrics$Train_End < model_metrics$Test_Start),nrow(predictions)==30*24)
  m <- model_metrics[model_metrics$Model=="Regression tree",]
  stopifnot(abs(m$MAE-mean(abs(predictions$Residual)))<1e-8)
}
cat("PASS: raw/cube intersections, geographic cells, aggregate conservation, date ranges, empty states, server reactives and model checks.\n")


# Schema failures and all filter dimensions, independently exercised.
invalid <- tempfile(fileext=".csv")
write_csv(data.frame(Wrong=1),invalid)
stopifnot(grepl("Rscript Main.R",tryCatch(read_checked(invalid,"Date"),error=function(e) conditionMessage(e)),fixed=TRUE))
unlink(invalid)
for(m in month_levels) stopifnot(sum(filter_cube(tm,month=m)$Total_Trips)==sum(tm$Total_Trips[tm$Month==m]))
for(b in bases) stopifnot(sum(filter_cube(tm,base=b)$Total_Trips)==sum(tm$Total_Trips[tm$Base==b]))
for(w in weekday_levels) stopifnot(sum(filter_cube(tm,weekday=w)$Total_Trips)==sum(tm$Total_Trips[tm$Weekday==w]))
for(d in c("Weekday","Weekend")) stopifnot(sum(filter_cube(tm,daytype=d)$Total_Trips)==sum(tm$Total_Trips[tm$DayType==d]))
for(h in 0:23) stopifnot(sum(filter_cube(tm,hour=as.character(h))$Total_Trips)==sum(tm$Total_Trips[tm$Hour==h]))
cat("PASS: all individual dimension values and invalid-schema error.\n")
