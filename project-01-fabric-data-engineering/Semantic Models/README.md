# Semantic Models

This folder stores semantic-model deliverables for the NYC Yellow Taxi Fabric project.

## Models

### Gold analytical model

- Fabric model: `sm_nyc_taxi_gold`
- Purpose: operational and financial reporting.
- Main fact table: `FactTaxiTrips` (78,423,712 rows in the latest recorded validation).
- Date dimension: `DimDate`.
- Supporting tables include descriptive dimensions and `TaxiKeyStatistics`.
- Active date relationship: `DimDate[DateKey]` to `FactTaxiTrips[PickupDateKey]`.

### Data Quality model

- Fabric model: `sm_nyc_taxi_data_quality`
- Purpose: data-quality monitoring and exception analysis.
- Main tables: `dim_dq_rule`, `dq_summary`, `dq_exceptions`, `dq_rule_counts`, and `dq_exception_rule_bridge`.
- The rule dimension supports rule-level analysis. A direct bridge-to-exception detail relationship must not rely on `source_file` alone because it is not a unique trip key.

## Repository artifact

- `NYC Taxi Analytics.SemanticModel.rar` is the semantic-model archive currently stored in this folder.

The archive is a packaged artifact. For reviewable source control, retain the extracted semantic-model definition files (for example, TMDL files and model metadata) in the repository when available. Verify that the exported model corresponds to the current Fabric model before replacing an existing version.

The Power BI report and its PBIP project are documented in [the Power BI project folder](../power-bi/nyc-taxi-analytics/README.md). See also the [architecture document](../docs/architecture.md).
