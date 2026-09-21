# Submission integration contract. Existing suites remain independent.
.libPaths(c(".r-library",.libPaths()))
source("app/app.R",encoding="UTF-8")
stopifnot(sum(time_cube$Total_Trips)==4534327,
  sum(geo_cube$Total_Trips)==metric("Records inside NYC bbox"),
  sum(filter_cube(time_cube,"Sep","Thu","Weekday","17","B02617")$Total_Trips)==4170)
# Detect stale model/cluster results after a mart or prediction change.
stopifnot(all(model_metadata$Cube_MD5==unname(tools::md5sum(out("dashboard/dashboard_time_cube.csv")))))
meta <- readr::read_csv(out("clusters/analytics_metadata.csv"),show_col_types=FALSE)
stopifnot(meta$Geo_Cube_MD5==unname(tools::md5sum(out("dashboard/dashboard_geo_cube.csv"))),
  meta$Predictions_MD5==unname(tools::md5sum(out("model/predictions.csv"))))
questions <- c("Dataset có bao nhiêu bản ghi?","Khung giờ cao điểm là khi nào?",
  "Base nào nhiều chuyến nhất?","So sánh B02617 và B02598.","Mô hình dự báo nào tốt nhất?",
  "Random Forest và XGBoost khác nhau thế nào trong kết quả?","Có bao nhiêu anomaly?",
  "Cụm hotspot nào lớn nhất?","Tóm tắt toàn bộ đồ án.","Vì sao ngày X cao bất thường?")
intents <- c("total_trips","peak_hour","base_rank","compare_bases","model_comparison",
  "model_comparison","anomaly_summary","cluster_summary","main_findings","causal_limit")
for(i in seq_along(questions)) {
  parsed <- da_parse(questions[i]);result <- da_execute(parsed,assistant_data)
  stopifnot(parsed$intent==intents[i],result$status=="ok",da_language(questions[i],"en")=="vi")
  for(l in c("vi","en")) {
    response <- da_explain(questions[i],result,l,list(provider="local",key="",model=""))
    stopifnot(response$mode=="local",length(response$lines)>0,length(response$sources)>0)
  }
}
stopifnot(da_execute(da_parse(questions[1]),assistant_data)$facts$total==4534327,
  any(grepl("không thể xác định nguyên nhân",da_render(da_execute(da_parse(questions[10]),assistant_data),"vi")$notes)))
# Every allowed intent is exercised, not just the demo examples.
all_questions <- c("Summarize the dataset.","Summarize the project main findings.","How many pickups?",
  "What is the peak hour?","Which month has the most trips?","Which weekday is busiest?",
  "What was the busiest date?","Compare weekday vs weekend.","Rank the Bases.",
  "Compare B02617 and B02598.","Compare April and September.","Top 5 grid cells?",
  "How many records inside the NYC bounding box?","Which cluster is largest?",
  "Which forecasting model is best?","Which features are most important?","How many anomalies?",
  "What methods are used?","What are the limitations?","Why was demand high on September 13?")
seen <- vapply(all_questions,function(q){r<-da_execute(da_parse(q),assistant_data);stopifnot(r$status=="ok");r$intent},character(1))
stopifnot(setequal(seen,setdiff(da_intents,"unsupported")))
# Parse every owned R source, including standalone stages, without running them.
owned <- c("Main.R",list.files("R",pattern="[.]R$",full.names=TRUE),list.files("app",pattern="[.]R$",full.names=TRUE),list.files("tests",pattern="[.]R$",full.names=TRUE))
invisible(lapply(owned,function(f)parse(file=f,encoding="UTF-8")))
# Startup source files may never enter expensive analytical pipeline stages or raw records.
appcode <- paste(unlist(lapply(list.files("app",pattern="[.]R$",full.names=TRUE),readLines,warn=FALSE)),collapse="\n")
stopifnot(!grepl("uber-raw-data|uber_clean[.]csv|source\\([^\\n]*R/[0-9]|ranger::ranger|xgb.train|dbscan::dbscan",appcode))
stopifnot(all(c("PROJECT_SUMMARY.md","DEFENSE_QA.md","DEMO_SCRIPT.md") %in% list.files()))
html <- as.character(ui)
stopifnot(sum(grepl('data-i18n="method_',strsplit(html,"\n")[[1]],fixed=TRUE))>=9,
  all(c("metric_guide","anomaly_meaning","method_conversation_text") %in% names(translations$vi)))
cat("PASS: refreshed output lineage; exact totals; all 20 intents; 10 final demo questions; VI/EN offline; source parsing; compact startup; academic documentation.\n")

shiny::testServer(server,{
  for(l in c("vi","en")) {
    session$setInputs(language=l)
    stopifnot(identical(output$model_period,output$method_model_period),
      grepl(fmt_date(model_metrics$Train_Start[1],l),output$method_model_period,fixed=TRUE),
      grepl(tr("lag_1",l),output$method_model_features,fixed=TRUE))
  }
})
cat("PASS: Methodology periods and feature descriptions use saved metadata in both languages.\n")
