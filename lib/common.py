"""Common utility functions for S3 and local file operations in the cookbook.

This module provides shared utilities for handling logging configuration and file
operations that work seamlessly with both local files and S3 objects using smart_open.
"""

import datetime
import hashlib
import json
import logging
import os
import sys
import time
import traceback
from typing import Optional, List, Generator, Tuple, Any, Dict

import boto3

import smart_open

# Set up module logger
log = logging.getLogger(__name__)


def extract_newspaper_id(content_item_id: str) -> str:
    """Extract newspaper ID from content item ID."""
    return content_item_id[0 : len(content_item_id) - 19]


def extract_year(content_item_id: str) -> str:
    """Extract year from content item ID."""
    return content_item_id[-18:-14]


def get_transport_params(filepath: str) -> Dict[str, Any]:
    """Get transport parameters for S3 or local file access."""
    if filepath.startswith("s3://"):
        return {"client": get_s3_client()}
    return {}


def get_timestamp() -> str:
    """
    Generates a timestamp in a specific format.

    Returns:
        str: The generated timestamp.

    Example:
        >>> len(get_timestamp()) == 20
        True
    """
    timestamp = datetime.datetime.now(datetime.timezone.utc)

    return timestamp.strftime("%Y-%m-%dT%H:%M:%SZ")


def get_s3_client() -> Any:  # "boto3.client":
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


def parse_s3_path(s3_path: str) -> Tuple[str, str]:
    """
    Parses an S3 path into a bucket name and prefix.

    Args:
        s3_path (str): The S3 path to parse.

    Returns:
        Tuple[str, str]: The bucket name and prefix.

    Raises:
        ValueError: If the S3 path does not start with "s3://" or if it does not include
        both a bucket name and prefix.

    >>> parse_s3_path("s3://mybucket/myfolder/myfile.txt")
    ('mybucket', 'myfolder/myfile.txt')

    >>> parse_s3_path("s3://mybucket/myfolder/subfolder/")
    ('mybucket', 'myfolder/subfolder/')

    >>> parse_s3_path("not-an-s3-path")
    Traceback (most recent call last):
    ...
    ValueError: S3 path must start with s3://
    """
    if not s3_path.startswith("s3://"):
        raise ValueError("S3 path must start with s3://: %s", s3_path)
    path_parts = s3_path[5:].split("/", 1)
    if len(path_parts) < 2:
        raise ValueError("S3 path must include both bucket name and prefix")
    return path_parts[0], path_parts[1]


def s3_file_exists(s3_client, bucket_or_path: str, key: Optional[str] = None) -> bool:
    """
    Check if a file exists in an S3 bucket.

    Args:
        s3_client: The boto3 S3 client.
        bucket_or_path (str): The name of the S3 bucket or the full S3 path.
        key (str, optional): The key of the file in the S3 bucket.
            Required if bucket_or_path is a bucket name.

    Returns:
        bool: True if the file exists, False otherwise.
    """
    if key is None:
        # Assume bucket_or_path is a full S3 path
        if not bucket_or_path.startswith("s3://"):
            raise ValueError("Invalid S3 path")
        bucket, key = parse_s3_path(bucket_or_path)
    else:
        # Assume bucket_or_path is a bucket name
        bucket = bucket_or_path

    try:
        s3_client.head_object(Bucket=bucket, Key=key)
        return True
    except s3_client.exceptions.ClientError as e:
        if e.response["Error"]["Code"] == "404":
            return False
        else:
            raise


def upload_file_to_s3(
    s3_client, local_file_path: str, s3_path: str, force_overwrite: bool = False
) -> None:
    """Uploads a local file to an S3 bucket and verifies the upload.

    Args:
        s3_client: The boto3 S3 client.
        local_file_path (str): The path to the local file to upload.
        s3_path (str): The destination S3 path.
        force_overwrite (bool): Whether to overwrite the file on S3 if it already exists.
    """
    if not s3_path.startswith("s3://"):
        log.error("The s3_path must start with 's3://'.")
        sys.exit(1)
    bucket, key = parse_s3_path(s3_path)
    if not force_overwrite and s3_file_exists(s3_client, bucket, key):
        log.warning(f"The file s3://{bucket}/{key} already exists. Skipping upload.")
        return

    try:
        # Calculate the MD5 checksum of the local file
        local_md5 = calculate_md5(local_file_path)
        log.info(f"MD5 checksum of local file {local_file_path}: {local_md5}")

        # Upload the file to S3
        log.info(f"Uploading {local_file_path} to s3://{bucket}/{key}")
        s3_client.upload_file(local_file_path, bucket, key)
        log.info(f"Successfully uploaded {local_file_path} to s3://{bucket}/{key}")

        # Verify the upload by comparing MD5 checksums
        s3_md5 = calculate_md5(s3_path, s3_client=s3_client)
        log.info(f"MD5 checksum of uploaded file s3://{bucket}/{key}: {s3_md5}")

        if local_md5 == s3_md5:
            log.info(f"File {local_file_path} successfully verified after upload.")
        else:
            log.error(
                f"MD5 checksum mismatch: local file {local_md5} != s3 file {s3_md5}"
            )
            raise ValueError("MD5 checksum mismatch after upload.")

    except FileNotFoundError:
        log.error(f"The file {local_file_path} was not found.")
    except s3_client.exceptions.NoCredentialsError:
        log.error("Credentials not available.")
    except s3_client.exceptions.PartialCredentialsError:
        log.error("Incomplete credentials provided.")
    except Exception as e:
        log.error(f"An error occurred: {e}")
        log.error(traceback.format_exc())


def read_json(path: str, s3_client=None) -> dict:
    """Read a JSON file from local filesystem or S3.

    :param str path: Path to JSON file.
    :param s3_client: S3 client for reading from S3, if needed.
    :return: Content of the JSON file.
    :rtype: dict

    """
    # Handle S3 transport parameters
    if path.startswith("s3://"):
        transport_params = {"client": s3_client} if s3_client else {}
    else:
        transport_params = {}

    with smart_open.open(
        path, "r", encoding="utf-8", transport_params=transport_params
    ) as f:
        return json.load(f)


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


def setup_logging(
    log_level: str,
    log_file: Optional[str],
    force: bool = False,
    logger: Optional[logging.Logger] = None,
) -> None:
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
        logger (Optional[logging.Logger], optional): Specific logger to configure.
            If None, configures the root logger. Defaults to None.

    Returns:
        None

    Example:
        >>> setup_logging('INFO', 'logs/app.log')
        >>> setup_logging('DEBUG', 's3://bucket/logs/debug.log', force=True)
        >>> # Configure specific logger
        >>> my_logger = logging.getLogger(__name__)
        >>> setup_logging('INFO', 'app.log', logger=my_logger)
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

    if logger:
        # Configure specific logger
        logger.setLevel(log_level)
        # Remove existing handlers to avoid duplication
        for handler in logger.handlers[:]:
            logger.removeHandler(handler)
        # Add new handlers
        for handler in handlers:
            handler.setFormatter(
                logging.Formatter(
                    "%(asctime)-15s %(filename)s:%(lineno)d %(levelname)s: %(message)s"
                )
            )
            logger.addHandler(handler)
        # Prevent propagation to root logger to avoid duplicate messages
        logger.propagate = False
    else:
        # Configure root logger (backward compatibility)
        logging.basicConfig(
            level=log_level,
            format="%(asctime)-15s %(filename)s:%(lineno)d %(levelname)s: %(message)s",
            handlers=handlers,
            force=force,
        )


def calculate_md5(file_path: str, s3_client: Any = None) -> str:
    """
    Calculates the MD5 checksum of a file. Supports both local and S3 paths.

    Args:
        file_path (str): The path to the file (local or S3).
        s3_client (boto3.client, optional): The S3 client to use if the file is in S3.

    Returns:
        str: The MD5 checksum of the file.
    """
    hash_md5 = hashlib.md5()

    if file_path.startswith("s3://"):
        if s3_client is None:
            raise ValueError("s3_client must be provided for S3 paths")
        bucket, key = parse_s3_path(file_path)
        obj = s3_client.get_object(Bucket=bucket, Key=key)
        for chunk in iter(lambda: obj["Body"].read(4096), b""):
            hash_md5.update(chunk)
    else:
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)

    return hash_md5.hexdigest()


def have_same_md5(file_path1: str, file_path2: str, s3_client: Any = None) -> bool:
    """
    Compares the MD5 checksums of two files (local or S3) and returns True if they are the same, False otherwise.

    Args:
        file_path1 (str): The path to the first file (local or S3).
        file_path2 (str): The path to the second file (local or S3).
        s3_client (boto3.client, optional): The S3 client to use if any of the files are in S3.

    Returns:
        bool: True if the files have the same MD5 checksum, False otherwise.
    """
    logging.debug("Comparing MD5 checksums of %s and %s", file_path1, file_path2)
    md5_1 = calculate_md5(file_path1, s3_client)
    md5_2 = calculate_md5(file_path2, s3_client)
    return md5_1 == md5_2


def upload_with_retries(
    s3_client: Any,
    local_file_path: str,
    s3_path: str,
    max_retries: int = 5,
    sleep_time: int = 3,
) -> bool:
    """
    Tries to overwrite the S3 file by first uploading a temporary file and verifying the MD5 checksum.

    Args:
        s3_client (boto3.client): The S3 client to use.
        local_file_path (str): The path to the local file.
        s3_path (str): The S3 path to the file.
        max_retries (int): The maximum number of retries if the MD5 checksum does not match.
        sleep_time (int): The number of seconds to sleep between retries.

    Returns:
        bool: True if the file was successfully overwritten, False otherwise.
    """
    bucket, key = parse_s3_path(s3_path)
    tmp_key = key + ".tmp"
    local_md5 = calculate_md5(local_file_path)

    for attempt in range(max_retries):
        try:
            # Upload the temporary file to S3
            s3_client.upload_file(local_file_path, bucket, tmp_key)
            log.info(f"Uploaded temporary file to s3://{bucket}/{tmp_key}")

            # Calculate the MD5 checksum of the uploaded temporary file
            s3_md5 = calculate_md5(f"s3://{bucket}/{tmp_key}", s3_client=s3_client)

            # Verify the MD5 checksum
            if local_md5 == s3_md5:
                # Copy the temporary file to the final destination
                s3_client.copy_object(
                    Bucket=bucket,
                    Key=key,
                    CopySource={"Bucket": bucket, "Key": tmp_key},
                    MetadataDirective="REPLACE",
                )
                log.info(
                    f"Successfully copied s3://{bucket}/{tmp_key} to"
                    f" s3://{bucket}/{key}"
                )
                s3_md5_overwritten = calculate_md5(
                    f"s3://{bucket}/{key}", s3_client=s3_client
                )
                if local_md5 == s3_md5_overwritten:
                    log.info(f"MD5 checksum verified after overwrite: {local_md5}")
                else:
                    log.error(
                        f"MD5 checksum mismatch after overwrite: local file {local_md5}"
                        f" != s3 file {s3_md5_overwritten}"
                    )
                    raise ValueError(
                        f"MD5 checksum mismatch after overwrite: s3://{bucket}/{key} is"
                        " probably corrupted."
                    )
                return True
            else:
                log.warning(
                    f"MD5 checksum mismatch: local file {local_md5} != s3 file {s3_md5}"
                )
                time.sleep(sleep_time)
        except Exception as e:
            log.error(f"An error occurred during upload attempt {attempt + 1}: {e}")
            time.sleep(sleep_time)
        finally:
            s3_client.delete_object(Bucket=bucket, Key=tmp_key)
            log.info(f"Deleted temporary file s3://{bucket}/{tmp_key}")

    log.error(
        f"Failed to overwrite s3://{bucket}/{key} after {max_retries} attempts."
        " Continuing..."
    )
    return False


def download_with_retries(
    s3_client: Any,
    s3_path: str,
    local_file_path: str,
    max_retries: int = 5,
    sleep_time: int = 3,
) -> bool:
    """
    Tries to download an S3 file and verifies the MD5 checksum.

    Args:
        s3_client (boto3.client): The S3 client to use.
        s3_path (str): The S3 path to the file.
        local_file_path (str): The path to the local file.
        max_retries (int): The maximum number of retries if the MD5 checksum does not match.
        sleep_time (int): The number of seconds to sleep between retries.

    Returns:
        bool: True if the file was successfully downloaded and verified, False otherwise.
    """
    bucket, key = parse_s3_path(s3_path)
    s3_md5 = calculate_md5(s3_path, s3_client=s3_client)

    for attempt in range(max_retries):
        try:
            # Download the file from S3
            s3_client.download_file(bucket, key, local_file_path)
            log.info(f"Downloaded file to {local_file_path}")

            # Calculate the MD5 checksum of the downloaded file
            local_md5 = calculate_md5(local_file_path)

            # Verify the MD5 checksum
            if local_md5 == s3_md5:
                log.info(f"MD5 checksum verified: {local_md5}")
                return True
            else:
                log.warning(
                    f"MD5 checksum mismatch: local file {local_md5} != s3 file {s3_md5}"
                )
                time.sleep(sleep_time)
        except Exception as e:
            log.error(f"An error occurred during download attempt {attempt + 1}: {e}")
            time.sleep(sleep_time)

    log.error(
        f"Failed to download and verify s3://{bucket}/{key} after"
        f" {max_retries} attempts"
    )
    return False


def keep_timestamp_only(
    input_path: str, timestamp: datetime.datetime | None = None
) -> None:
    """
    Truncates the file to zero length and updates its metadata to the UTC timestamp.

    Args:
        input_path (str): The path to the file to be truncated and timestamped.
        timestamp (datetime, optional): The UTC timestamp to set for the file's
            metadata. If not provided, the current UTC time will be used.

    Raises:
        Exception: If an error occurs during the truncation or timestamp update process.

    Example:
        >>> import tempfile
        >>> from datetime import datetime, timezone
        >>> with tempfile.NamedTemporaryFile(delete=False) as tmp_file:
        ...     tmp_file_path = tmp_file.name
        >>> keep_timestamp_only(tmp_file_path, datetime(2023, 1, 1, tzinfo=timezone.utc))
        >>> os.path.getsize(tmp_file_path) == 0
        True
        >>> os.path.getmtime(tmp_file_path) == datetime(2023, 1, 1, tzinfo=timezone.utc).timestamp()
        True
        >>> os.remove(tmp_file_path)
    """

    try:
        # Truncate the file to zero length
        with open(input_path, "w", encoding="utf-8"):
            # opening with 'w' truncates the file
            log.info("Truncating %s and setting its timestamp metadata.", input_path)

        # Use the provided timestamp or default to the current UTC time
        if timestamp is None:
            timestamp = datetime.datetime.now(datetime.timezone.utc)

        # Convert the timestamp to a Unix timestamp (seconds since epoch)
        timestamp_epoch = timestamp.timestamp()

        # Update the file's modification and access time to the specified timestamp
        os.utime(input_path, (timestamp_epoch, timestamp_epoch))

        log.info(
            "Truncated %s and timestamp set to %s.",
            input_path,
            timestamp.strftime("%Y-%m-%dT%H:%M:%SZ"),
        )
    except Exception as e:
        log.error("Failed to truncate %s: %s", input_path, e)
        raise


def get_s3_resource(
    access_key: str | None = None,
    secret_key: str | None = None,
    host_url: str | None = "https://os.zhdk.cloud.switch.ch/",
) -> Any:
    """Configures and returns an S3 resource object.

    If the optional access key, secret key, and host URL are not provided, the
    method uses environment variables to configure the S3 resource object. Support
    .env configuration.

    Args:
        access_key (str | None, optional): The access key for S3. Defaults to None.
        secret_key (str | None, optional): The secret key for S3. Defaults to None.
        host_url (str | None, optional): The host URL for S3. Defaults to None.

        Returns:
            Any: The configured S3 resource.
    """

    access_key = access_key or os.getenv("SE_ACCESS_KEY")
    secret_key = secret_key or os.getenv("SE_SECRET_KEY")
    host_url = host_url or os.getenv("SE_HOST_URL")
    return boto3.resource(
        "s3",
        aws_secret_access_key=secret_key,
        aws_access_key_id=access_key,
        endpoint_url=host_url,
    )
