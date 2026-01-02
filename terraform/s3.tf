# ============================================
# S3 Buckets
# ============================================

# Raw landing zone
resource "aws_s3_bucket" "raw" {
  bucket = "${var.raw_bucket_name}-${var.environment}"
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Processed/Curated zone
resource "aws_s3_bucket" "processed" {
  bucket = "${var.processed_bucket_name}-${var.environment}"
}

resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket                  = aws_s3_bucket.processed.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Scripts bucket (Glue jobs)
resource "aws_s3_bucket" "scripts" {
  bucket = "${var.scripts_bucket_name}-${var.environment}"
}

resource "aws_s3_bucket_public_access_block" "scripts" {
  bucket                  = aws_s3_bucket.scripts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload Glue job scripts
resource "aws_s3_object" "csv_cleaner_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "glue_jobs/csv_cleaner.py"
  source = "${path.module}/../glue_jobs/csv_cleaner.py"
  etag   = filemd5("${path.module}/../glue_jobs/csv_cleaner.py")
}

resource "aws_s3_object" "json_parser_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "glue_jobs/json_parser.py"
  source = "${path.module}/../glue_jobs/json_parser.py"
  etag   = filemd5("${path.module}/../glue_jobs/json_parser.py")
}

resource "aws_s3_object" "enrichment_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "glue_jobs/enrichment_job.py"
  source = "${path.module}/../glue_jobs/enrichment_job.py"
  etag   = filemd5("${path.module}/../glue_jobs/enrichment_job.py")
}

# S3 event notification → Lambda
resource "aws_s3_bucket_notification" "raw_notification" {
  bucket = aws_s3_bucket.raw.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "csv/"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "json/"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
