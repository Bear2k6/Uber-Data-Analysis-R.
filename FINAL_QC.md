# Final integration and quality-control report

Completed 16 September 2026 on Windows / R 4.6.1. Scope: stabilize the existing project, regenerate analytical outputs, document methodology and verify the demo. No new algorithm was introduced.

## Project status

| Component | Status | Evidence |
|---|---|---|
| Pipeline | PASS | `Rscript --vanilla Main.R`, new process, exit 0, all stages 00–09; 1.1 minutes |
| Dashboard | PASS | Nine pages opened in VI and EN, meaningful content, no Shiny error panels |
| ML | PASS | Four models on 720 identical holdout hours; metric/chronology/feature checks |
| Anomaly | PASS | 11 of 552 hours; prior-only calibration and saved forecast lineage |
| Clustering | PASS | Three clusters plus noise; mass conservation and weighted-neighborhood checks |
| Data Assistant | PASS | All 20 intents and ten requested final questions; VI/EN offline, provider mocks |
| VI/EN | PASS | Labels, numbers, filters, empty states and new Methodology metadata renderers |
| Tests | **6 passed / 0 failed** | Final master-run exit 0; original five suites unchanged |
| University Word report | **INCOMPLETE** | `report/BaoCao_Uber_Data_Analysis.docx` is still zero bytes; preserved |
| Optional external API | NOT RUN | No configured provider/key/model; fallback/schema behavior tested with mocks |

The code and local demo are ready within the tested environment. This is not a claim that a required university Word submission has been completed.

## Repository audit and disposition

A file-level inventory classifies every file, including vendor dependencies and previous local evidence: `output/logs/final-file-inventory.csv`. The inventory at audit time contained 7,931 entries; 7,800 were installed R-library files. Third-party library internals were inventoried as dependencies, not presented as project-authored source reviewed line by line. Every owned R/JS/CSS source and the five original tests were inspected; owned R source files also passed syntax parsing. Raw inputs were read by the complete pipeline, not displayed row by row.

| Finding | Resolution |
|---|---|
| README described seven pages and accumulated obsolete iteration notes | Rewritten as one definitive nine-page guide with Mermaid architecture, pipeline, source definitions, models, AI, tests and submission rules |
| Setup listed/attached unused `ggthemes` | Removed after confirming no use in project source; dependency files on disk retained |
| Fresh setup added library search path before creating the directory | Create `.r-library` first; declare directly used assistant/widget namespaces explicitly |
| Two `load_result()` definitions in stages 05 and 06 | Retained as small stage-local readers to preserve independent stage execution; neither loaded by Shiny |
| Legacy prediction alias columns | Retained: the original residual chart and regression checks still consume them |
| Historical UI backup, parse dumps and old logs | Classified as local evidence in ignored `output/logs/`; excluded from submission, no unverified deletion |
| Local R environment about 510 MiB | Retained for local running; `.r-library/` ignored and explicitly excluded from ZIP instructions |
| Existing output folder layout | Preserved `results/dashboard/model/anomaly/clusters/figures`; no cosmetic renames or duplicated result trees |
| Potential stale outputs | Full `Main.R` rebuild; 34 compact CSV schemas checked; model/cluster input checksums verified by new integration suite |
| Report images | All nine regenerated PNGs decode successfully; analytical figure content stayed byte-identical to audit baseline |
| Hardcoded anomaly incident note and y-axis ticks | Replaced UI incident count with saved-data count; ticks computed from plotted range; explanatory timestamp constant removed from assistant note |
| Geographic reverse-row indexing with zero rows | Use `rev(seq_len(nrow(df)))` to preserve an empty frame safely |
| Record-count question not recognized | Count intent now recognizes `record` / `bản ghi`; bilingual detection also covers comparison/cluster phrasing |
| Methodology incomplete | Nine academic sections; dataset source/counts, EDA/Base, cached architecture, ML dates/features from metadata, anomaly, DBSCAN, assistant, limitations |
| Model interpretation unclear | Added VI/EN explanation of lower MAE/RMSE, higher R² and MAPE's nonzero denominator |
| Anomaly language could imply event/error | Explicitly states neither interpretation is automatic; chart note now says all scored hours, not whole month |
| Potential secret files | Only `.env.example` found; no credential-pattern candidates in project text/log scan; no Git history exists in this supplied folder |

No raw CSV was modified. All five original test scripts match their pre-audit SHA-256 hashes. After regenerating outputs, only model timing fields and session runtime information differ from the prior results; analytical predictions, metrics excluding timing, clusters, anomaly results and EDA outputs remain consistent. Known analytical reference values are in documentation/tests, not hardcoded as UI answers.

## Files changed

- `Main.R`: complete output summary now includes anomaly and clusters.
- `R/00_setup.R`: correct first-run library order, direct dependencies, remove unused ggthemes.
- `app/app.R`: nine-section Methodology, dynamic periods/features/counts, metric guidance, safe empty geographic ordering.
- `app/i18n.R`: corresponding VI/EN wording, compact Anomalies navigation, clearer limitations and terminology.
- `app/ai_components.R`: anomaly meaning, data-driven note and axis ticks.
- `app/data_assistant.R`: record-count parsing, Vietnamese phrase recognition, generalized zero-filled-hour explanation.
- `README.md`: definitive technical guide.
- `.gitignore`: additional temporary/editor/submission exclusions.
- Generated `output/model/model_metrics.csv` and `model_session_info.txt`: refreshed runtime measurements. All other generated files were rebuilt and reconciled.

## Files created

- `PROJECT_SUMMARY.md`: Vietnamese academic and oral-defense summary.
- `DEFENSE_QA.md`: **71** questions across dataset, R, cleaning, EDA, Base, geography, dashboard, tree, forest, boosting, metrics, anomaly, clustering, assistant and limitations.
- `DEMO_SCRIPT.md`: natural Vietnamese **6 minute 30 second** walkthrough, with preparation and offline-map contingency.
- `tests/run_all_tests.R`: discovers all verify suites, isolated processes, visible failures and nonzero failure exit.
- `tests/verify_final_integration.R`: output lineage, all intents, final question wording, syntax/startup/documentation/Methodology checks.
- `FINAL_QC.md`: this report.

Local audit/test logs and screenshots are evidence, not additional application features.

## Final results

| Model | MAE | RMSE | MAPE | R² |
|---|---:|---:|---:|---:|
| Seasonal naive (last week) | 223.32 | 349.19 | 16.28% | 0.804 |
| Regression tree | 288.06 | 422.08 | 20.90% | 0.714 |
| Random Forest | 156.84 | 225.31 | 12.17% | 0.919 |
| XGBoost | 141.19 | 205.74 | 11.28% | 0.932 |

Winner by minimum September test RMSE: **XGBoost**. This compares forecasting systems with different tree/ensemble feature sets, not a controlled algorithm-only experiment. Original seasonal baseline still outperforms the original regression tree.

- Dataset: **4,534,327** pickups; NYC bbox: **4,462,626**.
- Known filtered intersection: **4,170** (September, Weekday, Thursday, 17:00, B02617).
- Anomalies: **11 / 552 (1.99275%)**; fixed prior-week median/MAD reference, threshold > 3.5.
- Clusters: **3**, noise excluded from count; noise volume **133,098 (2.98250%)**.
- Assistant: **20** intents plus unsupported, listed fully in README. Covers dataset summaries/findings, counts, temporal peaks/comparisons, Base ranks/comparisons, grids/bbox, cluster summaries, model metrics/importance, anomalies, methodology, limits and causal refusal.

## Executed verification

Final automated run:

| Suite | Result | Seconds |
|---|---|---:|
| verify_ai_analytics.R | PASS | 12.36 |
| verify_dashboard.R | PASS | 20.72 |
| verify_data_assistant.R | PASS | 13.47 |
| verify_final_integration.R | PASS | 10.19 |
| verify_i18n.R | PASS | 9.17 |
| verify_models.R | PASS | 15.59 |

Master runner separately tested in an isolated temporary fixture with one intentionally failing suite followed by a passing suite. It printed **1 passed / 1 failed**, executed the later suite and returned status **1**. This expected fixture failure is not an application regression. The temporary fixture was removed after checking it lay beneath the R temporary directory.

Browser path: Browser plugin not available; used the available unified computer-use in-app browser and its Playwright locator API, without installing a separate browser dependency. Local URL `http://127.0.0.1:3843/`. Desktop reviewed at 1440×900 and the default approximately 1280×720; assistant responsive check at 390×844. Temporary viewport override was reset.

Flow: app loads → nine pages in VI → language switch → nine pages in EN → important filters/selectors → offline assistant → mobile layout. Each page was inspected after relevant reactive content rendered; transient output recalculation was allowed to settle.

| Browser check | Result |
|---|---|
| Correct page title/URL and nonblank content | PASS |
| All nine pages in both languages | PASS |
| No runtime/error overlay or Shiny error panel | PASS |
| Demand intersection and language preservation | 4.170 → 4,170; same filters and numbers |
| Incompatible Demand filters | Localized empty state; Reset restores data |
| Base focus | B02617 = 1,458,853 and 32.17% |
| Geography filter and cluster mode | September B02617 = 371,770 represented pickups; cluster labels fixed |
| Cluster language switch | All-data total 4,462,626, 3 clusters and 2.98% noise unchanged |
| Prediction selectors | XGBoost forecast / Random Forest importance render |
| Anomaly score filter | Score 999 yields zero scored rows without errors; Reset works |
| Assistant offline | Dataset count 4,534,327; XGBoost 205.74; September 1,028,136; sources visible |
| Assistant VI/EN question handling | VI and EN answers in one session, factual scope retained |
| Mobile assistant | Single column, controls readable, no horizontal document overflow |
| Console errors | None observed |

Five bootstrap-datepicker deprecation warnings refer to bundled legacy locale aliases (en-CA/kh/kr/rs-latin/rs); these are dependency warnings, not application exceptions. R startup also reports inherited `C.UTF-8` locale names unsupported by Windows; parsing/calendars and UTF-8 app rendering passed. Neither warning was hidden or treated as a failed calculation.

Evidence retained locally: `output/logs/final-pipeline.log`, `final-tests.log`, `final-runner-probe.log`, `final-browser-pages.json`, `final-security-scan.json`, `final-output-audit.json`, `final-file-inventory.csv`. Screenshots live outside the source tree in the task visualization directory: `final-prediction-en.png`, `final-clusters-vi.png`, `final-assistant-desktop.png`, `final-assistant-mobile.png`.

## Remaining limitations and submission boundary

The Word report remains empty and must be prepared separately under the university's requirements. No replacement content was silently fabricated, no ZIP or deployment was claimed. ZIP creation must explicitly exclude `.r-library`, `.Rproj.user`, `.env`/`.Renviron`, R history/workspaces, logs and temporary files; `.gitignore` alone is insufficient. Keep `.env.example`. The cleaned CSV can be regenerated and omitted, while raw data is needed for a full rebuild.

There is no configured optional API, so no live paid/provider request was made. Mocked success, timeout, quota, invalid JSON and invented-field fallback are tested. This LLM mode only chooses a vetted opening; it is not free-form LLM explanation. Additional browsers, clean-machine dependency installation, Linux/macOS and production hosting were not tested. Map backgrounds still require internet; the assistant and compact analytical calculations work locally.

Historical/academic limits remain as documented: no causal variables, no present-day representativeness, one holdout month, different feature sets, zero-filled-hour ambiguity, coarse grid and parameter-sensitive clustering. No further feature expansion was undertaken.

## Commands

From the directory containing Main.R:

```powershell
& 'C:\Program Files\R\R-4.6.1\bin\Rscript.exe' --vanilla R/00_setup.R
& 'C:\Program Files\R\R-4.6.1\bin\Rscript.exe' --vanilla Main.R
& 'C:\Program Files\R\R-4.6.1\bin\Rscript.exe' --vanilla tests/run_all_tests.R
& 'C:\Program Files\R\R-4.6.1\bin\Rscript.exe' -e 'shiny::runApp("app",host="127.0.0.1",port=3843,launch.browser=TRUE)'
```

Stop a running Shiny process before rebuilding, then restart to use the new outputs. No pipeline run is needed just to reopen a completed dashboard.
