# Data Engineering & Analytics Portfolio

A hands-on portfolio showcasing data engineering, analytics, and business application projects built with Microsoft technologies and public datasets.

## Core Technologies

- Microsoft Fabric
- PySpark and Python
- Lakehouse architecture and Delta tables
- Dataflow Gen2 and Power Query
- Dimensional data modeling
- SQL and DAX
- Power BI
- Power Apps and Power Automate

## Projects

### Project 01: NYC Yellow Taxi Data Engineering

An end-to-end data engineering project using the publicly available NYC Yellow Taxi trip dataset for January 2025.

**Technologies:** Microsoft Fabric, PySpark, Delta Lake, Dataflow Gen2, Direct Lake semantic models, Power BI.

**Implemented so far:**
- Ingested the source Parquet dataset into the Bronze layer.
- Created a Silver Delta table with basic data quality filtering.
- Built a Gold fact table and dimension tables.
- Processed 3,475,102 valid trip records in the Silver layer.
- Created dimensions for vendors, payment types, taxi zones, and dates.
- Built a Direct Lake semantic model with relationships between the fact and dimension tables.
- Investigated data quality issues, including negative fares, missing values, and unusual trip durations.

**Next steps:**
- Complete semantic model design and DAX measures.
- Build Power BI reports for operations, financial analysis, and data quality.
- Document data lineage, transformation logic, and design decisions.
- Publish project documentation and source code.

Project details: [`project-01-fabric-data-engineering`](project-01-fabric-data-engineering/)

## About

This portfolio documents practical implementation of data engineering and analytics solutions using public datasets and Microsoft technologies. The focus is on reproducible workflows, data quality, dimensional modeling, and turning raw data into useful business insights.