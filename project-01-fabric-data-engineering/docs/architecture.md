# NYC Yellow Taxi Data Platform on Microsoft Fabric

## 1. Project overview

This project uses public NYC Yellow Taxi trip records to build a data engineering and analytics solution in Microsoft Fabric. It demonstrates repeatable multi-file ingestion, Bronze/Silver/Gold processing, PySpark transformations, Delta Lake storage, data-quality profiling, dimensional modeling, Direct Lake semantic models, and Power BI reporting.

The platform has been developed around a large dataset rather than a small reporting sample. The latest recorded Silver and Gold outputs each contain **78,423,712 rows**, sourced from 20 monthly files covering January 2025 through August 2026.

The project includes two separate analytical models and a Power BI report with an operational/financial overview and a Data Quality page. The two Fabric pipelines have run successfully independently. They are still manually triggered and are not yet connected through a fully automated parent workflow.

## 2. Fabric environment and components

- Lakehouse: `lh_nyc_taxi`
- Medallion notebook: `nb_nyc_taxi_medallion_pipeline`
- Medallion pipeline: `pl_nyc_taxi_medallion`
- Data Quality notebook: `nb_nyc_taxi_data_quality`
- Data Quality pipeline: `pl_nyc_taxi_data_quality`
- Gold semantic model: `sm_nyc_taxi_gold`
- Data Quality semantic model: `sm_nyc_taxi_data_quality`

Technology includes Microsoft Fabric Lakehouse, Data Pipelines, PySpark notebooks, Spark SQL, Delta Lake, Parquet, JSON processing manifests, Direct Lake, Power BI Desktop, and GitHub.

## 3. Source data and ingestion scope

Source: NYC Taxi & Limousine Commission (TLC) Yellow Taxi monthly Parquet files.

- Official data page: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- Monthly file pattern: `https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_YYYY-MM.parquet`

The currently verified source inventory contains 20 monthly files from January 2025 to August 2026. September and October 2026 were not part of the verified inventory at the time of the latest recorded check. Counts in this document describe recorded runs and can change when new source files are published or reprocessed.

## 4. Medallion architecture

### 4.1 Bronze: source preservation and incremental file discovery

Bronze files are stored in the Lakehouse under:

- `Files/bronze/yellow_taxi`
- Staging: `Files/bronze/yellow_taxi_staging`

Source state is tracked in `Files/metadata/yellow_taxi_source_manifest.json`.

The ingestion process checks the monthly source inventory and compares available metadata such as ETag, last-modified timestamp, and content length against the manifest. New or changed files are downloaded; unchanged files are skipped. Downloads are staged and size-checked before being moved into the Bronze area. The manifest is updated only after successful processing.

Latest recorded manifest check:
- 20 monthly files available
- 20 unchanged and skipped
- 0 downloaded or updated
- 0 failed

The manifest is operational metadata, not a replacement for the original Parquet files.

### 4.2 Silver: chronological integrity and schema alignment

Silver is stored as the Delta table `yellow_taxi_silver`. Processing state is tracked in `Files/metadata/yellow_taxi_silver_manifest.json`.

The notebook reads available Bronze files, aligns columns across monthly schemas using `unionByName(..., allowMissingColumns=True)`, and applies this timestamp integrity rule:

```text
tpep_dropoff_datetime >= tpep_pickup_datetime
```

Rows failing the chronological rule are rejected. Other suspicious values, including negative financial amounts, zero distances, and missing optional attributes, are retained for Data Quality analysis rather than silently discarded.

Recorded January 2025 validation:
- Bronze input: 3,475,226 rows
- Silver output: 3,475,102 rows
- Rejected by timestamp rule: 124 rows (approximately 0.0036%)

Latest recorded multi-month Silver output: **78,423,712 rows**.

Processing is tracked by source file and uses per-file replacement logic. This allows a changed month to be reprocessed without blindly appending a second copy of that month's records.

### 4.3 Gold: analytical fact and precomputed features

The main Gold trip table is `yellow_taxi_gold`; its manifest is `Files/metadata/yellow_taxi_gold_manifest.json`.

Gold is built from Silver and uses source-file tracking, per-file replacement, and versioned transformation logic. The latest recorded Gold output contains **78,423,712 rows**, matching Silver.

The Gold transformation precomputes analytical features in Fabric rather than forcing Power BI to calculate expensive row-level bins at query time. Current feature columns include:

- `TripDurationSeconds`
- `TripDistanceBin`
- `TripDistanceBinSort`
- `TripDurationBin`
- `TripDurationBinSort`

A separate `TaxiKeyStatistics` table stores dataset-level statistics, including total trips, median and maximum trip duration (seconds and minutes), zero-duration and zero-distance counts and percentages, median distance, and calculation date. This table is used for summary statistics without adding those calculations to the large fact table.

### 4.4 Gold dimensional model

The reporting model includes:

- `FactTaxiTrips`: trip-level fact table, currently 78,423,712 rows.
- `DimDate`: date dimension, latest recorded validation 9,375 rows.
- Supporting dimensions, including payment type and vendor.
- `TaxiKeyStatistics`: one-row dataset-level statistics table.

The active date relationship is `DimDate[DateKey]` to `FactTaxiTrips[PickupDateKey]`. The latest recorded validation confirmed pickup-date keys were covered by the date dimension, with pickup keys ranging from 20010101 to 20260831 and a maximum drop-off date key of 20260901.

The generated date dimension currently spans 2001-01-01 through 2026-09-01. Very old source records exist in small numbers and are not representative of the main 2025-2026 analytical period. The report's temporal analysis should focus on the intended analysis window rather than allowing a handful of historical records to distort trends.

## 5. Data Quality processing

Data Quality runs in a separate notebook and pipeline so its profiling workload can be managed independently from the medallion processing.

The notebook creates five Delta outputs:

| Table | Purpose |
|---|---|
| `dim_dq_rule` | Rule catalogue with rule IDs, conditions, severity, and interpretation |
| `dq_summary` | One row per rule with issue count, percentage, and total-row denominator |
| `dq_exceptions` | Trip records that violate one or more configured rules |
| `dq_rule_counts` | Compact rule counts, including rules with zero findings |
| `dq_exception_rule_bridge` | One row per exception-to-rule association |

The Data Quality work also includes column-level NULL profiling. It measures missing-value counts and percentages and supports analysis of rows where multiple nullable fields are simultaneously null. The latest recorded profile highlighted particularly high missingness in `request_source` and approximately 24.64% missingness in several fields, including `passenger_count`, `RatecodeID`, `store_and_fwd_flag`, `congestion_surcharge`, and `Airport_fee`. Missing values are surfaced for analysis rather than automatically replaced with zero.

### 5.1 Rule catalogue and interpretation

The nine configured rule categories are:

| Rule | Condition |
|---|---|
| `NEGATIVE_FARE` | Fare amount below zero |
| `NEGATIVE_TOTAL` | Total amount below zero |
| `NEGATIVE_TIP` | Tip amount below zero |
| `NEGATIVE_DISTANCE` | Trip distance below zero |
| `ZERO_DISTANCE` | Trip distance equals zero |
| `NULL_FARE` | Fare amount is null |
| `NULL_TOTAL` | Total amount is null |
| `ZERO_DURATION` | Calculated trip duration equals zero |
| `LONG_DURATION` | Calculated trip duration exceeds three hours |

A recorded Data Quality run reported the following counts:

| Finding | Rows |
|---|---:|
| Negative fare amount | 3,005,888 |
| Negative total amount | 1,135,505 |
| Negative tip amount | 2,576 |
| Negative trip distance | 0 |
| Zero trip distance | 2,355,175 |
| NULL fare amount | 0 |
| NULL total amount | 0 |
| Zero trip duration | 915,742 |
| Trip duration over three hours | 28,528 |

These counts are run-specific and should be refreshed when the Data Quality pipeline is rerun. They are investigation signals, not automatic proof that a record is invalid. Negative financial values may represent reversals or adjustments, but that interpretation requires business confirmation. The three-hour threshold is a project-defined review threshold, not an official TLC rule.

Rule counts overlap because one trip can violate multiple rules. Do not sum them to estimate unique affected trips. Likewise, exception rows and exception-to-rule bridge rows are different measures.

### 5.2 Validation and known modeling constraint

A recorded validation run produced 9 rule definitions, 9 summary rows, 9 rule-count rows, 6,023,630 exception rows, and 7,443,414 exception-to-rule associations. All nine rule counts matched the summary counts in that run, and orphan-rule checks for the summary, rule-count, and bridge outputs returned zero.

The bridge represents exception-to-rule associations. Do not join it to `dq_exceptions` using `source_file` alone because that is not a unique trip key. A reliable trip-level identifier is required for a direct exception-detail relationship.

## 6. Semantic models

Two Direct Lake semantic models separate operational analytics from data-quality monitoring.

### 6.1 Gold semantic model: `sm_nyc_taxi_gold`

Purpose: operational and financial analysis using the Gold fact table, date and descriptive dimensions, precomputed trip features, and the separate `TaxiKeyStatistics` table.

The active date relationship is based on pickup date. The report uses this model for trip volume, fare revenue, distance, duration, tip rate, and payment-type analysis.

### 6.2 Data Quality semantic model: `sm_nyc_taxi_data_quality`

Purpose: quality monitoring and investigation using the five Data Quality outputs and the rule dimension.

The rule dimension is intended to filter the summary, rule-count, and exception-rule bridge tables through one-to-many, single-direction relationships on `rule_id`. The bridge-to-exception detail relationship remains constrained by the lack of a confirmed unique trip key.

The two models are intentionally separate because their grains and analytical purposes differ.

## 7. Power BI report

The Power BI report is named **NYC Taxi Analytics** and has two principal pages.

### 7.1 NYC Taxi Analytics Overview

The overview page presents the operational and financial picture, including:
- Total Trips
- Fare Revenue
- Average Distance
- Average Duration
- Average Fare per Trip
- Tip Rate
- Previous-period comparisons where configured
- Trip and revenue trends
- Payment-type distribution
- Date filtering

The report uses the Gold Direct Lake semantic model. Trip duration and distance bins are prepared upstream in Fabric to reduce model-side calculated-column overhead.

### 7.2 Data Quality

The Data Quality page presents:
- Issue counts by rule and data-quality finding
- Percentages using the appropriate total-row denominator
- NULL profiling across selected columns
- Missing-value analysis, including simultaneous NULL patterns
- Trip distance and duration anomalies
- Exception and validation context

The page is designed to complement the overview, not duplicate the ingestion or pipeline validation evidence. The report screenshots are stored in `screenshots/`.

### 7.3 Power BI source-control status

The repository contains `power-bi/NYC Taxi Analytics.rar`, which packages the complete PBIP project, including the report and semantic-model components. A separate standalone semantic-model archive is also retained under `Semantic Models/NYC Taxi Analytics.SemanticModel.rar`. The `power-bi/nyc-taxi-analytics/` directory contains documentation for the report.

The PBIP deliverable has therefore been uploaded to GitHub as a complete archive. GitHub does not display the files inside a RAR as individually reviewable source. For file-level diffs, code review, and easier inspection of TMDL/report definitions, the extracted `.pbip` entry file and its associated `.Report/` and `.SemanticModel/` folders can additionally be committed without replacing the archive.

## 8. Pipelines, orchestration, and capacity

Two exported pipeline definitions are present in `pipelines/`:

1. `pl_nyc_taxi_medallion`
2. `pl_nyc_taxi_data_quality`

Both pipelines have completed successful runs independently. They are currently triggered separately and manually. There is no confirmed parent pipeline or automated end-to-end dependency chain.

The intended processing order is:

```text
Monthly TLC source files
        |
        v
Bronze ingestion and manifest update
        |
        v
Silver schema alignment and timestamp validation
        |
        v
Gold feature engineering and analytical tables
        |
        +------------------------------+
        |                              |
        v                              v
Gold Direct Lake model        Data Quality profiling
        |                              |
        v                              v
Operations / Finance report   Data Quality model and report
```

Data Quality currently profiles the large Silver dataset and rebuilds its outputs. Fabric Spark capacity throttling has occurred during development. This is why the two pipelines remain independently executable while orchestration, workload optimization, and refresh dependencies are evaluated. Successful independent runs must not be described as an automated end-to-end workflow.

## 9. Repository contents

```text
project-01-fabric-data-engineering/
├── docs/
│   ├── architecture.md
│   ├── work-log-2026-10-14.md
│   └── work-log-2026-10-30.md
├── notebooks/
│   ├── nb_nyc_taxi_medallion_pipeline.ipynb
│   ├── nb_nyc_taxi_data_quality.ipynb
│   ├── nb_nyc_taxi_fact_dimdate_gold.ipynb
│   └── nb_ingest_nyc_taxi.ipynb
├── pipelines/
│   ├── pl_nyc_taxi_medallion.zip
│   └── pl_nyc_taxi_data_quality.zip
├── power-bi/
│   ├── NYC Taxi Analytics.rar
│   └── nyc-taxi-analytics/
├── Semantic Models/
│   └── NYC Taxi Analytics.SemanticModel.rar
├── screenshots/
└── sql/
    ├── dim_date.pq
    ├── dim_payment_type.pq
    └── dim_vendor.pq
```

The current notebook exports include the medallion pipeline, Data Quality processing, and Gold fact/date-dimension work. The older `nb_ingest_nyc_taxi.ipynb` is an exploratory artifact and should not be confused with the current medallion implementation.

The `.pq` files in `sql/` are Power Query M scripts, not SQL scripts. The directory name is historical and may be reorganized later.

## 10. Validation snapshot

Latest recorded platform-level results:

| Check | Recorded result |
|---|---:|
| Monthly source files tracked | 20 |
| Silver rows | 78,423,712 |
| Gold rows | 78,423,712 |
| Gold fact rows | 78,423,712 |
| Date dimension rows | 9,375 |
| Configured Data Quality rules | 9 |
| Data Quality rule-count reconciliation | 9 of 9 matched in the recorded run |

These results describe specific successful runs. They are not permanent guarantees and should be updated after material source or transformation changes.

## 11. Current limitations and next milestones

1. Extract and validate the uploaded PBIP archive, confirming that the report and semantic-model definitions open and match the current Fabric artifacts.
2. Optionally commit the extracted PBIP folders alongside the archive to enable file-level review and version history.
3. Keep this architecture document, the root README, and dated work logs synchronized with material implementation changes.
4. Continue validating report measures, date filtering, NULL analysis, and the distinction between rule violations and unique affected trips.
5. Optimize Data Quality processing and assess capacity before scheduling frequent full-table profiling.
6. Design and test parent-pipeline orchestration, including failure handling and retry behavior.
7. Configure scheduled execution and downstream refresh only after dependencies and capacity have been validated.

## Project principles

- Preserve source traceability and processing metadata.
- Make transformations rerunnable and safe for changed source files.
- Validate row counts, date keys, rule counts, and model relationships.
- Keep anomalies visible until their business meaning is understood.
- Separate implemented capabilities from planned work.
- Keep GitHub documentation aligned with the actual Fabric and Power BI artifacts.
