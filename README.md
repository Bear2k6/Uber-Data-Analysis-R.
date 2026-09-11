# Uber NYC Demand Intelligence

An R analysis pipeline and Shiny dashboard for 4,534,327 Uber NYC pickup records from April–September 2014. The existing temporal, dispatch Base and geographic analyses are preserved. The dashboard uses exact compact aggregates, never the 4.5-million-row cleaned file.

## Run locally

Use the directory containing `Main.R` as your working directory (the supplied download has an extra outer folder).

```r
source("R/00_setup.R")  # one-time dependency setup; installs missing packages
source("Main.R")       # regenerate all analysis, dashboard and model outputs
shiny::runApp("app")
```

Or from a terminal with Rscript on PATH:

```sh
Rscript R/00_setup.R
Rscript Main.R
Rscript -e 'shiny::runApp("app", host="127.0.0.1", port=3838)'
Rscript tests/verify_dashboard.R
```

Dependencies: ggplot2, dplyr, tidyr, lubridate, ggthemes, scales, readr, shiny, bslib, leaflet, DT, plotly; the model uses the R-recommended rpart package. This workspace has a project-local `.r-library/` (ignored by version control). Both setup and the app also support normally installed R packages. Runtime never installs packages. Missing or invalid required outputs produce an actionable `Rscript Main.R` error.

## Structure and pipeline

```text
data/                          Six original monthly CSV files
R/
  00_setup.R                   Dependency setup
  01_data_cleaning.R           Validation, parsing, duplicate/missing audit
  02_time_analysis.R           Original temporal summaries
  03_base_analysis.R           Original Base summaries
  04_location_analysis.R       Bounding box, grid, hotspots, quality
  05_visualization.R           Nine report figures
  06_insight_dashboard.R       Original exported insight metrics
  07_dashboard_marts.R         Exact time and geographic cubes
  08_demand_model.R            Chronological prediction experiment
app/
  app.R                        Seven-page Shiny application
  helpers.R                    Validation, filtering and aggregation helpers
  i18n.R                       Central VI/EN dictionary and formatters
  components.R                 Reusable presentation components
  www/dashboard.css            Editorial layout and responsive tokens
  www/language.js              In-place language updates
output/
  results/                     Existing summaries, cleaning_quality.csv, uber_clean.csv
  figures/                     Preserved figure filenames
  dashboard/                   dashboard_time_cube.csv, dashboard_geo_cube.csv
  model/                       model_metrics.csv, predictions.csv, feature_importance.csv
report/                        Original report placeholder (supplied file is empty)
tests/verify_dashboard.R        Raw-data reconciliation and Shiny server tests
Main.R
```

Paths consistently use lowercase `data/`, `output/`, `report/`, `app/`, and uppercase `R/` and `Main.R`. The two formerly numbered 03 scripts now have distinct stage numbers. Run from the repository root on Windows or Linux. Linux needs the usual system libraries for R package installation; no Linux execution was performed in this Windows workspace.

## Dashboard

- **Overview / Tổng quan:** four primary metrics, a secondary summary row, daily trend with editorial annotations, and numbered temporal/comparison sections.
- **Demand Patterns:** date range, month, day type, weekday, hour and Base intersect on one dataset. Every KPI, chart, heatmap and table uses that selection. Reset and filtered CSV export are included.
- **Geography / Phân bố địa lý:** exact Month/Base filtering, Top N grid cells, Leaflet markers, ranks, shares, hotspot chart/table and CSV export. Shares use the full geographic selection before Top N.
- **Base Analysis / Phân tích Base:** calendar filters, Base focus, contextual rank and share, Base/month and Base/weekday heatmaps. Share is within this dataset, not the total ride-hailing market.
- **Prediction / Dự báo:** both baseline and regression-tree metrics, actual/predicted series, residuals, feature importance and limitations.
- **Data Explorer:** allowlisted compact aggregates and quality outputs, row counts, search/column filtering, CSV export of matching rows.
- **Methodology:** actual cleaning and coordinate audits, bounding-box definition, duplicates policy and metric denominators.

The time cube has 21,852 rows (Date, Month, Weekday, DayType, Hour, Base, Total_Trips). The geographic cube has 23,795 rows (Month, Base, Lat_Grid, Lon_Grid, Total_Trips). Both are read once at startup. Raw/cleaned records and the individual-pickup location sample are excluded from the app.

## Definitions and limits

- Records are pickups, not verified unique journeys or unmet demand. The 82,581 duplicate rows are reported and retained because no unique trip identifier exists.
- Date/time is interpreted as supplied wall-clock components; English calendar labels are set explicitly rather than relying on the operating-system locale.
- Filtered average/day includes eligible calendar dates with zero pickups for the selected hour/Base. Incompatible calendar filters return a clear empty state.
- Weekdays average 25,939 pickups/day and weekends 21,852, approximately 18.7% higher on weekdays. The app calculates this from unrounded aggregates.
- Coverage is 98.42% of valid coordinates inside latitude 40.5774–40.9176 and longitude −74.1500–−73.7004. This rectangular filter is not an administrative NYC boundary.
- Grids preserve `round(coordinate / 0.01) * 0.01`. They are not exact 1 km² cells or identified neighborhoods. Coordinates are displayed to four decimal places. Leaflet basemap tiles need internet access.
- Destination, fare, driver/customer identity, weather, traffic, holidays, events, pricing and supply are unavailable. Descriptive patterns cannot establish causation.

## Historical prediction experiment

Hourly observations are ordered chronologically. Training uses April 8–August 31 after a seven-day lag warmup; testing uses all 720 September hours. A fixed rpart regression tree (cp 0.002, minsplit 30, maxdepth 8; no random cross-validation) uses hour, weekday, day index, lag_24 and lag_168. No fitting or tuning uses September outcomes.

Evaluation is rolling **one hour ahead**: earlier observed September counts can be used as later lag features. It is not a month-ahead forecast. A seasonal naive baseline repeats demand from 168 hours earlier.

| Model | MAE | RMSE | MAPE | R² |
|---|---:|---:|---:|---:|
| Previous-week baseline | 223.32 | 349.19 | 16.28% | 0.804 |
| Regression tree | 288.06 | 422.08 | 20.90% | 0.714 |

The baseline outperforms the tree on this holdout. These are measured historical results, not claims of modern forecasting reliability. MAPE excludes zero-actual hours. Importance measures split improvement and is not causal. The model outputs are optional for dashboard startup; core pages remain available if the model output files are absent.

## Verification

`tests/verify_dashboard.R` independently parses the original September CSV, verifies 140 Base/weekday/hour intersections, reconciles every September geographic cell, checks date ranges and original aggregate totals, exercises Shiny server filtering/empty states, and recomputes model MAE. The requested Sep + Weekday + Thu + 17 + B02617 intersection is **4,170** records.

The existing `report/BaoCao_Uber_Data_Analysis.docx` is zero bytes in the supplied repository. It was preserved; no report content could be reviewed.

Original project reference: [DataFlair Uber Data Analysis](https://data-flair.training/blogs/r-data-science-project-uber-data-analysis/). This project is for education and research.

## Bilingual presentation

Vietnamese is the default. The compact VI / EN control updates one shared application; it does not reload datasets or regenerate marts. `app/i18n.R` contains UI copy, dimension display labels, table language and number/date formatters. `app/components.R` renders localized charts and display-only table values. `app/www/language.js` updates static labels in place. Server reactive data filters do not depend on language.

Canonical filter values (`Apr`–`Sep`, `Mon`–`Sun`, `Weekday`/`Weekend`, Base codes) and CSV columns/values remain unchanged. Date table sorting uses canonical ISO dates while display dates are localized. Chart hover labels, legends, notes, navigation, validations, methodology and table controls support both languages. Third-party map place names and attribution remain as provided by OpenStreetMap.

Run both checks from the repository root:

```r
Rscript tests/verify_dashboard.R
Rscript tests/verify_i18n.R
```

The original reconciliation suite is unchanged. The bilingual suite checks default VI, VI/EN/VI round trips, navigation and filter preservation, the 4,170 intersection, identical geographic/model values, localized empty states, and every chart/table renderer in both languages. Protected pipeline/helper/test and mart/model files were compared against pre-edit SHA-256 hashes: no changes.

## Submission

`.r-library/` is the developer machine's local R environment. Keep it for local use, but exclude it from Git and the final submission ZIP. `.gitignore` already excludes it; ZIP tools do not automatically honor `.gitignore`, so explicitly omit `.r-library/` and `output/logs/` when packaging. No submission archive is generated by this UI task.

`report/BaoCao_Uber_Data_Analysis.docx` is still the original zero-byte file. A real report must be supplied separately; this task does not fabricate one.
