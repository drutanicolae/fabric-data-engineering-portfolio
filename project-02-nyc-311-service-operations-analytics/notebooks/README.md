# Notebooks

Fabric notebook exports will be committed here as the project develops. The current engineering work is being developed and tested in the Fabric workspace; no notebook export is represented here as a finalized, version-controlled deliverable yet.

Planned notebook responsibilities:

- **Backfill Initial:** one-time historical API extraction.
- **NYC 311 Orchestrator:** monthly source discovery, manifest reconciliation, checkpoint recovery, and resumable extraction.
- **Late Arrivals Engine:** incremental detection using Socrata `:created_at`, with a dedicated watermark and separate Bronze files.
- **Updated Records Engine:** incremental detection using Socrata `:updated_at`, business-field comparison, and separate update snapshots.
- **Silver Processing:** schema normalization, data-quality validation, and current-state MERGE by `unique_key`.
- **Gold Processing:** analytical model preparation.

When exporting notebooks, remove environment-specific secrets and temporary test artifacts. Document the Fabric Lakehouse and workspace prerequisites alongside each exported notebook.
