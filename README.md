# Microsoft Fabric Data Engineering & Analytics Portfolio

A hands-on portfolio project built with Microsoft Fabric and public NYC Yellow Taxi data. The focus is on data engineering practices that go beyond a single report: incremental ingestion, a Bronze/Silver/Gold Lakehouse design, PySpark transformations, data-quality profiling, Delta tables, and documented validation.

## Project 01: NYC Yellow Taxi Data Platform

**Status:** Core medallion processing and a separate Data Quality pipeline have been run successfully. Power BI reports and end-to-end orchestration are still in progress.

### Technology

- Microsoft Fabric Lakehouse and Pipelines
- PySpark notebooks
- Delta Lake tables
- Parquet source files
- Incremental file processing with JSON manifests
- Direct Lake semantic models
- Git and GitHub

### Current implementation

- **Bronze ingestion:** checks monthly NYC TLC Parquet source files and uses a manifest to identify new, changed, and unchanged files. Downloads are staged and checked before the manifest is updated.
- **Silver transformation:** reads Bronze data, applies the timestamp validation rule `tpep_dropoff_datetime >= tpep_pickup_datetime`, and writes the `yellow_taxi_silver` Delta table with per-source-file replacement logic.
- **Gold transformation:** builds the `yellow_taxi_gold` Delta table from Silver and tracks processed source files in a separate manifest.
- **Data Quality pipeline:** profiles Silver and creates dedicated Delta tables for rule summaries, exception records, rule counts, a rule bridge, and rule definitions.
- **Validation:** compares the Data Quality summary and rule-count outputs; the latest run matched all 9 configured rules.
- **Orchestration:** two Fabric pipelines currently exist and have succeeded independently: `pl_nyc_taxi_medallion` and `pl_nyc_taxi_data_quality`. They are manually triggered and are not yet connected as one end-to-end automated workflow.

### Current scale and latest recorded results

| Item | Latest recorded result |
|---|---:|
| Monthly source files tracked in Bronze/Silver/Gold | 20 |
| Silver rows | 78,423,712 |
| Gold rows | 78,423,712 |
| Data Quality rules | 9 |
| Data Quality exception rows | 6,023,630 |
| Rule-count validations | 9 of 9 matched |

The exception table contains trips that violate one or more rules. Rule counts overlap, so they must **not** be summed to estimate unique affected trips.

### Data Quality findings

Latest recorded counts include 3,005,888 negative fares, 1,135,505 negative total amounts, 2,355,175 zero-distance trips, 915,742 zero-duration trips, and 28,528 trips lasting more than three hours. These are investigation signals, not automatic proof that a trip is invalid. Financial anomalies are retained for analysis rather than silently removed.

### Planned next steps

1. Optimize Data Quality processing so it does not needlessly rescan the full Silver table.
2. Finish and validate the Data Quality semantic model relationships.
3. Build two Power BI reports: Data Quality and Operations/Finance.
4. Publish the reports together in a Power BI App, where supported by the workspace and licensing.
5. Connect the two pipelines in a controlled workflow and configure refresh only after capacity and dependencies have been tested.
6. Export the current Fabric notebooks and replace the outdated exploratory notebook in this repository with the real implementation.
7. Expand the documentation with lineage, rule definitions, refresh behavior, and validation evidence.

### Latest documentation and evidence

- [Work log — 14 October 2026](project-01-fabric-data-engineering/docs/work-log-2026-10-14.md): explains the five Data Quality tables, latest rule results, validation, screenshots, and next steps.
- [Fabric screenshots](project-01-fabric-data-engineering/screenshots/): workspace, Lakehouse, medallion processing, pipeline runs, Data Quality results, and semantic models.

## Repository layout

- `project-01-fabric-data-engineering/docs/architecture.md`: architecture, processing rules, current status, and design decisions.
- `project-01-fabric-data-engineering/notebooks/`: notebook exports. The existing ingestion notebook is an older exploratory artifact and should not be treated as the current Fabric implementation until replaced with a fresh export.
- `project-01-fabric-data-engineering/sql/`: currently contains Power Query M (`.pq`) dimension scripts, despite the folder name.

## Data source

NYC Taxi & Limousine Commission (TLC) trip records:

- Official data page: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- Monthly Yellow Taxi Parquet pattern: `https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_YYYY-MM.parquet`

## Project principle

Keep source data traceable, make transformations rerunnable, validate outputs, and document uncertainty. The repository describes the current implementation honestly: the core pipelines have run successfully, while report development, full orchestration, and refreshed notebook exports remain unfinished.
