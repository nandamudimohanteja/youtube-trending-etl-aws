output "raw_bucket_name" {
  value = aws_s3_bucket.raw.id
}

output "processed_bucket_name" {
  value = aws_s3_bucket.processed.id
}

output "glue_database_name" {
  value = aws_glue_catalog_database.youtube.name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.youtube.name
}

output "trigger_lambda_arn" {
  value = aws_lambda_function.s3_trigger.arn
}

output "ingestion_lambda_arn" {
  value = aws_lambda_function.ingestion.arn
}
