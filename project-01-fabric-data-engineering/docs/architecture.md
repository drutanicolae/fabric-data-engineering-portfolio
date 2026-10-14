# NYC Yellow Taxi Data Platform on Microsoft Fabric

## 1. Project overview

This project uses the public NYC Yellow Taxi trip records to build a layered data platform in Microsoft Fabric. The goal is to demonstrate more than report authoring: repeatable ingestion, PySpark transformations, Delta Lake storage, data-quality rules, validation, orchestration, and an analytics-ready foundation for Power BI.

The implementation is being built incrementally. The core medallion pipeline and a separate Data Quality pipeline have both completed successful runs. End-to-end orchestration, optimized incremental Data Quality processing, final semantic-model validation, and Power BI reports are still in progress.

## 2. Technology and environment

- Microsoft Fabric Lakehouse and Data Pipelines
- PySpark notebooks
- Parquet source files and Delta Lake tables
- JSON manifests for tracking source-file processing
- Direct Lake semantic models
- Git and GitHub for version control and documentation

The Fabric Lakehouse is named `lh_nyc_taxi`. The main processing notebook is `nb_nyc_taxi_medallion_pipeline`, orchestrated by `pl_nyc_taxi_medallion`. Data Quality processing is implemented in `nb_nyc_taxi_data_quality` and orchestrated separately by `pl_nyc_taxi_data_quality`.

Both pipelines are currently triggered manually. They have succeeded independently; they are not yet connected into one automatically orchestrated workflow.

## 3. Data source and current scale

The project uses the public NYC TLC Yellow Taxi monthly Parquet files.

- Official TLC data page: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- Source URL pattern: `https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_YYYY-MM.parquet`

The ingestion process currently tracks 20 monthly source files. The latest recorded Silver and Gold table counts are both **78,423,712 rows**. These are the results of the latest successful processing run, not a guarantee that the public source will always expose the same number of files or rows.

## 4. Medallion architecture

### Bronze: source preservation and ingestion

Bronze files are stored under:

- `Files/bronze/yellow_taxi`
- Staging area: `Files/bronze/yellow_taxi_staging`

A JSON manifest is stored at `Files/metadata/yellow_taxi_source_manifest.json`.

The ingestion notebook checks the monthly source files and compares available metadata such as ETag, last-modified time, and content length with the manifest. New or changed files are downloaded; unchanged files are skipped. Downloads are staged and size-checked before being moved into the Bronze area. The manifest is updated only after successful processing of the file.

This makes ingestion rerunnable and avoids downloading every unchanged month on each run. In the latest recorded Bronze check, 20 files were available, 20 were skipped as unchanged, and no files failed or needed downloading.

The manifest is operational metadata used to track source-file state. It is not the source dataset itself.

### Silver: validated trip records

Silver is persisted as the Delta table `yellow_taxi_silver`. Its processing manifest is:

`Files/metadata/yellow_taxi_silver_manifest.json`

The transformation reads the available Bronze files, aligns columns with `unionByName(..., allowMissingColumns=True)`, and applies a conservative timestamp rule:

```text
tpep_dropoff_datetime >= tpep_pickup_datetime
```

Rows that fail this chronological check are excluded. Other unusual values, including negative financial amounts and zero distances, are retained for profiling instead of being silently removed.

For the initial January 2025 validation, Bronze contained 3,475,226 rows and Silver contained 3,475,102 rows. The 124 rejected rows represented approximately 0.0036% of that month's input. The broader multi-file Silver table now contains 78,423,712 rows.

Processing is tracked by source file, and the notebook uses per-file replacement logic so a changed source month can be reprocessed without blindly appending duplicate copies of that month's records.

### Gold: analytics-ready trip table

Gold is persisted as the Delta table `yellow_taxi_gold`. Its processing manifest is:

`Files/metadata/yellow_taxi_gold_manifest.json`

Gold is built from Silver and uses per-source-file replacement logic and a rule-version marker (`GOLD_RULE_VERSION=2`) to track the processing state. The latest recorded Gold row count is 78,423,712, matching Silver for the current run.

A lineage check previously confirmed that Bronze, Silver, and Gold each tracked the same 20 source files, with no missing files or metadata mismatches. A subsequent no-op Gold run reported that the data was already up to date.

The Gold table is the intended analytical trip-level output. The Data Quality tables described below are separate outputs for monitoring and investigation.

## 5. Data Quality profiling and outputs

Data Quality is implemented in a separate notebook and pipeline so that the full-table profiling workload can be run independently from the medallion transformations.

The current notebook creates these Lakehouse Delta tables:

| Table | Purpose |
|---|---|
| `dim_dq_rule` | Rule definitions, severity, and descriptions |
| `dq_summary` | One summary row per rule, including issue count and percentage |
| `dq_exceptions` | Trip-level records that violate one or more configured rules |
| `dq_rule_counts` | Exception counts by rule, including rules with zero findings |
| `dq_exception_rule_bridge` | One row per exception-to-rule association, created by splitting the exception rule list |

The latest recorded run produced 9 rule definitions, 9 summary rows, 9 rule-count rows, 6,023,630 exception rows, and 7,443,414 bridge rows. All 9 rule counts matched the corresponding summary counts in the validation output. The orphan-rule checks for the summary, rule-count, and bridge tables returned zero.

### Current rules and latest recorded counts

| Rule | Condition | Count |
|---|---|---:|
| `NEGATIVE_FARE` | Fare amount below zero | 3,005,888 |
| `NEGATIVE_TOTAL` | Total amount below zero | 1,135,505 |
| `NEGATIVE_TIP` | Tip amount below zero | 2,576 |
| `NEGATIVE_DISTANCE` | Trip distance below zero | 0 |
| `ZERO_DISTANCE` | Trip distance equals zero | 2,355,175 |
| `NULL_FARE` | Fare amount is null | 0 |
| `NULL_TOTAL` | Total amount is null | 0 |
| `ZERO_DURATION` | Calculated trip duration equals zero | 915,742 |
| `LONG_DURATION` | Calculated trip duration exceeds three hours | 28,528 |

Counts are not mutually exclusive. A trip can violate multiple rules, so the counts must not be added together to estimate the number of unique affected trips. The exception table contains trips with one or more configured exceptions.

The three-hour duration threshold is an investigation threshold chosen for this project, not an official NYC TLC business rule. Likewise, a negative amount or zero distance is a signal to investigate, not by itself proof that the source record is invalid.

### Interpretation and data-handling decisions

- **Negative financial values:** retained for investigation. They may reflect reversals or adjustments, but that interpretation requires confirmation.
- **Zero distance and zero duration:** retained and surfaced as data-quality findings rather than automatically excluded.
- **Long trips:** flagged using the current three-hour threshold for further review.
- **Missing attributes:** some records have nulls in several fields at once, including `passenger_count`, `RatecodeID`, `store_and_fwd_flag`, `congestion_surcharge`, and `Airport_fee`. These values should not automatically be replaced with zero without understanding their meaning.
- **Duplicates:** the earlier Silver profiling run found no exact duplicate rows in that profiled dataset. This should be treated as a result of that check, not a guarantee about future source files.

The overall approach is to make data issues visible and preserve evidence, rather than applying unverified business assumptions to financial records.

## 6. Data Quality semantic model

A Direct Lake semantic model named `sm_nyc_taxi_data_quality` has been created, and `dim_dq_rule` has been added to it.

The intended relationships are one-to-many, with single-direction filtering from `dim_dq_rule[rule_id]` to each rule-level table:

- `dq_summary[rule_id]`
- `dq_rule_counts[rule_id]`
- `dq_exception_rule_bridge[rule_id]`

Relationship validation and replacement of any earlier manually created DAX rule table should be completed before treating the model as finalized.

Do not join the bridge to `dq_exceptions` on `source_file` alone: that column is not a unique trip key. Also, `exception_rules` in `dq_exceptions` is a comma-separated list, not a single rule key. The bridge represents exception-to-rule associations and needs a reliable trip-level key if it is to be related back to individual exception rows.

The Gold semantic model and the Data Quality semantic model serve different purposes. The first supports operational and financial analysis; the second is intended for quality monitoring and investigation.

## 7. Orchestration and refresh status

Two Fabric pipelines exist:

1. `pl_nyc_taxi_medallion` runs `nb_nyc_taxi_medallion_pipeline`.
2. `pl_nyc_taxi_data_quality` runs `nb_nyc_taxi_data_quality`.

Both have completed successful runs when triggered independently. The Data Quality notebook currently scans the full Silver table and rebuilds its output tables. Because this is a large workload and the Fabric capacity has returned throttling errors for separate Spark jobs in earlier testing, Data Quality processing should be optimized and tested before adding it to the main workflow or scheduling frequent runs.

The intended future dependency is:

```text
Bronze ingestion
    -> Silver transformation
        -> Gold transformation
            -> Data Quality processing
                -> semantic model/report availability
```

This is the planned sequence, not the current deployed orchestration. At present, the medallion and Data Quality pipelines are separate and manually triggered. A parent pipeline, scheduled execution, and automated semantic-model refresh have not yet been confirmed as implemented.

## 8. Validation evidence

The latest recorded checks include:

- Bronze, Silver, and Gold track 20 monthly source files.
- The latest Silver and Gold row counts both equal 78,423,712.
- A repeated Gold run can report that the data is already up to date.
- Data Quality generated all five output tables.
- All 9 `dq_rule_counts` results matched the corresponding `dq_summary` counts.
- Orphan-rule checks for `dq_summary`, `dq_rule_counts`, and `dq_exception_rule_bridge` returned zero.

These checks validate the recorded run outputs. They do not replace future monitoring, source-file change handling, or model-level relationship validation.

## 9. Repository contents and source-code status

The repository currently contains this architecture document, Power Query M dimension scripts, and an older exploratory notebook named `nb_ingest_nyc_taxi.ipynb`.

**Important:** that notebook is not the current implementation of the working Fabric medallion pipeline. It should not be presented as production-ready code. The next repository task is to export the current notebooks from Fabric and replace or clearly archive the outdated exploratory artifact. Documentation should describe the working notebooks, not imply that an old export contains the current implementation.

The `.pq` files in the existing `sql` directory contain Power Query M, not SQL. The directory can be renamed or reorganized later once the current notebook exports are in place.

## 10. Power BI reporting roadmap

Two reports are planned:

### Data Quality

Intended content includes issue counts and percentages by rule, exception trends, source-file comparisons, severity, and detail views for investigating affected trips. It will use the Data Quality semantic model and its rule dimension.

### Operations and Finance

Intended content includes trip volume, pickup and drop-off patterns, trip distance and duration, payment methods, vendor activity, fares, tips, and total amounts. It will use the Gold analytical data model.

The plan is to publish both reports together in a Power BI App if the workspace configuration and licensing support the intended sharing experience. Neither report should be described as complete until the report pages, measures, and model behavior have been validated.

## 11. Next implementation milestones

1. Optimize the Data Quality notebook, ideally avoiding a full Silver rescan when only a subset of source files changes.
2. Validate the new `dim_dq_rule` relationships in `sm_nyc_taxi_data_quality` and remove the old manual DAX table only after the replacement works.
3. Export the current Fabric notebooks and add the real source to GitHub.
4. Build and validate the Data Quality report.
5. Build and validate the Operations and Finance report.
6. Test a controlled parent pipeline that runs the medallion process before Data Quality, taking Fabric capacity limits into account.
7. Configure scheduling and semantic-model refresh only after dependency and failure behavior have been tested.
8. Keep documenting row counts, rule results, and decisions as the implementation evolves.

## Final note

This is an evolving portfolio project. The current milestone demonstrates multi-file ingestion tracking, Bronze/Silver/Gold Delta processing, a separate Data Quality pipeline, and explicit validation of its rule outputs. Full orchestration, optimized incremental profiling, finalized semantic-model relationships, report development, and current notebook exports remain outstanding work.
