# Historical one-hour-ahead experiment. No test-set fitting or tuning.
# lag_24 and lag_168 are known at each prediction origin, including in September.
dir.create("output/model", recursive = TRUE, showWarnings = FALSE)
hourly <- dashboard_time_cube %>% group_by(Date, Hour) %>%
  summarise(Total_Trips = sum(Total_Trips), .groups = "drop") %>%
  tidyr::complete(Date = seq(min(Date), max(Date), by = "day"), Hour = 0:23,
                  fill = list(Total_Trips = 0)) %>% arrange(Date, Hour) %>%
  mutate(Weekday = factor(lubridate::wday(Date, week_start = 1)),
         DayIndex = as.integer(Date - min(Date)),
         lag_24 = lag(Total_Trips, 24), lag_168 = lag(Total_Trips, 168))
train <- hourly %>% filter(Date < as.Date("2014-09-01"), !is.na(lag_168))
test <- hourly %>% filter(Date >= as.Date("2014-09-01"))
set.seed(42)
model <- rpart::rpart(Total_Trips ~ Hour + Weekday + DayIndex + lag_24 + lag_168,
  data = train, method = "anova", control = rpart::rpart.control(cp = 0.002, minsplit = 30, maxdepth = 8, xval = 0))
predictions <- test %>% transmute(Date, Hour, Actual = Total_Trips,
  Baseline = lag_168, Prediction = as.numeric(predict(model, test)),
  Residual = Actual - Prediction)
metrics <- function(pred, label) {
  actual <- predictions$Actual
  data.frame(Model = label, MAE = mean(abs(actual-pred)), RMSE = sqrt(mean((actual-pred)^2)),
    MAPE = if (any(actual > 0)) mean(abs((actual[actual>0]-pred[actual>0])/actual[actual>0]))*100 else NA_real_,
    R2 = 1-sum((actual-pred)^2)/sum((actual-mean(actual))^2),
    Train_Start = min(train$Date), Train_End = max(train$Date),
    Test_Start = min(test$Date), Test_End = max(test$Date), Test_Hours = nrow(test))
}
write_csv(bind_rows(metrics(predictions$Baseline,"Seasonal naive (last week)"),
                    metrics(predictions$Prediction,"Regression tree")), "output/model/model_metrics.csv")
write_csv(predictions, "output/model/predictions.csv")
importance <- model$variable.importance
write_csv(data.frame(Feature = names(importance), Importance = as.numeric(importance)),
          "output/model/feature_importance.csv")
