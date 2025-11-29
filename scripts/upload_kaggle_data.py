"""Download YouTube Trending dataset from Kaggle and upload to S3.

Prerequisites:
    pip install kaggle boto3
    Set KAGGLE_USERNAME and KAGGLE_KEY environment variables
"""

import os
import glob
import zipfile
import shutil
from pathlib import Path

import boto3
from dotenv import load_dotenv

load_dotenv()

KAGGLE_DATASET = "datasnaek/youtube-new"
RAW_BUCKET = os.environ.get("RAW_BUCKET", "youtube-etl-raw-dev")
DOWNLOAD_DIR = Path("./tmp_kaggle_download")
AWS_REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")


def download_dataset():
    """Download dataset from Kaggle."""
    print(f"Downloading {KAGGLE_DATASET} from Kaggle...")

    DOWNLOAD_DIR.mkdir(exist_ok=True)

    # Using kaggle CLI via subprocess for reliability
    import subprocess

    subprocess.run(
        [
            "kaggle",
            "datasets",
            "download",
            "-d",
            KAGGLE_DATASET,
            "-p",
            str(DOWNLOAD_DIR),
        ],
        check=True,
    )

    # Extract zip
    zip_files = list(DOWNLOAD_DIR.glob("*.zip"))
    for zf in zip_files:
        print(f"Extracting {zf.name}...")
        with zipfile.ZipFile(zf, "r") as z:
            z.extractall(DOWNLOAD_DIR)
        zf.unlink()

    print(f"Downloaded files: {list(DOWNLOAD_DIR.iterdir())}")


def upload_to_s3():
    """Upload downloaded files to S3 staging area."""
    s3 = boto3.client("s3", region_name=AWS_REGION)

    # Upload CSV files
    csv_files = list(DOWNLOAD_DIR.glob("*.csv"))
    for csv_file in csv_files:
        # Extract region from filename (e.g., USvideos.csv → US)
        region = csv_file.stem.replace("videos", "")
        s3_key = f"staging/{region}videos.csv"

        print(f"Uploading {csv_file.name} → s3://{RAW_BUCKET}/{s3_key}")
        s3.upload_file(str(csv_file), RAW_BUCKET, s3_key)

    # Upload JSON files
    json_files = list(DOWNLOAD_DIR.glob("*.json"))
    for json_file in json_files:
        region = json_file.stem.split("_")[0]
        s3_key = f"staging/{json_file.name}"

        print(f"Uploading {json_file.name} → s3://{RAW_BUCKET}/{s3_key}")
        s3.upload_file(str(json_file), RAW_BUCKET, s3_key)

    print(f"\nUploaded {len(csv_files)} CSV + {len(json_files)} JSON files to s3://{RAW_BUCKET}/staging/")


def cleanup():
    """Remove temp download directory."""
    if DOWNLOAD_DIR.exists():
        shutil.rmtree(DOWNLOAD_DIR)
        print("Cleaned up temporary files.")


if __name__ == "__main__":
    try:
        download_dataset()
        upload_to_s3()
    finally:
        cleanup()

    print("\nDone! Trigger the ingestion Lambda or wait for the scheduled run.")
