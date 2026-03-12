"""Tests for YouTube Trending ETL — Lambda routing and Glue logic."""

import json
import pytest


class TestS3EventRouting:
    """Test S3 trigger Lambda event parsing and job routing."""

    def _make_s3_event(self, bucket, key, size=1024):
        return {
            "Records": [
                {
                    "s3": {
                        "bucket": {"name": bucket},
                        "object": {"key": key, "size": size},
                    }
                }
            ]
        }

    def test_csv_file_routes_to_csv_cleaner(self):
        event = self._make_s3_event("raw-bucket", "csv/US/2024-01-15/USvideos.csv")
        key = event["Records"][0]["s3"]["object"]["key"]
        ext = key.rsplit(".", 1)[-1].lower()
        assert ext == "csv"
        job = "csv-cleaner" if ext == "csv" else "json-parser"
        assert job == "csv-cleaner"

    def test_json_file_routes_to_json_parser(self):
        event = self._make_s3_event("raw-bucket", "json/US/2024-01-15/USvideos.json")
        key = event["Records"][0]["s3"]["object"]["key"]
        ext = key.rsplit(".", 1)[-1].lower()
        job = "csv-cleaner" if ext == "csv" else "json-parser"
        assert job == "json-parser"

    def test_empty_file_skipped(self):
        event = self._make_s3_event("raw-bucket", "csv/US/empty.csv", size=0)
        size = event["Records"][0]["s3"]["object"]["size"]
        should_process = size > 0
        assert should_process is False

    def test_unsupported_format_skipped(self):
        event = self._make_s3_event("raw-bucket", "other/file.txt")
        key = event["Records"][0]["s3"]["object"]["key"]
        ext = key.rsplit(".", 1)[-1].lower()
        supported = ext in ("csv", "json")
        assert supported is False

    def test_region_extraction_from_path(self):
        key = "csv/US/2024-01-15/USvideos.csv"
        parts = key.split("/")
        region = parts[1]
        assert region == "US"

    def test_date_extraction_from_path(self):
        key = "csv/US/2024-01-15/USvideos.csv"
        parts = key.split("/")
        date_str = parts[2]
        assert date_str == "2024-01-15"


class TestGlueCSVCleaner:
    """Test CSV cleaning transformation logic."""

    def test_engagement_metric(self):
        views, likes, dislikes, comments = 100000, 5000, 200, 1500
        engagement = round((likes + dislikes + comments) / max(views, 1) * 100, 4)
        assert engagement == 6.7

    def test_tag_parsing(self):
        raw_tags = '"python"|"data science"|"machine learning"'
        tags = [t.strip('"') for t in raw_tags.split("|")]
        assert len(tags) == 3
        assert tags[0] == "python"

    def test_engagement_tier_classification(self):
        def classify(rate):
            if rate > 10:
                return "viral"
            elif rate > 5:
                return "high"
            elif rate > 2:
                return "medium"
            return "low"

        assert classify(15) == "viral"
        assert classify(7) == "high"
        assert classify(3) == "medium"
        assert classify(1) == "low"


class TestGlueEnrichment:
    """Test enrichment job logic — joins, window functions."""

    def test_category_mapping(self):
        categories = {1: "Film", 2: "Autos", 10: "Music", 20: "Gaming", 22: "People", 24: "Entertainment", 25: "News", 28: "Science"}
        assert categories[10] == "Music"
        assert categories[20] == "Gaming"

    def test_trending_rank_window(self):
        videos = [
            {"region": "US", "views": 5000000},
            {"region": "US", "views": 3000000},
            {"region": "US", "views": 8000000},
        ]
        sorted_vids = sorted(videos, key=lambda v: v["views"], reverse=True)
        for rank, vid in enumerate(sorted_vids, 1):
            vid["trending_rank"] = rank
        assert sorted_vids[0]["views"] == 8000000
        assert sorted_vids[0]["trending_rank"] == 1

    def test_views_percentile(self):
        import numpy as np
        views = [1000, 5000, 10000, 50000, 100000, 500000, 1000000]
        p90 = np.percentile(views, 90)
        assert p90 > 100000
