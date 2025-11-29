# ============================================
# Athena Resources
# ============================================

resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.project_name}-athena-results-${var.environment}"
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket                  = aws_s3_bucket.athena_results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "expire-query-results"
    status = "Enabled"
    expiration {
      days = 7
    }
  }
}

resource "aws_athena_workgroup" "youtube" {
  name = "${var.project_name}-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.id}/results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }
  }
}

# Named queries for common analytics
resource "aws_athena_named_query" "top_trending" {
  name        = "top-trending-by-region"
  workgroup   = aws_athena_workgroup.youtube.name
  database    = var.glue_database_name
  description = "Top 10 trending videos by region"
  query       = file("${path.module}/../athena_queries/top_trending_by_region.sql")
}

resource "aws_athena_named_query" "engagement" {
  name        = "engagement-analysis"
  workgroup   = aws_athena_workgroup.youtube.name
  database    = var.glue_database_name
  description = "Video engagement analysis"
  query       = file("${path.module}/../athena_queries/engagement_analysis.sql")
}
