variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "youtube-etl"
}

variable "raw_bucket_name" {
  description = "S3 bucket for raw landing zone"
  type        = string
  default     = "youtube-etl-raw"
}

variable "processed_bucket_name" {
  description = "S3 bucket for processed/curated data"
  type        = string
  default     = "youtube-etl-processed"
}

variable "scripts_bucket_name" {
  description = "S3 bucket for Glue job scripts"
  type        = string
  default     = "youtube-etl-scripts"
}

variable "glue_database_name" {
  description = "Glue Data Catalog database name"
  type        = string
  default     = "youtube_analytics"
}
