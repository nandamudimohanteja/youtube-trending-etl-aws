"""AWS Glue ETL Job 2: JSON Category Parsing + Flattening.

Reads YouTube category JSON files, flattens the nested structure,
and writes a clean category mapping table as Parquet.
"""

import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.types import (
    ArrayType,
    IntegerType,
    StringType,
    StructField,
    StructType,
    BooleanType,
)

args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "RAW_BUCKET", "PROCESSED_BUCKET", "GLUE_DATABASE"],
)

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

RAW_BUCKET = args["RAW_BUCKET"]
PROCESSED_BUCKET = args["PROCESSED_BUCKET"]


def parse_category_json():
    """Parse and flatten YouTube category JSON files."""

    # Read all JSON category files
    raw_path = f"s3://{RAW_BUCKET}/json/"
    print(f"Reading category JSON from: {raw_path}")

    df = spark.read.option("multiLine", "true").json(raw_path)

    print(f"Raw JSON schema:")
    df.printSchema()

    # Explode the categories array
    df_exploded = df.select(
        F.col("region"),
        F.explode("categories").alias("category"),
    )

    # Flatten category struct
    category_df = df_exploded.select(
        F.col("region"),
        F.col("category.category_id").cast(IntegerType()).alias("category_id"),
        F.col("category.category_title").alias("category_title"),
        F.col("category.assignable").cast(BooleanType()).alias("is_assignable"),
    )

    # Deduplicate (same category can appear in multiple regions)
    category_df = category_df.dropDuplicates(["region", "category_id"])

    # Add processing metadata
    category_df = category_df.withColumn("processed_at", F.current_timestamp())

    print(f"Parsed category count: {category_df.count()}")
    category_df.show(20)

    # Write to processed zone
    output_path = f"s3://{PROCESSED_BUCKET}/parquet/category_mapping/"
    print(f"Writing category mapping to: {output_path}")

    category_df.write.mode("overwrite").partitionBy("region").parquet(output_path)

    # Also create a global (non-region-specific) mapping
    global_categories = (
        category_df.groupBy("category_id", "category_title")
        .agg(
            F.collect_set("region").alias("available_regions"),
            F.max("is_assignable").alias("is_assignable"),
        )
        .withColumn("region_count", F.size("available_regions"))
        .withColumn("processed_at", F.current_timestamp())
    )

    global_output = f"s3://{PROCESSED_BUCKET}/parquet/global_categories/"
    global_categories.write.mode("overwrite").parquet(global_output)

    print("JSON parsing job complete!")


parse_category_json()
job.commit()
