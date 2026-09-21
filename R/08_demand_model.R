# Run with Rscript R/08_demand_model.R, or as the final stage of Main.R.
# Fits models once and exports compact results. Shiny never sources this script.
.libPaths(c(".r-library",.libPaths()))
needed <- c("dplyr","tidyr","lubridate","readr","rpart","ranger","xgboost")
missing <- needed[!vapply(needed,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)) stop("Missing model packages: ",paste(missing,collapse=", "),". Run Rscript R/00_setup.R first.")
library(dplyr)
source("R/model_helpers.R",local=TRUE)
if(!exists("dashboard_time_cube",inherits=FALSE)) {
  if(!file.exists("output/dashboard/dashboard_time_cube.csv")) stop("Run Rscript Main.R to generate the time cube first.")
  dashboard_time_cube <- readr::read_csv("output/dashboard/dashboard_time_cube.csv",show_col_types=FALSE)
}
run_started <- proc.time()[["elapsed"]]
hourly <- engineer_demand_features(prepare_hourly_demand(dashboard_time_cube))
splits <- split_demand_data(hourly)
train <- splits$train;test <- splits$test
cat(sprintf("Hourly target: Total_Trips. Final training %s to %s (%d hours); test %s to %s (%d hours).\n",min(train$Date),max(train$Date),nrow(train),min(test$Date),max(test$Date),nrow(test)))
# Only this training frame enters model fitting and selection.
fitted <- fit_demand_models(train,seed=42L,threads=2L)
prediction_seconds <- numeric(4)
timed_predict <- function(i,expression) {
  start <- proc.time()[["elapsed"]];value <- force(expression)
  prediction_seconds[i] <<- proc.time()[["elapsed"]]-start
  as.numeric(value)
}
predictions <- data.frame(DateTime=test$DateTime,Actual=test$Total_Trips,
  Seasonal_Naive=timed_predict(1,test$lag_168),
  Regression_Tree=timed_predict(2,predict(fitted$tree,test)),
  Random_Forest=timed_predict(3,predict(fitted$forest,as.data.frame(test[ensemble_features]),num.threads=2)$predictions),
  XGBoost=timed_predict(4,predict(fitted$boost,xgboost::xgb.DMatrix(xgb_design(test),nthread=2))))
for(key in c("Seasonal_Naive","Regression_Tree","Random_Forest","XGBoost")) {
  predictions[[paste0("Residual_",key)]] <- predictions$Actual-predictions[[key]]
}
# Backward-compatible columns keep the original tests and downstream consumers working.
predictions$Date <- test$Date;predictions$Hour <- test$Hour
predictions$Baseline <- predictions$Seasonal_Naive
predictions$Prediction <- predictions$Regression_Tree
predictions$Residual <- predictions$Residual_Regression_Tree
stopifnot(nrow(predictions)==720,!anyNA(predictions),all(vapply(predictions[-1],function(x) all(is.finite(x)),logical(1))))
fit_seconds <- c(0,fitted$runtimes$tree[["fit"]],fitted$runtimes$forest[["fit"]],fitted$runtimes$boost[["fit"]])
tuning_seconds <- c(0,0,fitted$runtimes$forest[["tuning"]],fitted$runtimes$boost[["tuning"]])
metrics <- bind_rows(lapply(seq_along(model_ids),function(i) {
  values <- demand_metrics(predictions$Actual,predictions[[c("Seasonal_Naive","Regression_Tree","Random_Forest","XGBoost")[i]]])
  data.frame(Model=model_ids[i],values,Train_Start=min(train$Date),Train_End=max(train$Date),
    Test_Start=min(test$Date),Test_End=max(test$Date),Test_Hours=nrow(test),
    Runtime_Seconds=fit_seconds[i]+tuning_seconds[i]+prediction_seconds[i],
    Tuning_Seconds=tuning_seconds[i],Fit_Seconds=fit_seconds[i],Prediction_Seconds=prediction_seconds[i])
}))
# Different importance definitions: normalized only within each model, never pooled across models.
tree_raw <- fitted$tree$variable.importance
rf_raw <- fitted$forest$variable.importance
boost_raw <- xgboost::xgb.importance(model=fitted$boost)
boost_raw$Feature <- sub("^Weekday[1-7]$","Weekday",boost_raw$Feature)
boost_raw <- stats::aggregate(Gain~Feature,data=boost_raw,FUN=sum)
importance <- bind_rows(
  normalized_importance(tree_raw,"Regression tree",legacy_features,"rpart split improvement (including surrogate credit)"),
  normalized_importance(rf_raw,"Random Forest",ensemble_features,"ranger impurity decrease"),
  normalized_importance(setNames(boost_raw$Gain,boost_raw$Feature),"XGBoost",ensemble_features,"XGBoost gain; weekday dummy gains summed"))
metadata <- data.frame(Model=model_ids,Algorithm=c("Seasonal naive","rpart regression tree","ranger random forest regression","XGBoost gradient boosted regression trees"),
  Target="Total_Trips",Horizon_Hours=1,Seed=42,Train_Start=min(train$Date),Train_End=max(train$Date),
  Test_Start=min(test$Date),Test_End=max(test$Date),Train_Hours=nrow(train),Test_Hours=nrow(test),
  Validation_Start=c("Not tuned","Not tuned","2014-08-01","2014-08-01"),
  Validation_End=c("Not tuned","Not tuned","2014-08-31","2014-08-31"),
  Features=c("lag_168",paste(legacy_features,collapse="; "),rep(paste(ensemble_features,collapse="; "),2)),
  Hyperparameters=fitted$parameters,Package=c("base R","rpart","ranger","xgboost"),
  Package_Version=c(as.character(getRversion()),vapply(c("rpart","ranger","xgboost"),function(p) as.character(utils::packageVersion(p)),character(1))),
  R_Version=as.character(getRversion()),Evaluation="Rolling one hour ahead; observed lag values; no September fitting or tuning",
  Selection="Original baseline/tree preserved; ensembles selected by August RMSE then refitted through August 31",
  Feature_Comparison="Historical tree has 5 original predictors; ensembles have 15 predictors; comparison is of forecasting systems, not algorithm-only",
  Threads=c(1,1,2,2),Time_Convention="Supplied wall-clock labels stored as UTC without conversion",
  Cube_MD5=unname(tools::md5sum("output/dashboard/dashboard_time_cube.csv")))
# Publish only after all models and output validation succeed.
dir.create("output/model",recursive=TRUE,showWarnings=FALSE)
readr::write_csv(metrics,"output/model/model_metrics.csv")
readr::write_csv(predictions,"output/model/predictions.csv")
readr::write_csv(importance,"output/model/feature_importance.csv")
readr::write_csv(metadata,"output/model/model_metadata.csv")
readr::write_csv(fitted$tuning,"output/model/model_tuning.csv")
writeLines(c(capture.output(sessionInfo()),sprintf("Total model pipeline seconds: %.3f",proc.time()[["elapsed"]]-run_started)),"output/model/model_session_info.txt")
print(metrics)
cat(sprintf("Best September RMSE: %s. Total model pipeline: %.3f seconds.\n",metrics$Model[which.min(metrics$RMSE)],proc.time()[["elapsed"]]-run_started))
