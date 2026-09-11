# Bilingual presentation regression tests; the existing data suite is unchanged.
source('app/app.R',local=TRUE,encoding='UTF-8')
stopifnot(identical(names(translations$vi),names(translations$en)),all(nzchar(translations$vi)),all(nzchar(translations$en)))
stopifnot(fmt_number(4534327,'vi')=='4.534.327',fmt_number(4534327,'en')=='4,534,327',fmt_percent(98.42,'vi')=='98,42%')
stopifnot(identical(unname(localized_choices(month_levels,'vi')),c('All',month_levels)),identical(unname(localized_choices(weekday_levels,'en')),c('All',weekday_levels)))
stopifnot(identical(unname(localized_choices(c('Weekday','Weekend'),'vi','DayType')),c('All','Weekday','Weekend')))
original_models <- model_metrics
original_time <- time_cube
original_geo <- geo_cube
shiny::testServer(server,{
  stopifnot(lang()=='vi')
  session$setInputs(navigation='demand',ta_dates=as.Date(c('2014-04-01','2014-09-30')),ta_month='Sep',ta_daytype='Weekday',ta_weekday='Thu',ta_hour='17',ta_base='B02617',geo_month='Sep',geo_base='B02617',geo_top_n=10,ba_month='Sep',ba_weekday='All',ba_daytype='All',ba_base='B02617',de_dataset='Time cube')
  fields <- c('navigation','ta_dates','ta_month','ta_daytype','ta_weekday','ta_hour','ta_base','geo_month','geo_base','geo_top_n','ba_month','ba_weekday','ba_daytype','ba_base','de_dataset')
  before <- lapply(fields,function(k) input[[k]])
  geo_before <- geo_all();selected_before <- geo_filtered();time_before <- ta_filtered()
  vi_output <- output$ta_kpis$html
  stopifnot(sum(ta_filtered()$Total_Trips)==4170,grepl('4.170',vi_output,fixed=TRUE))
  for(language in c('en','vi')) {
    session$setInputs(language=language)
    stopifnot(identical(before,lapply(fields,function(k) input[[k]])),identical(time_before,ta_filtered()),identical(geo_before,geo_all()),identical(selected_before,geo_filtered()),identical(model_metrics,original_models),identical(time_cube,original_time),identical(geo_cube,original_geo))
    stopifnot(grepl(tr('filtered_trips',language),output$ta_kpis$html,fixed=TRUE),grepl(fmt_number(4170,language),output$ta_kpis$html,fixed=TRUE))
    # Force all chart/table/description renderers in each language, including hidden pages.
    for(id in c('ov_daily','ov_hour','ov_weekday','ov_month','ov_daytype','ta_hour_plot','ta_heatmap','ta_daily','ta_month_plot','ta_weekday_plot','ta_table','geo_map','geo_rank','geo_table','ba_rank_plot','ba_share','ba_month_plot','ba_weekday_plot','model_actual','model_residual','model_importance','model_table','de_table','quality_clean','quality_coord','quality_location')) stopifnot(!is.null(output[[id]]))
    stopifnot(grepl(tr('Seasonal naive (last week)',language),output$model_kpis$html,fixed=TRUE))
  }
  stopifnot(identical(output$ta_kpis$html,vi_output))
  session$setInputs(ta_daytype='Weekend')
  stopifnot(nrow(ta_filtered())==0,enc2utf8(output$ta_context)==enc2utf8(tr('empty','vi')))
})
cat('PASS: default VI; VI/EN/VI labels, numeric formatting, canonical choices; all filter/navigation state preserved; 4170 intersection; identical geographic/model/data values; all rendered outputs in both languages; localized empty state.\n')
