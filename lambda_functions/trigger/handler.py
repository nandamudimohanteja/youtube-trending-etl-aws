"""S3 Event Trigger Lambda.

Triggered when new files land in the raw S3 bucket.
Validates the file format and starts the appropriate Glue ETL job.
"""

import json
import logging
import os
import urllib.parse

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

glue_client = boto3.client("glue")

CSV_CLEANER_JOB = os.environ["CSV_CLEANER_JOB"]
JSON_PARSER_JOB = os.environ["JSON_PARSER_JOB"]
PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]


def lambda_handler(event, context):
    """Handle S3 event notifications and trigger Glue jobs.

    Routes CSV files to the CSV cleaner job and JSON files to the JSON parser job.
    Includes file validation before triggering.
    """
    logger.info("Received event: %s", json.dumps(event))

    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        size = record["s3"]["object"].get("size", 0)

        logger.info("Processing file: s3://%s/%s (size: %d bytes)", bucket, key, size)

        # Validate file size (skip empty files)
        if size == 0:
            logger.warning("Skipping empty file: %s", key)
            continue

        # Route to appropriate Glue job
        if key.startswith("csv/") and key.endswith(".csv"):
            job_name = CSV_CLEANER_JOB
            file_type = "csv"
        elif key.startswith("json/") and key.endswith(".json"):
            job_name = JSON_PARSER_JOB
            file_type = "json"
        else:
            logger.warning("Unsupported file path/format: %s", key)
            continue

        # Extract region and date from key pattern: {type}/{region}/{date}/filename
        parts = key.split("/")
        region = parts[1] if len(parts) > 2 else "unknown"
        date_str = parts[2] if len(parts) > 3 else "unknown"

        # Start Glue job
        try:
            response = glue_client.start_job_run(
                JobName=job_name,
                Arguments={
                    "--SOURCE_BUCKET": bucket,
                    "--SOURCE_KEY": key,
                    "--FILE_TYPE": file_type,
                    "--REGION": region,
                    "--DATE": date_str,
                    "--PROCESSED_BUCKET": PROCESSED_BUCKET,
                },
            )
            run_id = response["JobRunId"]
            logger.info(
                "Started Glue job %s (run: %s) for file: %s",
                job_name,
                run_id,
                key,
            )
        except glue_client.exceptions.ConcurrentRunsExceededException:
            logger.warning(
                "Glue job %s already running, skipping file: %s", job_name, key
            )
        except Exception as e:
            logger.error("Failed to start Glue job %s: %s", job_name, str(e))
            raise

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "Trigger processing complete"}),
    }
