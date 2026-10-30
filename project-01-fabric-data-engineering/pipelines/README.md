# Fabric Pipelines

This folder contains exported pipeline definitions for the NYC Yellow Taxi project.

## Exported pipelines

| Pipeline | Purpose | Current status |
|---|---|---|
| `pl_nyc_taxi_medallion` | Runs the Bronze/Silver/Gold medallion processing workflow | Exported; successful independent runs recorded |
| `pl_nyc_taxi_data_quality` | Runs the Data Quality profiling workflow | Exported; successful independent runs recorded |

Files:
- `pl_nyc_taxi_medallion.zip`
- `pl_nyc_taxi_data_quality.zip`

## Execution design

The medallion and Data Quality pipelines are separate. They have been triggered manually and validated independently. A parent pipeline that automatically runs the medallion workflow before Data Quality is **TBD**. It is deferred because current Fabric capacity is insufficient for reliable implementation and testing.

The intended dependency is:

```text
Bronze ingestion -> Silver transformation -> Gold transformation
                                      |
                                      +-> Data Quality profiling
```

The Data Quality notebook profiles a large Silver dataset. Fabric Spark capacity throttling has occurred during development. Parent-pipeline orchestration, scheduling, and automated refresh are deferred (**TBD**) until sufficient capacity is available to test workload, retry, and failure behavior.

## Import and maintenance notes

These ZIP files are exported Fabric artifacts, not source-code notebooks. Import them into a compatible Fabric workspace and review workspace-specific item references and dependencies before running them. Keep the exported definitions synchronized with the actual workspace after pipeline changes.

See [the architecture document](../docs/architecture.md) for the full data flow, Lakehouse tables, validation results, and current limitations.
