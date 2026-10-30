# NYC Taxi Analytics

This folder is reserved for the unpacked Power BI Project (PBIP) source for the NYC Taxi Analytics report.

## Report pages

### NYC Taxi Analytics Overview

The overview page focuses on operational and financial performance:
- Total Trips
- Fare Revenue
- Average Distance
- Average Duration
- Average Fare per Trip
- Tip Rate
- Previous-period comparisons where configured
- Trip and revenue trends
- Payment-type distribution
- Date filtering

### Data Quality

The Data Quality page focuses on dataset quality and investigation:
- Issue counts and percentages by rule
- NULL counts and percentages across selected columns
- Rows where multiple nullable fields are simultaneously null
- Negative financial values
- Zero-distance and zero-duration trips
- Long-duration trips
- Supporting quality context and interpretation

The report uses the Gold and Data Quality Direct Lake semantic models for their respective analytical purposes.

## Current repository state

The parent `power-bi/` folder contains `NYC Taxi Analytics.rar`, a compressed report package. The separate `Semantic Models/` folder contains `NYC Taxi Analytics.SemanticModel.rar`.

This directory currently contains documentation only. The complete unpacked PBIP project has not yet been committed here. When exported, commit the full project structure together:
- The `.pbip` entry file
- The associated `.Report/` folder
- The associated `.SemanticModel/` folder
- All required definition and metadata files

Do not commit local cache, temporary, credential, or machine-specific files. Keep the extracted source synchronized with the current report and semantic model.

See [the architecture document](../../docs/architecture.md) for the model design, data lineage, current validation results, and limitations.
