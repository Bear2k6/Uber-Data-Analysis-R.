# Run every verify_*.R suite in a fresh R process; preserve and report failures.
# From the project root: Rscript --vanilla tests/run_all_tests.R
if (!file.exists("Main.R")) stop("Run from the directory containing Main.R.")
files <- sort(list.files("tests", pattern="^verify_.*[.]R$", full.names=TRUE))
if (!length(files)) stop("No verification suites found.")
runner <- file.path(R.home("bin"), if (.Platform$OS.type=="windows") "Rscript.exe" else "Rscript")
results <- data.frame(Suite=basename(files),Status="FAIL",Seconds=0)
for (i in seq_along(files)) {
  cat(sprintf("[%d/%d] %s\n",i,length(files),basename(files[i])))
  log <- tempfile(fileext=".log")
  start <- proc.time()[["elapsed"]]
  status <- tryCatch(system2(runner,c("--vanilla",shQuote(files[i])),stdout=log,stderr=log),
    error=function(e) {cat(conditionMessage(e),"\n");1L})
  results$Seconds[i] <- round(proc.time()[["elapsed"]]-start,2)
  results$Status[i] <- if(identical(as.integer(status),0L)) "PASS" else "FAIL"
  lines <- if(file.exists(log)) readLines(log,warn=FALSE,encoding="UTF-8") else "No subprocess log"
  if(results$Status[i]=="FAIL") cat(paste(lines,collapse="\n"),"\n")
  else cat(paste(grep("^PASS:",lines,value=TRUE),collapse="\n"),"\n")
  unlink(log)
}
cat("\nFINAL TEST SUMMARY\n")
print(results,row.names=FALSE)
failed <- sum(results$Status=="FAIL")
cat(sprintf("%d passed / %d failed\n",nrow(results)-failed,failed))
if(failed) quit(save="no",status=1L)
