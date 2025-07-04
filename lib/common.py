"""Common utility functions for S3 and local file operations in the cookbook.

This module provides shared utilities for handling logging configuration and file
operations that work seamlessly with both local files and S3 objects using smart_open.
"""

import logging
import os
from typing import Optional, List, Generator

import boto3
import smart_open


def extract_newspaper_id(content_item_id: str) -> str:
    """Extract newspaper ID from content item ID."""
    return content_item_id[0 : len(content_item_id) - 19]


def extract_year(content_item_id: str) -> str:
    """Extract year from content item ID."""
    return content_item_id[-18:-14]


def get_transport_params(filepath: str) -> dict:
    """Get transport parameters for S3 or local file access."""
    if filepath.startswith("s3://"):
        return {"client": get_s3_client()}
    return {}


def get_s3_client() -> "boto3.client":
    """Returns a boto3.client object for interacting with S3.

    Returns:
        boto3.client: A boto3.client object for interacting with S3.
    """

    boto3.setup_default_session(
        aws_access_key_id=os.getenv("SE_ACCESS_KEY"),
        aws_secret_access_key=os.getenv("SE_SECRET_KEY"),
    )

    return boto3.client(
        "s3", endpoint_url=os.getenv("SE_HOST_URL", "https://os.zhdk.cloud.switch.ch/")
    )


def yield_s3_objects(bucket: str, prefix: str) -> Generator[str, None, None]:
    """Yield all objects in an S3 bucket with a given prefix.

    Args:
        bucket (str): S3 bucket name.
        prefix (str): Prefix to filter objects.

    Yields:
        str: The key of each object.
    """
    s3 = get_s3_client()
    continuation_token = None
    count = 0
    while True:
        # List objects in the specified S3 bucket with the given prefix
        response = (
            s3.list_objects_v2(
                Bucket=bucket, Prefix=prefix, ContinuationToken=continuation_token
            )
            if continuation_token
            else s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
        )

        # Yield the 'Key' of each object from the response
        for content in response.get("Contents", []):
            count += 1
            yield content["Key"]

        # Check if there are more objects to retrieve
        if response.get(
            "IsTruncated"
        ):  # If the response is truncated, there are more objects to retrieve
            continuation_token = response.get("NextContinuationToken")
        else:
            break
    logging.info(f"Found {count} objects with prefix {prefix}")


def setup_logging(log_level: str, log_file: Optional[str], force: bool = False) -> None:
    """Configure logging with support for both console and file output.

    Sets up logging handlers for console output and optionally file output using
    smart_open for compatibility with both local files and S3 paths. The logging format
    includes timestamp, filename, line number, level, and message.

    Args:
        log_level (str): Logging level as a string (e.g., 'DEBUG', 'INFO', 'WARNING',
            'ERROR').
        log_file (Optional[str]): Path to the log file. Can be a local path or S3 URI.
            If None, only console logging is configured.
        force (bool, optional): If True, force reconfiguration of existing loggers.
            Defaults to False.

    Returns:
        None

    Example:
        >>> setup_logging('INFO', 'logs/app.log')
        >>> setup_logging('DEBUG', 's3://bucket/logs/debug.log', force=True)
    """

    class SmartFileHandler(logging.FileHandler):
        """Custom FileHandler that uses smart_open for file operations.

        This handler extends logging.FileHandler to support both local files
        and S3 URIs by using smart_open instead of the built-in open function.
        """

        def _open(self):
            """Open the file using smart_open for S3 and local file compatibility.

            Returns:
                file object: An opened file object that supports both local files
                    and S3 URIs.
            """
            return smart_open.open(self.baseFilename, self.mode, encoding="utf-8")

    handlers: List[logging.Handler] = [logging.StreamHandler()]
    if log_file:
        handlers.append(SmartFileHandler(log_file, mode="w"))

    logging.basicConfig(
        level=log_level,
        format="%(asctime)-15s %(filename)s:%(lineno)d %(levelname)s: %(message)s",
        handlers=handlers,
        force=force,
    )
