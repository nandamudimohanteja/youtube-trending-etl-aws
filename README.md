# YouTube Trending Data ETL on AWS

![Python](https://img.shields.io/badge/Python-3.9+-blue?logo=python)
![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazonaws)
![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform)
![PySpark](https://img.shields.io/badge/PySpark-Glue-E25A1C?logo=apachespark)
![License](https://img.shields.io/badge/License-MIT-green)

A production-grade ETL pipeline on AWS that ingests YouTube trending video data (CSV + JSON), orchestrates multi-step transformations with AWS Glue, catalogs via Glue Crawler, provides SQL analytics through Athena, and visualizes with QuickSight dashboards. Infrastructure is fully managed via Terraform.


## Demo

![Project Demo](screenshots/project-demo.png)

*AWS infrastructure overview with Terraform resources, Glue workflow status, and Athena query results for top trending videos by region*

## Architecture

```
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” 
â”‚                        Data Sources                               â”‚
â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”     â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”   â”‚
â”‚  â”‚  Kaggle YouTube  â”‚    â”‚  YouTube Data API v3 (live refresh) â”‚  â”‚
â”‚  â”‚  Trending Datasetâ”‚    â”‚  (optional incremental)             â”‚  â”‚
â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”˜    â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”   â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
            â”‚                            â”‚
            â–¼                            â–¼
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” 
â”‚  S3 Landing Zone (Raw)                                           â”‚
â”‚  s3://youtube-etl-raw/                                           â”‚
â”‚  â”œâ”€â”€ csv/{region}/{date}/                                        â”‚
â”‚  â”œâ”€â”€ json/{region}/{date}/                                       â”‚
â”‚  â””â”€â”€ api/{date}/                                                 â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                         â”‚ S3 Event Notification
                         â–¼
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” 
â”‚  AWS Lambda (Trigger)                                             â”‚
â”‚  â€¢ Validates file format                                          â”‚
â”‚  â€¢ Starts Glue ETL Job                                           â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                         â”‚
                         â–¼
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” 
â”‚  AWS Glue ETL Jobs (PySpark)                                      â”‚
â”‚  â”œâ”€â”€ Job 1: CSV Cleaning + Schema Enforcement                    â”‚
â”‚  â”œâ”€â”€ Job 2: JSON Category Parsing + Flattening                   â”‚
â”‚  â””â”€â”€ Job 3: Join + Enrich â†’ Parquet (partitioned by date/region) â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                         â”‚
                         â–¼
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” 
â”‚  S3 Processed Zone (Curated)                                      â”‚
â”‚  s3://youtube-etl-processed/                                      â”‚
â”‚  â””â”€â”€ parquet/year={}/month={}/region={}/                          â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                         â”‚
                         â–¼
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” 
â”‚  AWS Glue Data Catalog                                            â”‚
â”‚  â”œâ”€â”€ Database: youtube_analytics                                  â”‚
â”‚  â”œâ”€â”€ Table: trending_videos (partitioned)                        â”‚
â”‚  â””â”€â”€ Table: category_mapping                                      â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                         â”‚
                    â”Œâ”€â”€â”€â”€â”´â”€â”€â”€â”€â” 
                    â–¼         â–¼
          â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”   â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â” 
          â”‚  Athena   â”‚  â”‚  QuickSight   â”‚
          â”‚  (SQL)    â”‚  â”‚  (Dashboard)  â”‚
          â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

## Key Business Insights

1.  **Regional Trending Patterns**: Analyze which video categories dominate across different countries and identify cross-cultural content trends.
2.  **Engagement Optimization**: Discover correlations between publishing time, title length, tags, and engagement metrics (views, likes, comments) to inform content strategy.

## Project Structure

```
â”œâ”€â”€ terraform/                      # Full AWS infrastructure as code
â”‚   â”œâ”€â”€ main.tf
â”‚   â”œâ”€â”€ variables.tf
â”‚   â”œâ”€â”€ outputs.tf
â”‚   â”œâ”€â”€ s3.tf
â”‚   â”œâ”€â”€ lambda.tf
â”‚   â”œâ”€â”€ glue.tf
â”‚   â”œâ”€â”€ athena.tf
â”‚   â””â”€â”€ iam.tf
â”œâ”€â”€ lambda_functions/
â”‚   â”œâ”€â”€ ingestion/                  # Data ingestion Lambda
â”‚   â”‚   â””â”€â”€ handler.py
â”‚   â””â”€â”€ trigger/                    # S3 event â†’ Glue trigger Lambda
â”‚       â””â”€â”€ handler.py
â”œâ”€â”€ glue_jobs/
â”‚   â”œâ”€â”€ csv_cleaner.py             # Job 1: CSV cleaning
â”‚   â”œâ”€â”€ json_parser.py            # Job 2: JSON flattening
â”‚   â””â”€â”€ enrichment_job.py         # Job 3: Join + Parquet output
â”œâ”€â”€ athena_queries/                 # Pre-built analytics queries
â”‚   â”œâ”€â”€ top_trending_by_region.sql
â”‚   â”œâ”€â”€ engagement_analysis.sql
â”‚   â””â”€â”€ category_trends.sql
â”œâ”€â”€ scripts/
â”‚   â”œâ”€â”€ upload_kaggle_data.py      # Download + upload Kaggle dataset
â”‚   â””â”€â”€ create_quicksight_dashboard.py
â”œâ”€â”€ tests/
â”‚   â”œâ”€â”€ test_glue_jobs.py
â”‚   â””â”€â”€ test_lambda.py
â”œâ”€â”€ .github/workflows/
â”‚   â””â”€â”€ deploy.yml
â””â”€â”€ requirements.txt
```

## Setup Instructions

### Prerequisites
- AWS Account with appropriate permissions
- Terraform >= 1.5
- Python 3.9+
- Kaggle API credentials (for dataset download)

### 1. Configure AWS Credentials
```bash
aws configure
# Or use environment variables:
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export AWS_DEFAULT_REGION=us-east-1
```

### 2. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Upload Kaggle Dataset
```bash
pip install -r requirements.txt
python scripts/upload_kaggle_data.py
```

### 4. Run Athena Queries
Navigate to Athena console â†’ select `youtube_analytics` database â†’ run queries from `athena_queries/`.



## Test Results

All unit tests pass â€” validating core business logic, data transformations, and edge cases.

![Test Results](screenshots/test-results.png)

**12 tests passed** across 3 test suites:
- `TestS3EventRouting` â€” CSV/JSON routing, empty file filtering, path parsing
- `TestGlueCSVCleaner` â€” engagement metrics, tag parsing, tier classification
- `TestGlueEnrichment` â€” category mapping, trending rank, views percentile

## License
MIT

## Maintainer

This project is actively maintained by Mohan Teja Nandamudi.

Mohan is a Data Engineer with 6+ years of experience building and optimizing enterprise data pipelines and cloud warehouses across AWS, Spark, and Python environments. He specializes in batch processing, streaming architecture, and CI/CD automation, ensuring robust and efficient data solutions.

-   **LinkedIn**: [Mohan Teja Nandamudi](https://www.linkedin.com/in/nmohant/)
-   **Email**: mohanteja.0117@gmail.com