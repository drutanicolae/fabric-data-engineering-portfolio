# Microsoft Fabric Data Engineering & Analytics Portfolio

A hands-on Microsoft Fabric data engineering and analytics project built on public NYC Yellow Taxi trip records. The portfolio demonstrates a complete analytical workflow across data ingestion, medallion architecture, PySpark transformations, data-quality profiling, Direct Lake semantic models, and Power BI reporting.

The emphasis is on engineering decisions, repeatability, validation, and transparent documentation rather than a standalone dashboard.

## Project 01: NYC Yellow Taxi Data Platform

**Status:** The Bronze/Silver/Gold processing layer, separate Data Quality pipeline, and two Direct Lake semantic models are implemented. The Power BI report has been developed with Overview and Data Quality pages. GitHub publication of the complete Power BI project and further documentation/validation are in progress. The Fabric pipelines are still triggered independently; automated end-to-end orchestration is not yet implemented.

### Technology

- Microsoft Fabric Lakehouse and Data Pipelines
- PySpark notebooks and Spark SQL
- Delta Lake tables and Parquet source data
- Incremental source-file processing with JSON manifests
- Bronze / Silver / Gold medallion architecture
- Direct Lake semantic models
- Power BI Desktop project format (PBIP) for report/model source control
- Git and GitHub

### Architecture and implementation

#### Bronze: ingestion and source tracking

- Tracks monthly NYC TLC Yellow Taxi Parquet files.
- Uses a JSON manifest and source metadata to identify new, changed, and unchanged files.
- Stages downloads and validates file sizes before promoting them to the Bronze area.
- Avoids downloading unchanged source files on every run.

The latest recorded manifest check found 20 available monthly files, all 20 unchanged, with no failed downloads. The currently verified source range is January 2025 to August 2026. Later months are not included in the recorded dataset.

#### Silver: validated trip data

- Combines monthly source files while handling schema differences.
- Applies the chronological integrity rule:

```text
tpep_dropoff_datetime >= tpep_pickup_datetime
```

- Tracks processing by source file and supports reprocessing changed months without blindly appending duplicate data.
- Retains unusual financial and trip values for investigation instead of silently removing them.

Latest recorded result: **78,423,712 rows** in `yellow_taxi_silver`.

#### Gold: analytics-ready data

- Builds `yellow_taxi_gold` from Silver.
- Uses source-file processing metadata and versioned transformation logic.
- Precomputes trip duration and grouped distance/duration bins in Fabric, reducing the need for expensive row-level calculated columns in Power BI.
- Includes the fields `TripDurationSeconds`, `TripDistanceBin`, `TripDistanceBinSort`, `TripDurationBin`, and `TripDurationBinSort`.
- Includes a separate `TaxiKeyStatistics` table with dataset-level metrics such as trip count, median and maximum duration, zero-duration and zero-distance counts, and median distance.

Latest recorded result: **78,423,712 rows** in `yellow_taxi_gold`, matching Silver.

The Gold model also contains a `DimDate` table and a `FactTaxiTrips` fact table. The active date relationship uses `DimDate[DateKey]` to `FactTaxiTrips[PickupDateKey]`. The latest validation recorded 9,375 date rows and confirmed that all fact pickup-date keys were covered by the date dimension. The date dimension currently spans 2001-01-01 to 2026-09-01; historical source records outside the main 2025-2026 analysis period should be treated carefully in time-based reporting.

#### Data Quality: profiling and exception analysis

A separate notebook and pipeline profile the Silver dataset and create dedicated Delta outputs:

| Table | Purpose |
|---|---|
| `dim_dq_rule` | Rule catalogue, severity, conditions, and interpretation |
| `dq_summary` | Rule-level issue counts and percentages |
| `dq_exceptions` | Trip records that violate one or more configured rules |
| `dq_rule_counts` | Compact count by rule, including zero-result rules |
| `dq_exception_rule_bridge` | One row per exception-to-rule association |

The Data Quality work also includes column-level NULL profiling. The latest recorded profile identified high missing-value rates in fields such as `request_source`, `passenger_count`, `RatecodeID`, `store_and_fwd_flag`, `congestion_surcharge`, and `Airport_fee`. Missing values are exposed for analysis rather than automatically replaced with zero.

Latest recorded rule findings include:

| Finding | Rows |
|---|---:|
| Negative fare amount | 3,005,888 |
| Negative total amount | 1,135,505 |
| Negative tip amount | 2,576 |
| Negative trip distance | 0 |
| Zero trip distance | 2,355,175 |
| Zero trip duration | 915,742 |
| Trip duration over three hours | 28,528 |
| NULL fare amount | 0 |
| NULL total amount | 0 |

These are investigation signals, not automatic proof that a trip is invalid. Negative financial amounts may have legitimate explanations, such as reversals or adjustments, which require business confirmation. The three-hour duration threshold is a project-defined review threshold, not an official TLC rule.

Rule counts overlap because one trip can violate multiple rules. They must not be summed to estimate unique affected trips. The exception-row count and exception-to-rule association count are also different measures.

### Semantic models and Power BI

Two Direct Lake semantic models support separate analytical purposes:

- **Gold semantic model — `sm_nyc_taxi_gold`:** operational and financial analysis based on the Gold fact and dimension tables.
- **Data Quality semantic model — `sm_nyc_taxi_data_quality`:** quality monitoring and investigation using the dedicated Data Quality tables and rule dimension.

The Power BI report currently includes:

**NYC Taxi Analytics Overview**
- Core KPIs such as total trips, fare revenue, average distance, average duration, average fare per trip, and tip rate.
- Date filtering and trend analysis.
- Payment-type distribution.
- Operational and financial overview.

**Data Quality**
- Data-quality issue counts and percentages.
- Rule-level findings and severity.
- NULL profiling and missing-value analysis.
- Trip duration and distance anomalies.
- Supporting detail for interpreting data-quality findings.

The report is being prepared for source control in Power BI Project (PBIP) format. The intended repository location is `project-01-fabric-data-engineering/power-bi/`. The complete PBIP folder structure, including the report and semantic-model definitions, should be committed together when the export is ready. Do not treat the Power BI publication or a Power BI App as complete until deployment and sharing have been validated.

### Current scale and recorded validation

| Item | Latest recorded result |
|---|---:|
| Monthly source files tracked | 20 |
| Silver rows | 78,423,712 |
| Gold rows | 78,423,712 |
| Gold fact rows | 78,423,712 |
| Gold date dimension rows | 9,375 |
| Data Quality rules | 9 |

Validation performed during development includes:

- Source-file manifest checks for new, changed, and unchanged monthly files.
- Silver and Gold row-count reconciliation.
- Timestamp integrity filtering during Silver processing.
- Gold fact date-key coverage checks.
- Data Quality rule-count reconciliation against the summary output.
- Data Quality relationship and model checks during semantic-model development.

These are recorded results from specific runs, not a guarantee that future source files or refreshes will produce identical counts.

### Orchestration and operational considerations

Two Fabric pipelines currently exist:

1. `pl_nyc_taxi_medallion` — runs the Bronze/Silver/Gold processing workflow.
2. `pl_nyc_taxi_data_quality` — runs the Data Quality profiling workflow.

Both have completed successful independent runs. They are currently triggered separately and manually. A parent pipeline, scheduled end-to-end execution, and fully automated downstream refresh have not yet been confirmed as implemented.

The Data Quality workload scans a large Silver dataset. Fabric Spark capacity throttling has occurred during development, so execution order, workload optimization, and capacity behavior need to be considered before introducing frequent scheduled runs.

### Repository layout

```text
project-01-fabric-data-engineering/
├── docs/
│   ├── architecture.md
│   └── work-log-2026-10-14.md
├── notebooks/
├── pipelines/
├── power-bi/
├── screenshots/
└── sql/
```

- `docs/`: architecture, implementation notes, and work logs.
- `notebooks/`: Fabric notebook exports. Check each notebook's provenance and version before treating it as the current implementation.
- `pipelines/`: pipeline definitions and related project artifacts.
- `power-bi/`: Power BI report and semantic-model project files.
- `screenshots/`: evidence from the Fabric workspace, Lakehouse, pipelines, notebooks, and semantic models.
- `sql/`: currently includes Power Query M dimension scripts; the folder name does not mean every file in it is SQL.

### Next milestones

1. Complete the PBIP export and commit the full report and semantic-model project structure.
2. Reconcile this README and the architecture document with the latest committed Fabric and Power BI artifacts.
3. Validate the final Power BI measures, filters, date behavior, and Data Quality interactions.
4. Optimize Data Quality processing where practical and document its capacity requirements.
5. Test a parent pipeline that runs medallion processing before Data Quality, including failure and retry behavior.
6. Configure scheduling and downstream refresh only after dependencies and capacity have been tested.
7. Add current notebook and pipeline exports, with clear versioning and documentation.

## Data source

NYC Taxi & Limousine Commission (TLC) trip records:

- Official data page: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- Monthly Yellow Taxi Parquet pattern: `https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_YYYY-MM.parquet`

## Project principles

- Preserve source traceability and processing metadata.
- Make transformations repeatable and safe to rerun.
- Validate row counts, keys, relationships, and rule outputs.
- Keep data-quality anomalies visible until their business meaning is understood.
- Separate implemented functionality from planned work.
- Keep the repository aligned with the actual Fabric and Power BI implementation.
