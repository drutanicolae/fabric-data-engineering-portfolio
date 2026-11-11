# Project 02: NYC 311 Service Operations Analytics

## Objective

Build an end-to-end Microsoft Fabric analytics platform using NYC 311 service-request data from the NYC Open Data REST API. The project targets approximately 23.1 million records and will progress through Bronze, Silver, and Gold layers before delivering analytical reporting in Power BI.

The focus is on reliable API ingestion, scalable data processing, data quality, operational observability, and reproducible engineering.

## Difference from Project 01

| Project 01: NYC Taxi | Project 02: NYC 311 |
|---|---|
| Source-provided monthly Parquet files | REST API ingestion implemented from scratch |
| Bulk file download and Spark processing | Monthly partitions and 10,000-row API batches |
| Incremental file manifest | Composite cursor pagination and per-month checkpoints |
| Parquet source format | JSON API responses persisted as JSONL in Bronze |
| File-based recovery and reprocessing | Retry handling and recovery from saved Bronze batches |

The two projects demonstrate complementary ingestion approaches rather than repeating the same pipeline with another dataset.

## Current status

**In progress: Bronze ingestion framework and initial extraction.**

- Source dataset: NYC Open Data, `erm2-nwe9`.
- Source endpoint: [NYC 311 API](https://data.cityofnewyork.us/resource/erm2-nwe9.json).
- Snapshot inventory: 83 monthly partitions, January 2020 to November 2026.
- Snapshot total: 23,100,861 records, measured on 2026-11-11. November 2026 is partial.
- Batch size: 10,000 records.
- Pagination: deterministic composite cursor using `created_date` and `unique_key`.
- Completed: January and February 2020.
- Bronze records extracted and reconciled: **368,393**.
- Manifest and monthly checkpoints are initialized for all 83 partitions.
- Retry, Bronze validation, and interrupted-run recovery logic are implemented. Failure-path retry behavior has not yet been stress-tested.

The full monthly extraction is not yet complete. Silver, Gold, Data Quality outputs, orchestration, semantic models, and Power BI reporting remain planned work.

## Target architecture

`NYC Open Data API → Bronze JSONL → Silver Delta → Gold analytical model → Direct Lake semantic model → Power BI`

## Repository structure

```text
project-02-nyc-311-service-operations-analytics/
├── docs/                 # Architecture, decisions, data quality and work logs
├── notebooks/            # Fabric notebook exports
├── pipelines/            # Fabric pipeline definitions
├── power-bi/             # Power BI report and PBIP deliverables
├── Semantic Models/      # Semantic model exports and documentation
├── screenshots/          # Fabric and Power BI evidence
└── sql/                  # SQL and Power Query scripts
```

## Source

- Dataset: [311 Service Requests from 2020 to Present](https://data.cityofnewyork.us/Social-Services/311-Service-Requests-from-2020-to-Present/erm2-nwe9)
- API: [Socrata API endpoint](https://data.cityofnewyork.us/resource/erm2-nwe9.json)
- API documentation: [Socrata developer documentation](https://dev.socrata.com/foundry/data.cityofnewyork.us/erm2-nwe9)

## Engineering principles

Preserve raw source data, make ingestion restartable, avoid offset-based pagination, validate every persisted batch, reconcile extracted counts against a documented source snapshot, and distinguish completed functionality from planned work.
