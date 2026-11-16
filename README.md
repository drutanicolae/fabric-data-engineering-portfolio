# Microsoft Fabric Data Engineering & Analytics Portfolio

A hands-on Microsoft Fabric data engineering and analytics project built on public NYC Yellow Taxi trip records. The portfolio demonstrates repeatable ingestion, a Bronze/Silver/Gold Lakehouse architecture, PySpark transformations, data-quality profiling, Direct Lake semantic models, and Power BI reporting at scale.

The emphasis is on engineering decisions, rerunnable processing, validation, and transparent documentation rather than a standalone dashboard.

## Project 01: NYC Yellow Taxi Data Platform

**Status:** The medallion processing layer, separate Data Quality pipeline, two Direct Lake semantic models, and a two-page Power BI report are implemented. The complete Power BI Project (PBIP), including the report and semantic-model components, has been uploaded as `power-bi/NYC Taxi Analytics.rar`. The archive is the repository's packaged PBIP deliverable; its contents are not individually browsable in GitHub. The Fabric pipelines have completed successful independent runs but are still triggered separately. Automated end-to-end orchestration is marked **TBD** because the current Fabric capacity is insufficient for further orchestration and scheduling tests.

### Technology

- Microsoft Fabric Lakehouse and Data Pipelines
- PySpark notebooks and Spark SQL
- Delta Lake and Parquet
- JSON manifests for incremental source-file tracking
- Bronze / Silver / Gold medallion architecture
- Direct Lake semantic models
- Power BI Desktop and Power BI Project (PBIP)
- Git and GitHub

### Data platform

The project ingests public NYC TLC Yellow Taxi monthly Parquet files. The currently verified inventory contains 20 monthly files from January 2025 through August 2026.

| Layer / output | Latest recorded result |
|---|---:|
| Bronze source files tracked | 20 |
| Silver table | 78,423,712 rows |
| Gold table | 78,423,712 rows |
| Gold fact table | 78,423,712 rows |
| Gold date dimension | 9,375 rows |
| Data Quality rules | 9 |

**Bronze**
- Checks monthly source files against a JSON manifest.
- Identifies new, changed, and unchanged files using available source metadata.
- Stages and validates downloads before promoting them to Bronze.

**Silver**
- Aligns monthly schemas.
- Applies the chronological integrity rule `tpep_dropoff_datetime >= tpep_pickup_datetime`.
- Tracks processing by source file and supports per-file replacement.
- Retains unusual financial and trip values for investigation.

**Gold**
- Produces the analytical trip table and dimensional reporting structures.
- Precomputes trip duration and grouped distance/duration bins in Fabric.
- Includes `TaxiKeyStatistics` for dataset-level metrics such as median/max duration, zero-duration and zero-distance statistics, and median distance.

**Data Quality**
- Produces rule definitions, rule summaries, exception details, rule counts, and an exception-to-rule bridge.
- Profiles NULL counts and percentages across selected columns, including rows with multiple nullable fields simultaneously missing.
- Retains anomalies for investigation rather than automatically deleting or overwriting them.

Rule findings include negative fares, negative total amounts, negative tips, zero-distance trips, zero-duration trips, and trips longer than the project-defined three-hour review threshold. These counts overlap and must not be summed to estimate unique affected trips. They are investigation signals, not automatic proof of invalid records.

See [the architecture document](project-01-fabric-data-engineering/docs/architecture.md) for the detailed design, table definitions, recorded results, modeling constraints, and limitations.

### Semantic models and Power BI

Two Direct Lake semantic models support different analytical purposes:

- `sm_nyc_taxi_gold`: operational and financial analysis using the Gold fact and dimension tables.
- `sm_nyc_taxi_data_quality`: quality monitoring and investigation using the Data Quality outputs and rule dimension.

The **NYC Taxi Analytics** Power BI report contains two pages:

1. **NYC Taxi Analytics Overview** — trip volume, fare revenue, average distance and duration, average fare, tip rate, trends, payment-type distribution, and date filtering.
2. **Data Quality** — rule-level issue counts and percentages, NULL profiling, and trip distance/duration anomalies.

### Orchestration status

Two Fabric pipelines are present:

- `pl_nyc_taxi_medallion`
- `pl_nyc_taxi_data_quality`

Both have completed successful independent runs and are manually triggered. A parent pipeline, scheduled execution, and automated end-to-end refresh are **TBD**. Fabric Spark capacity limitations currently prevent reliable testing of these additions.

### Repository layout

```text
project-01-fabric-data-engineering/
├── docs/                 # Architecture and dated work logs
├── notebooks/            # Fabric notebook exports
├── pipelines/            # Exported Fabric pipeline definitions
├── power-bi/             # Power BI report archive and PBIP project folder
├── Semantic Models/      # Semantic-model archive and documentation
├── screenshots/          # Fabric and Power BI evidence
└── sql/                  # Power Query M dimension scripts (.pq)
```

The repository currently contains:
- Exported medallion, Data Quality, and Gold fact/date-dimension notebooks, plus an older exploratory ingestion notebook.
- ZIP exports of both Fabric pipelines.
- A complete PBIP package at `project-01-fabric-data-engineering/power-bi/NYC Taxi Analytics.rar`, containing the report and semantic-model project components.
- A separate semantic-model archive at `project-01-fabric-data-engineering/Semantic Models/NYC Taxi Analytics.SemanticModel.rar`, retained as an additional standalone export.
- A `power-bi/nyc-taxi-analytics/` directory containing project documentation. The PBIP contents are stored in the RAR archive rather than expanded into individually browsable GitHub files.

The `.pq` files in `sql/` are Power Query M scripts, not SQL.

### Next milestones

1. Verify that the uploaded PBIP archive can be extracted and opened, and that its report and semantic-model definitions match the current Fabric artifacts.
2. Optionally publish the extracted PBIP source structure alongside the archive for file-level review and version history.
3. Continue validating report measures, date behavior, and Data Quality interactions.
4. **TBD (capacity-dependent):** optimize Data Quality processing and evaluate parent-pipeline orchestration, failure/retry handling, scheduling, and downstream refresh when sufficient Fabric capacity is available.

## Project 02: NYC 311 Service Operations Analytics

**Status (2026-11-16):** The complete 83-month Bronze extraction has been reconciled against the current NYC Open Data API count snapshot. The project now includes a monthly ingestion orchestrator, a validated Late Arrivals Engine, and initial design and validation work for an Updated Records Engine. Silver, Gold, semantic models, Power BI reporting, and scheduled Fabric Pipeline orchestration are not yet implemented.

### Objective

Build an end-to-end NYC 311 analytics platform in Microsoft Fabric using the NYC Open Data REST API and approximately 23.16 million service-request records.

### How this differs from Project 01

- **Project 01 (NYC Taxi):** ingests monthly Parquet files already published by the source, downloads them to Bronze, and processes them with Spark.
- **Project 02 (NYC 311):** implements API ingestion from scratch, including monthly partitions, 10,000-row batches, composite cursor pagination, retries, JSONL Bronze files, checkpoints, recovery, and incremental change detection.

Together, the projects demonstrate file-based bulk ingestion and resilient API-based ingestion.

### Current verified Bronze state

| Metric | Result |
|---|---:|
| Monthly partitions | 83 |
| API expected records | 23,162,984 |
| Normal extracted records | 23,162,944 |
| Late-arrival records | 40 |
| Total Bronze records | 23,162,984 |
| Reconciliation difference | 0 |

The reconciliation snapshot is dated 2026-11-16. NYC Open Data is a live source, so these counts are a dated checkpoint, not a permanent guarantee.

### Implemented ingestion capabilities

- Monthly partition discovery based on `created_date`.
- 10,000-row extraction batches and deterministic composite cursor pagination using `created_date` and `unique_key`.
- Retry handling, per-month checkpoints, manifest tracking, and interrupted-run recovery.
- Bronze JSONL persistence and validation.
- A separate orchestrator for month discovery, manifest reconciliation, and resumable extraction.

### Incremental processing

**Late Arrivals Engine: implemented and validated**

The `run_late_arrivals_engine()` workflow uses Socrata's `:created_at` field to detect records newly created in the source after the original monthly extraction, including records whose `created_date` belongs to a historical month.

- Dedicated watermark: `Files/metadata/late_arrivals_watermark.json`.
- Seven-day overlap and keyset pagination.
- Deduplication by `unique_key`.
- Explicit alignment to the 44-column Bronze business schema.
- Separate late-arrival JSONL files; original batch files are not overwritten.
- Manifest and watermark persistence checks.

The latest overlap run retrieved 91,809 API records and found no additional records missing from Bronze. The 40 previously recovered late arrivals remain reconciled: 3 from August, 3 from September, and 34 from November 2026. A controlled positive-insert component test validated schema alignment, write/read behavior, manifest and watermark persistence, and reconciliation using temporary test artifacts.

**Updated Records Engine: in progress**

This separate workflow uses Socrata's `:updated_at` field to identify existing service requests whose business fields have changed.

- Dedicated watermark: `Files/metadata/updated_records_watermark.json`.
- Seven-day overlap configured; initial watermark intentionally remains unset until the first extraction is validated.
- Candidate records are matched to Bronze by `unique_key`.
- The source partition is resolved using `created_date`, not `:updated_at`.
- All 44 business fields are compared using null-safe equality.
- Only actual business changes should become update snapshots; a metadata timestamp change alone is insufficient.

A 20-record sample matched all 20 records to their correct Bronze partitions. All 20 showed business-field differences, including status, close date, and resolution fields. One record created in August and updated in November confirmed that comparison must read the original `created_date` partition. The initial seven-day API extraction is still running; its final volume and production snapshot-writing logic are not yet validated.

### Target architecture

```text
NYC Open Data API
       |
NYC 311 Orchestrator
       |
       +---- Backfill / New Monthly Partitions
       |
       +---- Late Arrivals Engine (:created_at)
       |
       +---- Updated Records Engine (:updated_at)
                       |
                Change Snapshots
                       |
                  Silver MERGE
                       |
                 Gold / Power BI
```

The original Backfill Initial notebook remains separate from the ongoing orchestrator and incremental engines. Next milestones are to complete and validate Updated Records extraction, implement update snapshots and Silver MERGE, then build Gold, Data Quality, the semantic model, Power BI reporting, and Fabric Pipeline orchestration.

See the [Project 02 README](project-02-nyc-311-service-operations-analytics/README.md), [architecture notes](project-02-nyc-311-service-operations-analytics/docs/architecture.md), and [2026-11-16 work log](project-02-nyc-311-service-operations-analytics/docs/work-log-2026-11-16.md).

## Data source

NYC Taxi & Limousine Commission (TLC) trip records:

- Official data page: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- Monthly Yellow Taxi Parquet pattern: `https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_YYYY-MM.parquet`

## Project principles

Preserve source traceability, make transformations rerunnable, validate outputs, keep anomalies visible until their business meaning is understood, and distinguish implemented functionality from planned work.
