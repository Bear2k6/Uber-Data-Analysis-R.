# Pure, reusable chronological feature engineering and model training helpers.
# No function in the fitting stage receives the September holdout.
legacy_features <- c("Hour","Weekday","DayIndex","lag_24","lag_168")
ensemble_features <- c("Hour","Weekday","DayType","Month","DayOfMonth","DayIndex",
  "lag_1","lag_2","lag_24","lag_48","lag_168",
  "rolling_mean_3","rolling_mean_24","rolling_mean_168","rolling_sd_24")
model_ids <- c("Seasonal naive (last week)","Regression tree","Random Forest","XGBoost")

prepare_hourly_demand <- function(cube) {
  stopifnot(all(c("Date","Hour","Total_Trips") %in% names(cube)),inherits(cube$Date,"Date"),
    !anyNA(cube[c("Date","Hour","Total_Trips")]),all(cube$Hour %in% 0:23),all(cube$Total_Trips>=0))
  hourly <- cube %>% dplyr::group_by(Date,Hour) %>%
    dplyr::summarise(Total_Trips=sum(Total_Trips),.groups="drop") %>%
    tidyr::complete(Date=seq(min(Date),max(Date),by="day"),Hour=0:23,fill=list(Total_Trips=0)) %>%
    dplyr::arrange(Date,Hour)
  # UTC is a storage convention for the supplied wall-clock labels, not a timezone conversion.
  hourly$DateTime <- as.POSIXct(hourly$Date,tz="UTC")+hourly$Hour*3600
  stopifnot(all(diff(as.numeric(hourly$DateTime))==3600))
  hourly
}
prior_window <- function(y,width,fun=mean) {
  stopifnot(width>=1,length(width)==1)
  vapply(seq_along(y),function(i) if(i<=width) NA_real_ else fun(y[seq.int(i-width,i-1L)]),numeric(1))
}
engineer_demand_features <- function(hourly) {
  stopifnot(all(c("Date","DateTime","Hour","Total_Trips") %in% names(hourly)),
    all(diff(as.numeric(hourly$DateTime))==3600),!anyNA(hourly$Total_Trips))
  df <- hourly
  weekday <- lubridate::wday(df$Date,week_start=1)
  df$Weekday <- factor(weekday,levels=1:7)
  df$DayIndex <- as.integer(df$Date-min(df$Date))
  df$DayType <- as.integer(weekday>=6) # 0 weekday, 1 weekend
  df$Month <- as.integer(format(df$Date,"%m"))
  df$DayOfMonth <- as.integer(format(df$Date,"%d"))
  for(k in c(1,2,24,48,168)) df[[paste0("lag_",k)]] <- dplyr::lag(df$Total_Trips,k)
  for(k in c(3,24,168)) df[[paste0("rolling_mean_",k)]] <- prior_window(df$Total_Trips,k)
  df$rolling_sd_24 <- prior_window(df$Total_Trips,24,stats::sd)
  df
}
split_demand_data <- function(features) {
  train <- features[features$Date<as.Date("2014-09-01") & stats::complete.cases(features[ensemble_features]),]
  test <- features[features$Date>=as.Date("2014-09-01") & features$Date<=as.Date("2014-09-30"),]
  stopifnot(nrow(train)>0,nrow(test)==720,!anyNA(test[ensemble_features]),max(train$Date)<min(test$Date),
    min(train$Date)==as.Date("2014-04-08"),max(train$Date)==as.Date("2014-08-31"))
  list(train=train,test=test)
}
xgb_design <- function(df) {
  # Fixed calendar levels are known in advance; no target encoding or test-fitted preprocessing.
  x <- stats::model.matrix(~ . - 1,data=as.data.frame(df[ensemble_features]),
    contrasts.arg=list(Weekday=stats::contrasts(factor(1:7),contrasts=FALSE)))
  storage.mode(x) <- "double"
  x
}
demand_metrics <- function(actual,pred) {
  stopifnot(length(actual)==length(pred),length(actual)>0,all(is.finite(actual)),all(is.finite(pred)))
  nonzero <- actual!=0
  data.frame(MAE=mean(abs(actual-pred)),RMSE=sqrt(mean((actual-pred)^2)),
    MAPE=if(any(nonzero)) mean(abs((actual[nonzero]-pred[nonzero])/actual[nonzero]))*100 else NA_real_,
    R2=if(sum((actual-mean(actual))^2)>0) 1-sum((actual-pred)^2)/sum((actual-mean(actual))^2) else NA_real_)
}
fit_demand_models <- function(training,seed=42L,threads=2L) {
  stopifnot(max(training$Date)<as.Date("2014-09-01"),!anyNA(training[ensemble_features]))
  fit <- training[training$Date<as.Date("2014-08-01"),]
  validation <- training[training$Date>=as.Date("2014-08-01"),]
  stopifnot(nrow(fit)>0,nrow(validation)==744,max(fit$Date)<min(validation$Date))
  runtimes <- list();tuning <- list()
  started <- proc.time()[["elapsed"]]
  set.seed(seed)
  # Historical reference: exact original formula, parameters and training rows.
  tree <- rpart::rpart(Total_Trips ~ Hour + Weekday + DayIndex + lag_24 + lag_168,
    data=training,method="anova",control=rpart::rpart.control(cp=0.002,minsplit=30,maxdepth=8,xval=0))
  runtimes$tree <- c(tuning=0,fit=proc.time()[["elapsed"]]-started)
  cat(sprintf("Regression tree: %.3f seconds\n",runtimes$tree[["fit"]]))

  rf_grid <- expand.grid(mtry=c(5L,10L),min.node.size=c(5L,15L))
  started <- proc.time()[["elapsed"]]
  rf_scores <- numeric(nrow(rf_grid))
  for(i in seq_len(nrow(rf_grid))) {
    set.seed(seed)
    candidate <- ranger::ranger(x=as.data.frame(fit[ensemble_features]),y=fit$Total_Trips,
      num.trees=400,mtry=rf_grid$mtry[i],min.node.size=rf_grid$min.node.size[i],
      respect.unordered.factors="order",seed=seed,num.threads=threads)
    pred <- predict(candidate,as.data.frame(validation[ensemble_features]),num.threads=threads)$predictions
    rf_scores[i] <- demand_metrics(validation$Total_Trips,pred)$RMSE
    cat(sprintf("Random Forest validation %d/%d: RMSE %.3f\n",i,nrow(rf_grid),rf_scores[i]))
  }
  rf_tuning <- proc.time()[["elapsed"]]-started
  best_rf <- which.min(rf_scores)
  started <- proc.time()[["elapsed"]]
  set.seed(seed)
  forest <- ranger::ranger(x=as.data.frame(training[ensemble_features]),y=training$Total_Trips,
    num.trees=400,mtry=rf_grid$mtry[best_rf],min.node.size=rf_grid$min.node.size[best_rf],
    respect.unordered.factors="order",importance="impurity",seed=seed,num.threads=threads)
  runtimes$forest <- c(tuning=rf_tuning,fit=proc.time()[["elapsed"]]-started)
  cat(sprintf("Random Forest: %.3f seconds tuning + %.3f seconds final fit\n",rf_tuning,runtimes$forest[["fit"]]))

  xgb_grid <- expand.grid(max_depth=c(3L,5L),min_child_weight=c(5,15))
  started <- proc.time()[["elapsed"]]
  dfit <- xgboost::xgb.DMatrix(xgb_design(fit),label=fit$Total_Trips,nthread=threads)
  dval <- xgboost::xgb.DMatrix(xgb_design(validation),label=validation$Total_Trips,nthread=threads)
  xgb_scores <- numeric(nrow(xgb_grid));best_rounds <- integer(nrow(xgb_grid))
  parameters <- function(i) list(objective="reg:squarederror",eval_metric="rmse",tree_method="hist",
    max_depth=xgb_grid$max_depth[i],min_child_weight=xgb_grid$min_child_weight[i],eta=0.05,
    subsample=0.8,colsample_bytree=0.8,seed=seed,nthread=threads)
  for(i in seq_len(nrow(xgb_grid))) {
    set.seed(seed)
    candidate <- xgboost::xgb.train(params=parameters(i),data=dfit,nrounds=400,
      evals=list(validation=dval),early_stopping_rounds=30,maximize=FALSE,verbose=0)
    # Evaluation-log row numbers equal the number of boosting rounds, avoiding index-version ambiguity.
    evaluation <- as.data.frame(attr(candidate,"evaluation_log"))
    score_col <- grep("validation.*rmse",names(evaluation),value=TRUE)
    stopifnot(length(score_col)==1,nrow(evaluation)>0)
    best_rounds[i] <- which.min(evaluation[[score_col]])
    xgb_scores[i] <- evaluation[[score_col]][best_rounds[i]]
    cat(sprintf("XGBoost validation %d/%d: RMSE %.3f at %d rounds\n",i,nrow(xgb_grid),xgb_scores[i],best_rounds[i]))
  }
  xgb_tuning <- proc.time()[["elapsed"]]-started
  best_xgb <- which.min(xgb_scores)
  started <- proc.time()[["elapsed"]]
  set.seed(seed)
  boost <- xgboost::xgb.train(params=parameters(best_xgb),
    data=xgboost::xgb.DMatrix(xgb_design(training),label=training$Total_Trips,nthread=threads),
    nrounds=best_rounds[best_xgb],verbose=0)
  runtimes$boost <- c(tuning=xgb_tuning,fit=proc.time()[["elapsed"]]-started)
  cat(sprintf("XGBoost: %.3f seconds tuning + %.3f seconds final fit\n",xgb_tuning,runtimes$boost[["fit"]]))
  rf_settings <- sprintf("num.trees=400; mtry=%d; min.node.size=%d; respect.unordered.factors=order; importance=impurity; num.threads=%d",rf_grid$mtry[best_rf],rf_grid$min.node.size[best_rf],threads)
  xgb_settings <- paste(paste(names(parameters(best_xgb)),unlist(parameters(best_xgb)),sep="="),collapse="; ")
  xgb_settings <- paste0(xgb_settings,"; nrounds=",best_rounds[best_xgb])
  tuning <- dplyr::bind_rows(
    data.frame(Model="Random Forest",Candidate=seq_len(nrow(rf_grid)),Parameters=sprintf("num.trees=400; mtry=%d; min.node.size=%d",rf_grid$mtry,rf_grid$min.node.size),Validation_RMSE=rf_scores,Selected=seq_len(nrow(rf_grid))==best_rf),
    data.frame(Model="XGBoost",Candidate=seq_len(nrow(xgb_grid)),Parameters=sprintf("max_depth=%d; min_child_weight=%g; eta=0.05; subsample=0.8; colsample_bytree=0.8; nrounds=%d",xgb_grid$max_depth,xgb_grid$min_child_weight,best_rounds),Validation_RMSE=xgb_scores,Selected=seq_len(nrow(xgb_grid))==best_xgb))
  tuning$Fit_Start <- min(fit$Date);tuning$Fit_End <- max(fit$Date)
  tuning$Validation_Start <- min(validation$Date);tuning$Validation_End <- max(validation$Date)
  list(tree=tree,forest=forest,boost=boost,runtimes=runtimes,tuning=tuning,
    parameters=c("lag=168; no fitted parameters","cp=0.002; minsplit=30; maxdepth=8; xval=0",rf_settings,xgb_settings),
    seed=seed,threads=threads)
}
normalized_importance <- function(raw,label,features,method) {
  values <- setNames(rep(0,length(features)),features)
  values[names(raw)] <- raw
  values <- values[order(-values,names(values))]
  data.frame(Model=label,Feature=names(values),Importance=if(sum(values)>0) 100*values/sum(values) else 0,
    Rank=seq_along(values),Raw_Importance=as.numeric(values),Method=method,row.names=NULL)
}
