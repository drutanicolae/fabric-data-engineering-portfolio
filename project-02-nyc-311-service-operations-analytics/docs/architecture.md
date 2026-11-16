# NYC 311 Service Operations Analytics: Architecture

## Objective

Create a restartable, auditable data pipeline in Microsoft Fabric for NYC 311 service requests, sourced from the NYC Open Data REST API. The design separates initial historical extraction, newly created records arriving late, and changes to records that already exist in Bronze.

## Source and scale

- Dataset ID: `erm2-nwe9`
- API: `https://data.cityofnewyork.us/resource/erm2-nwe9.json`
- Current inventory: 83 monthly partitions, January 2020 through November 2026.
- Reconciliation snapshot: 2026-11-16.
- API expected records: 23,162,984.
- Normal extracted records: 23,162,944.
- Late arrivals: 40.
- Total Bronze records: 23,162,984.
- Reconciliation difference: 0.

The source is dynamic. Monthly counts are point-in-time reconciliation values, not immutable guarantees.

## Core ingestion design

1. Discover monthly partitions using `created_date`.
2. Extract records in batches of 10,000.
3. Use deterministic ordering by `created_date` and `unique_key`.
4. Continue pagination with a composite keyset cursor rather than `$offset`.
5. Persist original API records as JSON Lines in the Bronze Lakehouse area.
6. Validate saved batches for row count, null keys, duplicate `unique_key` values, and schema consistency.
7. Persist a monthly checkpoint after each successful batch and maintain a central ingestion manifest.
8. On restart, inspect and validate the next sequential Bronze batch and reconcile it with the checkpoint.
9. Retry transient connection failures, timeouts, HTTP 429, and selected 5xx responses with backoff.

## Notebook and engine responsibilities

### Backfill Initial

The initial historical extraction notebook remains a separate process. It is not reused as the daily incremental engine.

### NYC 311 Orchestrator

The orchestrator coordinates monthly source discovery, expected-count retrieval, manifest initialization and reconciliation, checkpoint inspection, recovery, and resumable monthly extraction. It preserves completed batches and does not re-extract confirmed data unnecessarily.

### Late Arrivals Engine

**Purpose:** detect records newly created in Socrata after the original monthly extraction, including records whose business `created_date` belongs to a historical month.

- Source metadata field: `:created_at`.
- Dedicated watermark: `Files/metadata/late_arrivals_watermark.json`.
- Overlap: 7 days.
- Pagination: keyset ordered by `:created_at` and `unique_key`.
- Deduplication key: `unique_key`.
- Partition assignment: `created_date` determines the original Bronze month.
- Destination: separate `late_arrivals/` JSONL files under the relevant month.
- Original batch files are never overwritten.

The engine normalizes late-arrival records to the 44 business columns in the Bronze schema. This explicit schema is important because Spark JSON inference can omit fields that are null in a small file.

**Validation checkpoint (2026-11-16):**

- 40 late-arrival records incorporated into the reconciled Bronze count: 3 in August, 3 in September, and 34 in November 2026.
- Latest seven-day overlap run retrieved 91,809 API records.
- No additional API records were missing from Bronze.
- No new records were inserted in that run.
- A separate controlled positive-insert test validated schema alignment, write/read, key uniqueness, manifest persistence, watermark persistence, and reconciliation using temporary test artifacts.

The positive-insert test was isolated from production Bronze and manifest files. It validated the component path, not a full production run with a real missing API record.

### Updated Records Engine

**Purpose:** detect changes to records already present in Bronze.

- Source metadata field: `:updated_at`.
- Dedicated watermark: `Files/metadata/updated_records_watermark.json`.
- Configured overlap: 7 days.
- Initial watermark: null until the first extraction is validated.
- Candidate identity: `unique_key`.
- Original partition: derived from `created_date`, never from `:updated_at`.
- Comparison: null-safe comparison of all 44 business columns.
- Persistence: separate update snapshots; do not overwrite original backfill batches.

The API response must explicitly select `*, :created_at, :updated_at`; Socrata system fields are not included in a plain `SELECT *` response. The two metadata timestamps serve different purposes: `:created_at` describes when the source record was created, while `:updated_at` identifies its latest source modification time.

A source update timestamp alone does not prove that business values changed. The engine must compare the API record with the current Bronze state and only persist actual business differences. The API exposes the current record state, not a complete sequence of every intermediate version.

**Validation checkpoint (2026-11-16):**

- A 20-record API sample was matched against Bronze across August and November 2026.
- All 20 records matched by `unique_key`.
- All 20 showed at least one changed business field.
- The comparison found 67 field-level differences in the initial November-only comparison: `resolution_action_updated_date` (19), `resolution_description` (19), `closed_date` (15), and `status` (14).
- A cross-partition comparison then confirmed all 20 records against their correct Bronze months, including key `70209243`, created in August and updated in November.
- The initial seven-day API extraction is in progress. Its final volume and the production update-snapshot workflow remain unvalidated.

## Lakehouse layout

```text
Files/
├── bronze/
│   └── 311_service_requests/
│       └── year=YYYY/month=MM/
│           ├── batch_NNNNN.jsonl
│           ├── late_arrivals/
│           │   └── late_arrivals_NNNNN.jsonl
│           └── updated_records/           # planned
│               └── update_snapshot_*.jsonl
└── metadata/
    ├── checkpoints/
    │   └── 311_service_requests/year=YYYY/month=MM/checkpoint.json
    ├── ingestion_manifest.json
    ├── late_arrivals_watermark.json
    └── updated_records_watermark.json
```

## Data integrity and idempotency

- `unique_key` is the record identity across partitions and processing engines.
- Original monthly batch files are immutable after successful validation.
- Late-arrival records are stored separately and reconciled into the manifest's Bronze totals.
- Update snapshots are separate from original batches and should be replay-safe.
- Overlap windows deliberately re-read a recent time range; deduplication and current-state comparison prevent duplicate business-state application.
- Manifest and watermark updates occur only after the corresponding data persistence and validation steps succeed.
- The Silver layer will represent the current record state through an upsert/MERGE keyed by `unique_key`, while Bronze retains source extraction and change evidence.

## Current implementation status

| Capability | Status |
|---|---|
| Source assessment and monthly inventory | Complete |
| 10,000-row batch extraction | Implemented |
| Composite cursor pagination | Implemented and exercised |
| Retry handling | Implemented; deliberate failure-injection testing remains |
| Bronze JSONL persistence and validation | Implemented |
| Manifest and monthly checkpoints | Implemented |
| Interrupted-run recovery | Implemented and exercised |
| 83-month Bronze reconciliation | Complete for the 2026-11-16 snapshot |
| NYC 311 monthly orchestrator | Implemented |
| Late Arrivals Engine | Implemented and validated |
| Late Arrivals positive-insert component test | Passed with temporary test artifacts |
| Updated Records API discovery | Validated |
| Updated Records business-field comparison | Validated on a 20-record sample |
| Updated Records full initial extraction | In progress |
| Update snapshot persistence and replay validation | Pending |
| Silver Delta and MERGE | Pending |
| Gold and Data Quality model | Pending |
| Semantic model and Power BI | Pending |
| Fabric Pipeline orchestration and scheduling | Pending |

## Target flow

`NYC Open Data API → NYC 311 Orchestrator → Bronze Backfill / Late Arrivals / Updated Records → Silver MERGE → Gold → Direct Lake → Power BI`

## Key design caveats

- The API dataset can change while a long extraction is running. Source counts must always be associated with a snapshot timestamp.
- `:created_at` and `:updated_at` are Socrata system metadata and must be explicitly selected.
- The monthly Bronze partition is based on `created_date`, which is not necessarily the same month as the source update event.
- Small JSONL files can contain only a subset of non-null fields. Always read them using the canonical Bronze schema when validating or comparing records.
- A seven-day overlap is a replay safety window, not a retention period. The watermark and keyset strategy must be designed so that downtime does not silently skip unprocessed updates.
- The API returns the latest record state. Multiple intermediate edits between polling runs cannot be reconstructed unless the source provides a separate history feed.
- Silver, Gold, Data Quality, semantic models, Power BI, and automated scheduling are future implementation milestones, not completed deliverables.
