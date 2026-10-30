# NYC Taxi Analytics

This folder documents the NYC Taxi Analytics Power BI Project (PBIP) deliverable. The complete PBIP package is stored as a RAR archive in the parent `power-bi/` directory.

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

The parent `power-bi/` folder contains `NYC Taxi Analytics.rar`, which packages the complete PBIP project, including both report and semantic-model components. The separate `Semantic Models/` folder also retains `NYC Taxi Analytics.SemanticModel.rar` as a standalone semantic-model export.

The RAR archive is the uploaded PBIP deliverable. This directory currently contains documentation rather than the extracted project files. GitHub cannot show or diff the files inside a RAR archive. For easier review and source history, the extracted project can additionally be committed with:
- The `.pbip` entry file
- The associated `.Report/` folder
- The associated `.SemanticModel/` folder
- All required definition and metadata files

Do not commit local cache, temporary, credential, or machine-specific files. Keep the archive and any extracted source synchronized with the current report and semantic model.

See [the architecture document](../../docs/architecture.md) for the model design, data lineage, current validation results, and limitations.
