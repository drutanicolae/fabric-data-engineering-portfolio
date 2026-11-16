# Project 02: NYC 311 Service Operations Analytics

## Objective

Build an end-to-end Microsoft Fabric analytics platform using NYC 311 service-request data from the NYC Open Data REST API. The project targets approximately 23.16 million records and will progress through Bronze, Silver, and Gold layers before delivering analytical reporting in Power BI.

The focus is on reliable API ingestion, scalable data processing, incremental change capture, data quality, operational observability, and reproducible engineering.

## Difference from Project 01

| Project 01: NYC Taxi | Project 02: NYC 311 |
|---|---|
| Source-provided monthly Parquet files | REST API ingestion implemented from scratch |
| Bulk file download and Spark processing | Monthly partitions and 10,000-row API batches |
| Incremental file manifest | Composite cursor pagination and per-month checkpoints |
| Parquet source format | JSON API responses persisted as JSONL in Bronze |
| File-based recovery and reprocessing | Retry handling, recovery, late-arrival detection, and update detection |

The two projects demonstrate complementary ingestion approaches rather than repeating the same pipeline with another dataset.

## Current status (2026-11-16)

**Bronze extraction and reconciliation: complete for the current 83-month source inventory.**

| Metric | Verified value |
|---|---:|
| Monthly partitions | 83 |
| API expected records | 23,162,984 |
| Normal extracted records | 23,162,944 |
| Late-arrival records | 40 |
| Total Bronze records | 23,162,984 |
| Reconciliation difference | 0 |

The figures represent a source-count snapshot checked on 2026-11-16. NYC Open Data is a live dataset, so expected counts can change after this checkpoint.

### Implemented

- NYC Open Data source assessment and monthly partition discovery.
- 10,000-row API batches.
- Deterministic keyset pagination ordered by `created_date` and `unique_key`, without offset-based paging.
- Retry handling for transient API/network failures.
- JSONL Bronze persistence.
- Per-month checkpoints and a central ingestion manifest.
- Batch validation and interrupted-run recovery.
- Monthly orchestrator and global count reconciliation.
- Late Arrivals Engine using Socrata `:created_at`, with a dedicated watermark, seven-day overlap, keyset pagination, duplicate prevention, schema alignment, manifest updates, and post-write validation.

### Late Arrivals validation

The latest seven-day overlap run retrieved 91,809 API records and found no records missing from Bronze. The current 40 late arrivals are distributed as follows:

| Created-date month | Late arrivals |
|---|---:|
| 2026-08 | 3 |
| 2026-09 | 3 |
| 2026-11 | 34 |
| **Total** | **40** |

A controlled positive-insert test used temporary validation files and metadata. It verified the 44-column schema, write/read behavior, unique-key validation, manifest persistence, watermark persistence, and zero-difference reconciliation. The production Bronze batch files were not modified by this test.

### Updated Records Engine: in progress

Late arrivals and updates are separate source-change scenarios:

- **Late arrivals** are records newly created in Socrata after the original extraction. The source system field `:created_at` is used to discover them.
- **Updated records** already exist in Bronze but have subsequently changed. The source system field `:updated_at` is used to discover candidates.

The Updated Records Engine has its own watermark at `Files/metadata/updated_records_watermark.json`, configured with a seven-day overlap. The initial watermark is intentionally null until the initial extraction has been completed and validated.

A 20-record sample was retrieved from the API and matched against Bronze using `unique_key`. All 20 matched the correct source partitions and all 20 showed changes across the 44 business fields. The sample included a record created in August 2026 and updated in November 2026, confirming that Bronze must be located using `created_date`, not `:updated_at`.

The initial seven-day API extraction is currently being tested. Its final volume, production snapshot persistence, replay behavior, and downstream Silver MERGE are not yet complete.

## Architecture

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

### Bronze layout

```text
Files/
├── bronze/
│   └── 311_service_requests/
│       └── year=YYYY/month=MM/
│           ├── batch_NNNNN.jsonl
│           ├── late_arrivals/
│           │   └── late_arrivals_NNNNN.jsonl
│           └── updated_records/       # planned update snapshots
└── metadata/
    ├── checkpoints/
    │   └── 311_service_requests/year=YYYY/month=MM/checkpoint.json
    ├── ingestion_manifest.json
    ├── late_arrivals_watermark.json
    └── updated_records_watermark.json
```

Original backfill batches are preserved. Late arrivals are written separately. Updated-record snapshots will also be stored separately so that source changes do not overwrite the original extraction history.

## Target architecture and remaining work

1. Complete and validate the initial Updated Records API extraction.
2. Implement update candidate matching across the relevant Bronze partitions and compare all 44 business fields null-safely.
3. Persist only genuinely changed current record states as separate update snapshots, with source update metadata and replay-safe identifiers.
4. Implement Silver upsert/MERGE by `unique_key`, retaining the latest observed business state.
5. Add Silver data-quality rules and validation.
6. Build Gold analytical tables, semantic model, and Power BI reporting.
7. Integrate the independent engines into a Fabric Pipeline and configure scheduling and failure handling.

Silver, Gold, Data Quality outputs, semantic models, Power BI reporting, and automated Fabric Pipeline orchestration are not yet implemented.

## Source

- Dataset: [311 Service Requests from 2020 to Present](https://data.cityofnewyork.us/Social-Services/311-Service-Requests-from-2020-to-Present/erm2-nwe9)
- API: [Socrata API endpoint](https://data.cityofnewyork.us/resource/erm2-nwe9.json)
- API documentation: [Socrata developer documentation](https://dev.socrata.com/foundry/data.cityofnewyork.us/erm2-nwe9)

## Engineering principles

Preserve raw source data, make ingestion restartable, avoid offset-based pagination, validate every persisted batch, reconcile counts against a dated source snapshot, separate newly created records from updates to existing records, and distinguish implemented functionality from planned work.
