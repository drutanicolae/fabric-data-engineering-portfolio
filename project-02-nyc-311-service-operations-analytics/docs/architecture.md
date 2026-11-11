# NYC 311 Service Operations Analytics: Architecture

## Objective

Create a restartable, auditable data pipeline in Microsoft Fabric for NYC 311 service requests, sourced from the NYC Open Data REST API.

## Source and scale

- Dataset ID: `erm2-nwe9`
- API: `https://data.cityofnewyork.us/resource/erm2-nwe9.json`
- Snapshot: 23,100,861 records across 83 monthly partitions (January 2020 to partial November 2026).
- Snapshot timestamp: 2026-11-11.
- The source is dynamic. The monthly counts are a point-in-time reconciliation baseline, not an immutable guarantee.

## Ingestion design

1. Partition extraction by calendar month using `created_date`.
2. Request records in batches of 10,000.
3. Use deterministic ordering by `created_date` and `unique_key`.
4. Continue pagination with a composite cursor rather than `$offset`.
5. Persist original API records as JSON Lines in the Bronze Lakehouse area.
6. Validate each saved batch for row count, null keys, and duplicate `unique_key` values.
7. Persist a monthly checkpoint after each successful batch and maintain a central ingestion manifest.
8. On restart, inspect and validate the next sequential Bronze batch and reconcile it with the checkpoint.
9. Retry transient connection failures, timeouts, HTTP 429, and selected 5xx responses with exponential backoff.

Retry behavior is implemented in code but has not yet been validated through deliberate failure injection.

## Lakehouse layout

```text
Files/
├── bronze/
│   └── 311_service_requests/
│       └── year=YYYY/month=MM/batch_NNNNN.jsonl
└── metadata/
    ├── checkpoints/
    │   └── 311_service_requests/year=YYYY/month=MM/checkpoint.json
    └── ingestion_manifest.json
```

The Silver directory exists in the Lakehouse but no Silver dataset has been produced yet.

## Difference from Project 01

NYC Taxi uses monthly Parquet files published by the source. NYC 311 uses a custom REST API ingestion process. This introduces request management, cursor pagination, JSON serialization, rate-limit handling, per-partition checkpoints, and recovery from interrupted extraction.

## Current implementation status

- Source assessment and metadata inspection: complete.
- Monthly count snapshot and 83 partition definitions: complete.
- 10,000-row batch-size benchmark: complete.
- Cursor pagination: implemented and basic success path tested.
- Retry logic: implemented; failure-path testing pending.
- Bronze persistence and batch validation: implemented.
- Manifest and monthly checkpoints: initialized.
- Recovery logic: implemented and basic checks completed.
- Official Bronze extraction: January and February 2020 complete, 368,393 records reconciled.
- Remaining Bronze extraction: pending.
- Silver, Gold, Data Quality, orchestration, semantic model, and Power BI: not started.

## Important design caveat

The API dataset can change while a long extraction is running. Counts recorded in the manifest represent a snapshot taken on 2026-11-11. A final count mismatch must be investigated rather than silently ignored. A later incremental strategy should account for late-arriving or updated records, using the source update timestamp where appropriate and deduplicating by `unique_key`.

## Target flow

`NYC Open Data API → Bronze JSONL → Silver Delta → Gold model → Direct Lake → Power BI`
