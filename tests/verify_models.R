# Run after Rscript R/08_demand_model.R. No tuning or training against the test set.
.libPaths(c('.r-library',.libPaths()))
library(dplyr)
library(readr)
source('R/model_helpers.R')
read_model <- function(name) read_csv(file.path('output/model',name),show_col_types=FALSE)
p <- read_model('predictions.csv');m <- read_model('model_metrics.csv')
imp <- read_model('feature_importance.csv');meta <- read_model('model_metadata.csv');tuning <- read_model('model_tuning.csv')
columns <- c('Seasonal_Naive','Regression_Tree','Random_Forest','XGBoost')
stopifnot(all(c('DateTime','Actual',columns,'Date','Hour','Baseline','Prediction','Residual') %in% names(p)),
  all(c('Model','MAE','RMSE','MAPE','R2','Train_Start','Train_End','Test_Start','Test_End','Test_Hours','Runtime_Seconds') %in% names(m)),
  identical(m$Model,model_ids),nrow(m)==4,nrow(p)==720,!anyNA(p),!anyNA(m),
  all(vapply(p[c('Actual',columns)],function(x) length(x)==720 && all(is.finite(x)),logical(1))),
  all(vapply(m[c('MAE','RMSE','MAPE','R2','Runtime_Seconds')],function(x) all(is.finite(x)),logical(1))),
  all(m$Runtime_Seconds>=0),all(m$Test_Hours==720),all(m$Train_End<m$Test_Start),
  min(p$Date)==as.Date('2014-09-01'),max(p$Date)==as.Date('2014-09-30'),
  all(diff(as.numeric(p$DateTime))==3600),!anyDuplicated(p$DateTime))
stopifnot(all(m$Train_Start==as.Date('2014-04-08')),all(m$Train_End==as.Date('2014-08-31')),
  all(meta$Train_Hours==3504),all(meta$Test_Hours==720),all(meta$Target=='Total_Trips'),all(meta$Seed==42),
  all(tuning$Fit_End<tuning$Validation_Start),all(tuning$Validation_End<as.Date('2014-09-01')))
for(id in c('Random Forest','XGBoost')) {
  rows <- tuning[tuning$Model==id,]
  stopifnot(nrow(rows)==4,sum(rows$Selected)==1,rows$Validation_RMSE[rows$Selected]==min(rows$Validation_RMSE))
}
# Independent cube aggregation establishes the target and exact test hour alignment.
cube <- read_csv('output/dashboard/dashboard_time_cube.csv',show_col_types=FALSE)
independent <- cube %>% group_by(Date,Hour) %>% summarise(Total_Trips=sum(Total_Trips),.groups='drop') %>% arrange(Date,Hour)
grid <- expand.grid(Date=seq(as.Date('2014-04-01'),as.Date('2014-09-30'),by='day'),Hour=0:23)
independent <- left_join(grid,independent,by=c('Date','Hour')) %>% arrange(Date,Hour)
independent$Total_Trips[is.na(independent$Total_Trips)] <- 0
hourly <- prepare_hourly_demand(cube)
stopifnot(nrow(hourly)==4392,sum(hourly$Total_Trips)==4534327,identical(as.numeric(hourly$Total_Trips),as.numeric(independent$Total_Trips)))
features <- engineer_demand_features(hourly);splits <- split_demand_data(features)
stopifnot(all(p$Actual==splits$test$Total_Trips),all(p$DateTime==splits$test$DateTime),
  !any(splits$train$DateTime %in% splits$test$DateTime),!('Total_Trips' %in% ensemble_features),
  !any(c('Actual','Prediction','Residual','DateTime') %in% ensemble_features),length(ensemble_features)==15)
# Exact lag alignment and deliberately asymmetric rolling windows catch off-by-one leakage.
for(k in c(1,2,24,48,168)) {
  value <- features[[paste0('lag_',k)]]
  stopifnot(all(is.na(head(value,k))),identical(as.numeric(value[-seq_len(k)]),as.numeric(head(hourly$Total_Trips,-k))))
}
for(i in c(169L,200L,1000L,3673L,4000L,4392L)) {
  for(k in c(3,24,168)) stopifnot(abs(features[[paste0('rolling_mean_',k)]][i]-mean(hourly$Total_Trips[(i-k):(i-1)]))<1e-10)
  stopifnot(abs(features$rolling_sd_24[i]-sd(hourly$Total_Trips[(i-24):(i-1)]))<1e-10)
  poisoned <- hourly;poisoned$Total_Trips[i:nrow(poisoned)] <- poisoned$Total_Trips[i:nrow(poisoned)]+1000000
  other <- engineer_demand_features(poisoned)
  stopifnot(identical(features[seq_len(i),ensemble_features],other[seq_len(i),ensemble_features]))
}
# The baseline and historical tree are independently reconstructed, not weakened.
stopifnot(all(p$Seasonal_Naive==splits$test$lag_168),identical(p$Baseline,p$Seasonal_Naive),
  identical(p$Prediction,p$Regression_Tree),max(abs(p$Residual-(p$Actual-p$Regression_Tree)))<1e-9)
reference <- rpart::rpart(Total_Trips ~ Hour + Weekday + DayIndex + lag_24 + lag_168,
  data=splits$train,method='anova',control=rpart::rpart.control(cp=0.002,minsplit=30,maxdepth=8,xval=0))
stopifnot(max(abs(as.numeric(predict(reference,splits$test))-p$Regression_Tree))<1e-10)
for(i in seq_along(columns)) {
  actual <- p$Actual;pred <- p[[columns[i]]];error <- actual-pred
  independent_metrics <- c(mean(abs(error)),sqrt(mean(error^2)),100*mean(abs(error[actual!=0]/actual[actual!=0])),1-sum(error^2)/sum((actual-mean(actual))^2))
  stopifnot(max(abs(unlist(m[i,c('MAE','RMSE','MAPE','R2')],use.names=FALSE)-independent_metrics))<1e-8)
  stopifnot(max(abs(p[[paste0('Residual_',columns[i])]]-error))<1e-9)
}
stopifnot(abs(m$RMSE[1]-349.19273371274176)<1e-8,abs(m$RMSE[2]-422.07597801378324)<1e-8,
  all(c('Model','Feature','Importance','Rank','Raw_Importance','Method') %in% names(imp)),!anyNA(imp),
  all(imp$Importance>=0),all(is.finite(imp$Importance)),setequal(unique(imp$Model),model_ids[-1]))
for(id in model_ids[-1]) {
  rows <- imp[imp$Model==id,]
  stopifnot(abs(sum(rows$Importance)-100)<1e-8,identical(as.integer(rows$Rank),seq_len(nrow(rows))),!anyDuplicated(rows$Feature))
}
# Stable one-hot feature schema across fit/validation/holdout; all encoders are calendar-only.
stopifnot(identical(colnames(xgb_design(splits$train)),colnames(xgb_design(splits$test))),
  !anyNA(xgb_design(splits$test)),!any(grepl('Total_Trips|Actual|Residual',colnames(xgb_design(splits$test)))))
cat('PASS: 4 models on the same 720 hours; chronology; schemas; finite metrics; independent metric recomputation; unchanged baseline/tree; lag shifts; prior-only rolling features; target poisoning tests; training-only validation selection; normalized model-specific importance.\n')
# Check dashboard selectors and language changes without fitting models at startup.
source('app/app.R',local=TRUE,encoding='UTF-8')
shiny::testServer(server,{
  session$setInputs(ta_dates=as.Date(c('2014-04-01','2014-09-30')),ta_month='All',ta_weekday='All',ta_daytype='All',ta_hour='All',ta_base='All',geo_month='All',geo_base='All',geo_top_n=20,ba_month='All',ba_weekday='All',ba_daytype='All',ba_base='All',de_dataset='Time cube',navigation='model')
  for(value in c('All',model_series)) {
    session$setInputs(prediction_model=value)
    stopifnot(identical(selected_prediction(),if(value=='All') model_series else value),!is.null(output$model_actual))
  }
  for(value in importance_models) {
    session$setInputs(importance_model=value)
    stopifnot(all(selected_importance()$Model==value),abs(sum(selected_importance()$Importance)-100)<1e-8,!is.null(output$model_importance))
  }
  for(language in c('en','vi')) {
    session$setInputs(language=language)
    stopifnot(input$prediction_model=='XGBoost',input$importance_model=='XGBoost',input$navigation=='model',
      grepl('XGBoost',output$model_comparison,fixed=TRUE),grepl(tr('best_rmse',language),output$model_kpis$html,fixed=TRUE))
  }
})
cat('PASS: Prediction model and importance selectors; dynamic winning model; VI/EN selector preservation; cached-output dashboard render.\n')
