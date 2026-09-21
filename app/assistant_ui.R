# UI wiring only. All analytical data is cached at startup in assistant_data.
source(file.path(project_root,"app/data_assistant.R"),local=TRUE,encoding="UTF-8")
source(file.path(project_root,"app/assistant_provider.R"),local=TRUE,encoding="UTF-8")
assistant_data <- list(time=time_cube,geo=geo_cube,
  metrics=if(model_available) model_metrics else NULL,
  importance=if(model_available) importance else NULL,
  anomalies=if(ai_available) anomaly_data else NULL,
  clusters=if(ai_available) cluster_cells else NULL)
assistant_config <- da_provider_config()
da_suggestions <- function(lang,context=da_context()) {
  q <- if(lang=="vi") c("Khung giờ nào có nhiều lượt đón nhất?","Base nào hoạt động nhiều nhất?","Mô hình dự báo nào tốt nhất?","Tháng 9 có gì đáng chú ý?","Có bao nhiêu điểm bất thường?","Cụm nào có nhiều lượt đón nhất?") else c("What is the peak hour?","Which Base had the most trips?","Which forecasting model is best?","Summarize September.","How many anomalies were detected?","Which cluster has the most pickups?")
  if(!identical(context$Base,"All"))q[5] <- if(lang=="vi")paste(context$Base[1],"chiếm tỷ trọng bao nhiêu?") else paste("What share belongs to",context$Base[1],"?")
  if(any(vapply(c("Weekday","DayType","Hour"),function(k)!identical(context[[k]],"All"),logical(1)))||!is.null(context$Dates))q[6] <- da_text("What was the busiest date?","Ngày nào có nhiều lượt đón nhất?",lang)
  if(context$Direction!="All"||context$Min_Score>0)q[c(1,2,4,6)] <- if(lang=="vi")c("Hiện các giờ bất thường.","Bất thường dương lớn nhất là gì?","Bất thường âm lớn nhất là gì?","Dữ liệu có hạn chế gì?") else c("Show unusual hours.","What was the largest positive anomaly?","What was the largest negative anomaly?","What are the limitations of this dataset?")
  q
}
assistant_page <- function() nav_panel(label("nav_assistant"),value="assistant",div(class="page",
  heading("nav_assistant","da_subtitle"),div(class="assistant-layout",
    div(class="assistant-main",div(class="assistant-toolbar",textOutput("da_mode"),actionButton("da_clear",label("da_clear"))),
      div(id="assistant-transcript",role="log",`aria-live`="polite",`aria-relevant`="additions text",uiOutput("da_chat")),
      div(class="assistant-compose",textAreaInput("da_question",label("da_question"),value="",rows=3,width="100%",placeholder=tr("da_placeholder")),
        div(class="assistant-send",tags$small(label("da_input_note")),actionButton("da_send",label("da_send"),class="btn-primary")))),
    tags$aside(class="assistant-sidebar",h3(label("da_suggestions")),p(class="context",label("da_suggestion_note")),uiOutput("da_suggestions"),
      h3(label("da_scope")),p(label("da_scope_text")),
      h3(label("da_current_context")),checkboxInput("da_use_filters",label("da_use_filters"),value=TRUE),
      selectInput("da_context",label("da_context_source"),localized_choices(c("da_all","nav_demand","nav_geo","nav_base","nav_anomaly"),all=FALSE),selectize=FALSE),
      textOutput("da_context_text"),p(class="context",label("da_context_note")),
      if(da_provider_ready(assistant_config)) tagList(checkboxInput("da_llm",label("da_llm"),value=FALSE),p(class="context",label("da_external_note")))))))
assistant_server <- function(input,output,session,lang) {
  history <- reactiveVal(list());previous <- reactiveVal(NULL)
  t <- function(k,...) tr(k,lang(),...)
  value <- function(x,default="All") if(is.null(x)||!length(x))default else x
  # Remember the most recently visited analytical page, not a mixture of unrelated page filters.
  observeEvent(input$navigation,{
    map <- c(overview="da_all",demand="nav_demand",geo="nav_geo",base="nav_base",anomaly="nav_anomaly",model="da_all")
    if(input$navigation %in% names(map)) updateSelectInput(session,"da_context",selected=unname(map[[input$navigation]]))
  })
  current_context <- reactive({
    ctx <- da_context()
    if(!is.null(input$da_use_filters)&&!isTRUE(input$da_use_filters)) return(ctx)
    context_page <- value(input$da_context,"da_all")
    if(context_page=="nav_demand") {
      ctx$Month <- value(input$ta_month);ctx$Base <- value(input$ta_base);ctx$Weekday <- value(input$ta_weekday)
      ctx$DayType <- value(input$ta_daytype);ctx$Hour <- value(input$ta_hour)
      if(!is.null(input$ta_dates) && !identical(as.Date(input$ta_dates),range(calendar$Date)))ctx$Dates <- as.Date(input$ta_dates)
    } else if(context_page=="nav_geo") {ctx$Month <- value(input$geo_month);ctx$Base <- value(input$geo_base)
    } else if(context_page=="nav_base") {ctx$Month <- value(input$ba_month);ctx$Base <- value(input$ba_base);ctx$Weekday <- value(input$ba_weekday);ctx$DayType <- value(input$ba_daytype)
    } else if(context_page=="nav_anomaly") {ctx$Month <- value(input$an_month);ctx$Direction <- value(input$an_direction);ctx$Min_Score <- value(input$an_score,0)}
    ctx
  })
  observeEvent(lang(),{
    selected <- isolate(value(input$da_context,"da_all"))
    updateSelectInput(session,"da_context",choices=localized_choices(c("da_all","nav_demand","nav_geo","nav_base","nav_anomaly"),lang(),all=FALSE),selected=selected)
    updateTextAreaInput(session,"da_question",placeholder=t("da_placeholder"))
  })
  output$da_context_text <- renderText(da_scope_label(current_context(),lang()))
  output$da_mode <- renderText(if(isTRUE(input$da_llm)&&da_provider_ready(assistant_config))t("da_mode_optional") else t("da_mode_local"))
  output$da_suggestions <- renderUI(div(class="assistant-suggestions",lapply(seq_along(da_suggestions(lang(),current_context())),function(i)actionButton(paste0("da_suggest_",i),da_suggestions(lang(),current_context())[i]))))
  for(i in seq_len(6)) local({j <- i;observeEvent(input[[paste0("da_suggest_",j)]],{updateTextAreaInput(session,"da_question",value=da_suggestions(lang(),current_context())[j])})})
  output$da_chat <- renderUI({
    messages <- history()
    if(!length(messages)) return(div(class="assistant-empty",h3(t("da_welcome")),p(t("da_welcome_text"))))
    tagList(lapply(messages,function(m)tagList(
      div(class="assistant-row assistant-user",span(class="assistant-role",t("da_user")),p(m$question)),
      div(class="assistant-row assistant-answer",span(class="assistant-role",t("nav_assistant")),
        div(class="assistant-answer-body",p(class="assistant-scope",paste0(tr("da_answer_scope",m$lang),": ",m$answer$scope)),
          lapply(m$answer$lines,tags$p),lapply(m$answer$notes,function(n)p(class="assistant-note",n)),
          p(class="assistant-source",paste0(tr("da_source",m$lang),": ",paste(m$answer$sources,collapse=" · "))),
          tags$small(class="assistant-mode",tr(switch(m$answer$mode,assisted="da_assisted",fallback="da_fallback","da_local"),m$lang)))))))
  })
  observeEvent(input$da_submit,{
    submission <- input$da_submit
    if(!is.list(submission)||!is.character(submission$question)||length(submission$question)!=1||is.na(submission$question))return()
    question <- trimws(submission$question);if(!nzchar(question)) return()
    if(nchar(question)>1000) {showNotification(t("da_too_long"),type="warning");return()}
    answer_lang <- da_language(question,lang());parsed <- da_parse(question,previous())
    result <- da_execute(parsed,assistant_data,current_context(),previous())
    config <- if(isTRUE(input$da_llm)) assistant_config else list(provider="local",key="",model="")
    answer <- da_explain(question,result,answer_lang,config)
    history(tail(c(history(),list(list(question=question,lang=answer_lang,result=result,answer=answer))),20))
    if(result$status=="ok") previous(result) else previous(NULL)
    updateTextAreaInput(session,"da_question",value="")
  })
  observeEvent(input$da_clear,{history(list());previous(NULL);updateTextAreaInput(session,"da_question",value="")})
  list(history=history,previous=previous,current_context=current_context)
}
