# ============================================
# Lambda Functions
# ============================================

data "archive_file" "trigger_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/trigger"
  output_path = "${path.module}/builds/trigger_lambda.zip"
}

data "archive_file" "ingestion_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/ingestion"
  output_path = "${path.module}/builds/ingestion_lambda.zip"
}

# S3 Event Trigger Lambda
resource "aws_lambda_function" "s3_trigger" {
  filename         = data.archive_file.trigger_lambda.output_path
  function_name    = "${var.project_name}-s3-trigger-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 128
  source_code_hash = data.archive_file.trigger_lambda.output_base64sha256

  environment {
    variables = {
      CSV_CLEANER_JOB   = aws_glue_job.csv_cleaner.name
      JSON_PARSER_JOB   = aws_glue_job.json_parser.name
      ENRICHMENT_JOB    = aws_glue_job.enrichment.name
      PROCESSED_BUCKET  = aws_s3_bucket.processed.id
      ENVIRONMENT       = var.environment
    }
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw.arn
}

# Data Ingestion Lambda (scheduled)
resource "aws_lambda_function" "ingestion" {
  filename         = data.archive_file.ingestion_lambda.output_path
  function_name    = "${var.project_name}-ingestion-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 300
  memory_size      = 512
  source_code_hash = data.archive_file.ingestion_lambda.output_base64sha256

  environment {
    variables = {
      RAW_BUCKET  = aws_s3_bucket.raw.id
      ENVIRONMENT = var.environment
    }
  }
}

# EventBridge rule for scheduled ingestion
resource "aws_cloudwatch_event_rule" "daily_ingestion" {
  name                = "${var.project_name}-daily-ingestion"
  description         = "Trigger daily YouTube data ingestion"
  schedule_expression = "cron(0 5 * * ? *)" # 5 AM UTC
}

resource "aws_cloudwatch_event_target" "ingestion_target" {
  rule      = aws_cloudwatch_event_rule.daily_ingestion.name
  target_id = "ingestion-lambda"
  arn       = aws_lambda_function.ingestion.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_ingestion.arn
}
