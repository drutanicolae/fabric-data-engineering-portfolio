# NYC Yellow Taxi Data Engineering Project

## 1. Why I built this project

This project started as a practical way to explore Microsoft Fabric beyond the usual reporting workflow. I wanted to work with a real dataset, process it at scale, make deliberate decisions about data quality, and build a model that could eventually support meaningful business analysis in Power BI.

The dataset comes from New York City's Yellow Taxi trip records for January 2025. It contains millions of trips and enough inconsistencies to make the project more interesting than simply loading data and creating a few charts.

The goal is to build an end-to-end workflow using Microsoft Fabric, PySpark, Delta tables, Dataflow Gen2, dimensional modeling, and Power BI. The project is being developed incrementally, with the code, architecture, and design decisions documented in GitHub.

## 2. Technology and environment

The project currently uses:

- **Microsoft Fabric** for the data engineering and analytics environment.
- **Fabric Lakehouse** for storing source files and curated Delta tables.
- **PySpark** for ingestion, transformations, data validation, and fact table creation.
- **Delta Lake** for the Silver and Gold tables.
- **Dataflow Gen2 and Power Query M** for creating and transforming dimension tables.
- **Direct Lake semantic model** for connecting the Gold tables to Power BI.
- **Git and GitHub** for version control and project documentation.

The Fabric workspace is `Nicu-Data-Engineering-Lab`, running on a Fabric trial. The Lakehouse is named `lh_nyc_taxi`.

The source notebook is `nb_ingest_nyc_taxi`, and the semantic model is `sm_nyc_taxi_gold`.

The project source code and documentation are maintained in the `fabric-data-engineering-portfolio` GitHub repository.

## 3. Data source

The project uses the publicly available NYC Yellow Taxi trip record dataset for January 2025.

- Official TLC data page: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- January 2025 Parquet file: https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2025-01.parquet
- Taxi zone lookup: https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv

The trip records contain information such as pickup and drop-off timestamps, locations, vendor identifiers, passenger counts, trip distances, payment types, fares, tips, and other charges.

The zone lookup provides the borough, zone name, and service zone associated with each taxi location identifier.

For the initial version, I deliberately limited the scope to one month. This makes it possible to validate the entire workflow before expanding it to additional months and implementing a repeatable update process.

## 4. Architecture: Bronze, Silver, and Gold

The Lakehouse follows a layered architecture. Each layer has a different purpose, rather than treating every transformation as part of one large query.

### Bronze: raw source data

The original January 2025 trip data is stored as a Parquet file at:

`Files/bronze/yellow_tripdata_2025-01.parquet`

The taxi zone lookup is stored separately at:

`Files/reference/taxi_zone_lookup.csv`

The raw trip file is retained as the starting point for downstream processing. Keeping the source separate from cleaned data makes it easier to investigate unexpected results and compare transformations with the original records.

### Silver: cleaned trip records

The notebook reads the Bronze Parquet file with PySpark and creates the `yellow_taxi_silver` Delta table.

The initial source contained 3,475,226 records. I identified and excluded 124 records where the drop-off timestamp was earlier than the pickup timestamp.

The resulting Silver table contains **3,475,102 records across 20 columns**.

This filtering rule addresses a clear chronological inconsistency without removing records simply because their financial values look unusual.

Silver is the cleaned trip-level dataset used by the downstream Gold transformations.

### Gold: analytics-ready tables

The Gold layer separates trip-level facts from descriptive dimensions.

| Table | Purpose | Current row count |
|---|---|---:|
| `FactTaxiTrips` | Trip-level facts and numeric measures | 3,475,102 |
| `DimTaxiZone` | Taxi location, borough, and zone descriptions | 265 |
| `DimVendor` | Vendor identifiers and descriptive attributes | 4 |
| `DimPaymentType` | Payment codes and analyst-defined classifications | 6 |
| `DimDate` | Calendar attributes for date-based analysis | 366 |

`FactTaxiTrips` and `DimTaxiZone` are generated in the PySpark notebook. The other three dimensions are created through Dataflow Gen2, using Power Query M.

The date dimension covers December 31, 2024, through December 31, 2025. The extra day at the beginning is intentional: some trips in the January dataset started on December 31 and continued into January.

The Gold tables are the intended source for the semantic model, rather than the raw files or intermediate Silver table.

## 5. Dataflow Gen2 and dimension design

Dataflow Gen2 is used to create reusable dimension tables from the Silver data and to maintain the transformation logic separately from the main PySpark notebook.

### DimVendor

The vendor dimension is derived from the distinct vendor identifiers present in Silver. It currently contains four vendors:

- Vendor 1: Creative Mobile Technologies, LLC
- Vendor 2: Curb Mobility, LLC
- Vendor 6: Myle Technologies Inc
- Vendor 7: Helix

The dimension also contains descriptive text identifying the records as TPEP providers identified by NYC TLC. These descriptions are portfolio documentation, not official TLC descriptions of each vendor's role.

### DimPaymentType

The payment dimension contains the six payment codes found in the source, from 0 to 5.

In addition to the original payment code, I added three descriptive attributes:

- `PaymentTypeName`
- `PaymentCategory`
- `IsStandardPayment`

The names map the source codes to readable labels, including credit card, cash, no charge, dispute, unknown, and unspecified or missing.

The category groups payment types into broader analytical categories. The standard-payment flag identifies credit card and cash transactions.

These categories and the standard-payment flag are analyst-defined classifications. They should not be interpreted as official TLC business rules.

### DimDate

The date dimension is generated using Power Query M and includes a date key in `yyyyMMdd` integer format.

It provides the basis for calendar-based analysis and will be extended with additional attributes, such as month names and day-of-week labels, for reporting.

The model still needs its final date-related design, including how pickup and drop-off dates will be handled separately.

## 6. Data quality: what the data actually looks like

An important part of the project has been investigating the source data rather than assuming every record represents a normal, completed taxi trip.

The initial profiling identified several patterns worth documenting.

### Missing values

Approximately 540,031 records contain null values simultaneously in the following five columns:

- `passenger_count`
- `RatecodeID`
- `store_and_fwd_flag`
- `congestion_surcharge`
- `Airport_fee`

Because these missing values occur together, I have not automatically replaced them with zero or removed the affected records. Doing so could change the meaning of the data without sufficient evidence.

### Negative financial amounts

The dataset contains approximately:

- 144,118 records with negative fares.
- 63,037 records with negative total amounts.
- 124 records with negative tips.

Negative values require investigation, but they are not automatically proof of bad data. Some may represent reversals or adjustments, although that interpretation has not yet been confirmed.

The negative fares total approximately -$1.68 million, while negative total amounts sum to approximately -$1.66 million.

### Zero distances and unusual durations

The profiling also identified:

- 90,893 records with zero trip distance.
- 1,927 trips with zero calculated duration.
- 1,377 trips lasting more than three hours.
- A maximum observed duration of approximately 93.8 hours.

The three-hour threshold is an investigation threshold used during profiling, not an official business rule.

These records have been retained for investigation rather than excluded through arbitrary thresholds.

### Potential reversals or adjustments

A further investigation found 59,294 groups of records with both positive and negative fares. Of these, 59,291 groups contained exactly two records with opposite fare signs.

Some examples share the same pickup and drop-off timestamps and trip distances while showing opposite financial amounts. This pattern could indicate reversals or adjustments, but the available evidence does not establish that interpretation conclusively.

For that reason, I have not removed these records or treated them as confirmed duplicates.

There were no exact duplicate records identified in the Silver dataset.

### Overall approach

The data quality strategy is conservative: remove records only when a clear rule supports doing so, document anomalies, and avoid silently changing financial values.

This keeps the processing decisions transparent and makes the remaining issues available for further analysis in Power BI.

## 7. Semantic model

The semantic model, `sm_nyc_taxi_gold`, uses the Gold tables and the Direct Lake storage mode.

The current model contains active, one-to-many relationships with single-direction filtering:

| Dimension | Dimension key | Fact key |
|---|---|---|
| `DimVendor` | `VendorID` | `FactTaxiTrips[VendorID]` |
| `DimPaymentType` | `payment_type` | `FactTaxiTrips[payment_type]` |
| `DimTaxiZone` | `LocationID` | `FactTaxiTrips[PULocationID]` |
| `DimDate` | `DateKey` | `FactTaxiTrips[PickupDateKey]` |

The pickup date and pickup location relationships are the active paths in the current model.

The fact table also contains drop-off dates and locations. Their relationships and role-playing dimension design still need to be completed. This will allow pickup and drop-off analysis without introducing ambiguous filter paths.

### Key integrity

I checked the fact table keys against their corresponding dimensions. All six checks returned zero unmatched keys:

- Vendor identifiers.
- Payment type codes.
- Pickup location identifiers.
- Drop-off location identifiers.
- Pickup date keys.
- Drop-off date keys.

These checks provide confidence that the current fact records can be matched to the relevant dimension records.

## 8. Business and design decisions

Several decisions have shaped the project so far.

**Start with one month of data.** January 2025 is the initial scope. The priority was to build and validate the complete processing path before expanding the dataset.

**Keep raw data separate from curated tables.** Bronze preserves the source, Silver applies basic cleaning, and Gold prepares the data for analytical use.

**Use PySpark for the large trip dataset.** The trip records are processed in Fabric rather than being manually reshaped in Excel.

**Use Dataflow Gen2 for selected dimensions.** This separates Power Query transformations from the main notebook and makes the dimension logic easier to inspect.

**Build a dimensional model.** A central fact table with descriptive dimensions provides a cleaner foundation for reusable DAX measures and multiple reports.

**Do not automatically discard financial anomalies.** Negative fares, zero distances, missing values, and unusual durations are documented for investigation rather than removed without evidence.

**Separate source attributes from analytical classifications.** Payment categories and the standard-payment flag are explicitly identified as analyst-defined logic.

**Keep the implementation reproducible.** Notebook code, Power Query scripts, and architecture documentation are version-controlled in GitHub.

## 9. Current implementation status

The following components have been implemented:

- Loaded the January 2025 Parquet dataset into Bronze.
- Stored the taxi zone lookup in the Lakehouse.
- Created the Silver Delta table and applied the initial timestamp validation rule.
- Created the Gold fact table and taxi zone dimension.
- Created vendor, payment type, and date dimensions using Dataflow Gen2.
- Created a Direct Lake semantic model from the Gold tables.
- Established the current active relationships.
- Validated fact-to-dimension key integrity.
- Investigated key data quality patterns.
- Exported the ingestion notebook and selected Power Query M scripts to GitHub.

The repository currently contains the exported notebook and dimension scripts. The architecture document is being added to make the implementation and its design decisions easier to understand.

## 10. Next steps: refresh and data updates

The initial data engineering workflow is in place, but the update process is not yet automated.

The next stage is to make the project repeatable, so that future data can be processed without manually rebuilding the entire workflow.

Planned work includes:

1. **Design a repeatable ingestion process.** Establish how new monthly Parquet files will be discovered, downloaded, and stored in Bronze.
2. **Configure orchestration and scheduled execution.** Determine which steps should run in sequence and configure a Fabric schedule where supported by the current trial and item configuration.
3. **Define refresh dependencies.** Ensure ingestion completes before Silver and Gold transformations, dimension updates, and downstream model availability.
4. **Make processing safe to rerun.** Avoid duplicate records if a monthly file is processed more than once. Define how existing months will be handled if source files change.
5. **Validate each update.** Record row counts, rejected records, missing keys, and other quality checks after processing.
6. **Complete the semantic model.** Add the drop-off date and location analysis paths and implement the required DAX measures.
7. **Build the Power BI reports.** Create separate views for data quality and profiling, and for operational and financial analysis.
8. **Document the refresh strategy.** Record the schedule, dependencies, failure handling, and the process for adding new months.

The refresh schedule and automated data update process have **not been configured yet**. They are the next implementation milestone, not completed features.

## 11. Planned reporting

The project is intended to support two complementary Power BI reports.

### Data Quality and Profiling

This report will focus on record counts, missing values, negative financial amounts, unusual trip durations, zero distances, and the results of the validation rules.

### Operations and Finance

This report will focus on trip volumes, pickup and drop-off patterns, vendor activity, payment methods, trip distance, duration, fares, tips, and total amounts.

The reports will be built on the same semantic model, with reusable measures and consistent definitions.

## 12. Repository structure

The project source is maintained in GitHub:

```text
fabric-data-engineering-portfolio/
├── README.md
└── project-01-fabric-data-engineering/
    ├── notebooks/
    │   └── nb_ingest_nyc_taxi.ipynb
    ├── sql/
    │   ├── dim_payment_type.pq
    │   ├── dim_vendor.pq
    │   └── dim_date.pq
    └── docs/
        └── architecture.md
```

The `.pq` files contain Power Query M code, despite being stored in a folder currently named `sql`. That folder name can be revisited as the repository grows.

## Final note

This is an evolving project, not a claim that every part of a production data platform is already complete. The first milestone was to get real data through a layered architecture, investigate its quality, and create an analytical model.

The next milestone is to automate the process of keeping that model up to date and then build reports on top of it. The goal is to show not only the final result, but also the technical decisions and trade-offs behind it.
