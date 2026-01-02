# ============================================
# AWS Glue Resources
# ============================================

# Glue Data Catalog Database
resource "aws_glue_catalog_database" "youtube" {
  name        = var.glue_database_name
  description = "YouTube trending video analytics database"
}

# --- Glue Crawler ---
resource "aws_glue_crawler" "processed_data" {
  database_name = aws_glue_catalog_database.youtube.name
  name          = "${var.project_name}-processed-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.processed.id}/parquet/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  schedule = "cron(0 7 * * ? *)" # Run after daily ETL
}

# --- Glue ETL Jobs ---
resource "aws_glue_job" "csv_cleaner" {
  name     = "${var.project_name}-csv-cleaner"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.id}/glue_jobs/csv_cleaner.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"               = "python"
    "--job-bookmark-option"        = "job-bookmark-enable"
    "--enable-metrics"             = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--RAW_BUCKET"                 = aws_s3_bucket.raw.id
    "--PROCESSED_BUCKET"           = aws_s3_bucket.processed.id
    "--GLUE_DATABASE"              = aws_glue_catalog_database.youtube.name
  }

  glue_version      = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"
  timeout           = 60
  max_retries       = 1

  execution_property {
    max_concurrent_runs = 1
  }
}

resource "aws_glue_job" "json_parser" {
  name     = "${var.project_name}-json-parser"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.id}/glue_jobs/json_parser.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"               = "python"
    "--job-bookmark-option"        = "job-bookmark-enable"
    "--enable-metrics"             = "true"
    "--RAW_BUCKET"                 = aws_s3_bucket.raw.id
    "--PROCESSED_BUCKET"           = aws_s3_bucket.processed.id
    "--GLUE_DATABASE"              = aws_glue_catalog_database.youtube.name
  }

  glue_version      = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"
  timeout           = 30
  max_retries       = 1
}

resource "aws_glue_job" "enrichment" {
  name     = "${var.project_name}-enrichment"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.id}/glue_jobs/enrichment_job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"               = "python"
    "--job-bookmark-option"        = "job-bookmark-enable"
    "--enable-metrics"             = "true"
    "--RAW_BUCKET"                 = aws_s3_bucket.raw.id
    "--PROCESSED_BUCKET"           = aws_s3_bucket.processed.id
    "--GLUE_DATABASE"              = aws_glue_catalog_database.youtube.name
  }

  glue_version      = "4.0"
  number_of_workers = 4
  worker_type       = "G.1X"
  timeout           = 120
  max_retries       = 1
}

# --- Glue Workflow (orchestration) ---
resource "aws_glue_workflow" "etl_pipeline" {
  name        = "${var.project_name}-etl-workflow"
  description = "YouTube ETL pipeline: CSV clean → JSON parse → Enrich → Crawl"
}

resource "aws_glue_trigger" "start" {
  name          = "${var.project_name}-start-trigger"
  type          = "SCHEDULED"
  schedule      = "cron(0 6 * * ? *)"
  workflow_name = aws_glue_workflow.etl_pipeline.name

  actions {
    job_name = aws_glue_job.csv_cleaner.name
  }

  actions {
    job_name = aws_glue_job.json_parser.name
  }
}

resource "aws_glue_trigger" "enrichment_trigger" {
  name          = "${var.project_name}-enrichment-trigger"
  type          = "CONDITIONAL"
  workflow_name = aws_glue_workflow.etl_pipeline.name

  predicate {
    logical = "AND"
    conditions {
      job_name = aws_glue_job.csv_cleaner.name
      state    = "SUCCEEDED"
    }
    conditions {
      job_name = aws_glue_job.json_parser.name
      state    = "SUCCEEDED"
    }
  }

  actions {
    job_name = aws_glue_job.enrichment.name
  }
}

resource "aws_glue_trigger" "crawler_trigger" {
  name          = "${var.project_name}-crawler-trigger"
  type          = "CONDITIONAL"
  workflow_name = aws_glue_workflow.etl_pipeline.name

  predicate {
    conditions {
      job_name = aws_glue_job.enrichment.name
      state    = "SUCCEEDED"
    }
  }

  actions {
    crawler_name = aws_glue_crawler.processed_data.name
  }
}
