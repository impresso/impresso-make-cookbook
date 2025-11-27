#!/usr/bin/env python3
"""
This script processes JSONL.bz2 files stored in an S3 bucket. It extracts specified keys 
and their values from the JSON objects, applies optional filters, and writes the results 
to an output file (local or S3) with proper temporary file cleanup.

Features:
- Reads JSONL.bz2 files from an S3 bucket using a specified prefix
- Extracts specific keys from each JSON object or returns full objects
- Supports filtering JSON objects based on key-value pairs
- Allows applying advanced transformations using jq filters
- Outputs processed data to local files or S3 paths
- Automatic temporary file cleanup under all exit conditions
- Comprehensive logging with optional S3-compatible log files

Environment Variables:
- AWS credentials should be configured via standard AWS methods
- .env file support is available for configuration

Usage:
    python3 s3_aggregator.py --s3-prefix s3://bucket/prefix --keys key1 key2 \\
        --output s3://output-bucket/output.txt.gz

Examples:
1. Extract specific keys:
    python3 s3_aggregator.py --s3-prefix s3://bucket/prefix \\
        --keys id tokens --output s3://output-bucket/output.jsonl

2. Apply filters:
    python3 s3_aggregator.py --s3-prefix s3://bucket/prefix \\
        --keys id --filter type=article --output output.jsonl

3. Use jq filter for token extraction:
    python3 s3_aggregator.py --s3-prefix s3://bucket/prefix \\
        --jq-filter lib/extract_tokens.jq --output output.txt.gz \\
        --log-file s3://bucket/logs/process.log.gz

4. Extract all content without key filtering:
    python3 s3_aggregator.py --s3-prefix s3://bucket/prefix \
        --keys content --output output.txt.gz

5. Verify data readability:
    python3 s3_aggregator.py --s3-prefix s3://bucket/prefix --verify

6. Verify data with custom file extensions:
    python3 s3_aggregator.py --s3-prefix s3://bucket/prefix --verify \
        --verify-file-extensions json jsonl.gz json.bz2

7. Verify and delete corrupted files:
    python3 s3_aggregator.py --s3-prefix s3://bucket/prefix --verify \
        --verify-and-delete
"""

import argparse
import json
import logging
import os
import re
import sys
import tempfile
from typing import Dict, Any, Optional, Sequence
from dotenv import load_dotenv

import jq
from impresso_cookbook import get_s3_client, yield_s3_objects
from smart_open import open as smart_open

load_dotenv()


class SmartFileHandler(logging.FileHandler):
    def _open(self) -> any:
        """Open the log file using smart_open and return a file-like object."""
        return smart_open(self.baseFilename, self.mode, encoding="utf-8")


def list_s3_files_with_prefix(bucket: str, prefix: str) -> Sequence[str]:
    """List all files in an S3 bucket with a given prefix.

    Args:
        bucket (str): S3 bucket name.
        prefix (str): Prefix to filter files.

    Returns:
        Sequence[str]: List of file keys.
    """
    files = [
        file for file in yield_s3_objects(bucket, prefix) if file.endswith("jsonl.bz2")
    ]
    logging.warning("Found %d files with prefix %s", len(files), prefix)
    return files


def parse_filter_arguments(filter_args: Sequence[str]) -> Dict[str, str]:
    """Parse filter arguments into a dictionary.

    Args:
        filter_args (Sequence[str]): List of filter arguments in the form FEAT=VAL.

    Returns:
        Dict[str, str]: Dictionary of feature-value pairs.
    """
    filters = {}
    for arg in filter_args:
        if "=" in arg:
            key, value = arg.split("=", 1)
            filters[key] = value
        else:
            logging.warning("Invalid filter argument: %s. Skipping.", arg)
    return filters


def apply_jq_filter(data: Dict[str, Any], jq_filter: Optional[jq.jq]) -> Optional[Any]:
    """Apply a jq filter to a JSON object.

    Args:
        data (Dict[str, Any]): A dictionary representing a single JSON object.
        jq_filter (Optional[jq.jq]): A compiled jq filter.

    Returns:
        Optional[Any]: The filtered result, or None if the filter excludes it.
    """
    if jq_filter:
        try:
            results = list(jq_filter.input(data).all())
            return results if results else None
        except Exception as e:
            logging.error("Error applying jq filter: %s", e)
            return None
    return data


def process_jsonl_file(
    data: Dict[str, Any],
    keys: Sequence[str],
    filters: Dict[str, str],
    jq_filter: Optional[jq.jq],
) -> Optional[Any]:
    """Process a single JSON object, apply filters, jq filter, and extract specified keys.

    Args:
        data (Dict[str, Any]): A dictionary representing a single JSON object.
        keys (Sequence[str]): Keys to extract from the JSON object.
        filters (Dict[str, str]): Filters to apply to the JSON object.
        jq_filter (Optional[jq.jq]): A compiled jq filter.

    Returns:
        Optional[Any]: A dictionary containing the extracted keys and values, or list of results from jq filter, or None if the input is invalid or does not match filters.
    """
    try:
        for key, value in filters.items():
            logging.debug(
                "Filtering by %s for %s %s",
                data.get(key),
                value,
                data.get(key) == value,
            )
            if data.get(key) != value:
                return None

        if jq_filter:
            return apply_jq_filter(data, jq_filter)

        # If no keys are specified, return the entire JSON object
        if not keys:
            return data
        return {key: data[key] for key in keys if key in data}
    except KeyError as e:
        logging.warning("Missing key in data: %s. Skipping this entry.", e)
        return None


def verify_s3_files(
    bucket: str,
    prefix: str,
    file_extensions: Optional[Sequence[str]] = None,
    delete_corrupted: bool = False,
) -> None:
    """Verify that all matching files in an S3 bucket are readable.

    Args:
        bucket (str): S3 bucket name.
        prefix (str): Prefix to filter files.
        file_extensions (Optional[Sequence[str]]): List of file extensions to check.
            Defaults to ["jsonl.bz2"].
        delete_corrupted (bool): If True, delete corrupted files from S3.
    """
    if file_extensions is None:
        file_extensions = ["jsonl.bz2"]

    s3 = get_s3_client()
    transport_params = {"client": s3}
    total_files = 0
    total_lines = 0
    error_files = 0
    files_with_errors = []  # Track files that have errors
    deleted_files = []  # Track files that were deleted

    logging.info(
        "Starting verification of S3 data with extensions: %s", file_extensions
    )

    for file_key in yield_s3_objects(bucket, prefix):
        if not any(file_key.endswith(ext) for ext in file_extensions):
            continue

        total_files += 1
        file_lines = 0
        file_has_error = False
        try:
            logging.info("Verifying file %d: %s", total_files, file_key)
            with smart_open(
                f"s3://{bucket}/{file_key}", "rb", transport_params=transport_params
            ) as infile:
                for line in infile:
                    file_lines += 1
                    try:
                        json.loads(line)
                    except json.JSONDecodeError as e:
                        logging.error(
                            "JSON decode error in %s at line %d: %s",
                            file_key,
                            file_lines,
                            e,
                        )
                        error_files += 1
                        file_has_error = True
                        error_msg = (
                            f"s3://{bucket}/{file_key} "
                            f"(JSON decode error at line {file_lines})"
                        )
                        files_with_errors.append(error_msg)
                        if delete_corrupted:
                            try:
                                s3.delete_object(Bucket=bucket, Key=file_key)
                                deleted_files.append(f"s3://{bucket}/{file_key}")
                                logging.warning("Deleted corrupted file: %s", file_key)
                            except Exception as delete_error:
                                logging.error(
                                    "Failed to delete %s: %s",
                                    file_key,
                                    delete_error,
                                )
                        break
            total_lines += file_lines
            if not file_has_error:
                logging.info("  ✓ File readable: %d lines", file_lines)
        except Exception as e:
            logging.error("Error reading file %s: %s", file_key, e)
            error_files += 1
            file_has_error = True
            files_with_errors.append(f"s3://{bucket}/{file_key} ({str(e)})")
            if delete_corrupted:
                try:
                    s3.delete_object(Bucket=bucket, Key=file_key)
                    deleted_files.append(f"s3://{bucket}/{file_key}")
                    logging.warning("Deleted corrupted file: %s", file_key)
                except Exception as delete_error:
                    logging.error("Failed to delete %s: %s", file_key, delete_error)

    logging.info("=" * 60)
    logging.info("Verification complete:")
    logging.info("  Total files checked: %d", total_files)
    logging.info("  Total lines read: %d", total_lines)
    logging.info("  Files with errors: %d", error_files)
    success_rate = (
        (total_files - error_files) * 100.0 / total_files if total_files > 0 else 0
    )
    logging.info("  Success rate: %.2f%%", success_rate)

    if error_files > 0:
        # Print list of files with errors to stdout for easy parsing
        print("\n" + "=" * 60)
        print("FILES WITH ERRORS:")
        print("=" * 60)
        for error_file in files_with_errors:
            print(error_file)
        print("=" * 60)
        print(f"Total files with errors: {error_files}")

        if delete_corrupted and deleted_files:
            print("\n" + "=" * 60)
            print("DELETED FILES:")
            print("=" * 60)
            for deleted_file in deleted_files:
                print(deleted_file)
            print("=" * 60)
            print(f"Total files deleted: {len(deleted_files)}")

        sys.exit(1)
    else:
        logging.info("All data is readable ✓")
        print("\nAll data is readable ✓")


def upload_to_s3(local_path: str, s3_path: str, s3_client) -> None:
    """Upload a local file to an S3 path.

    Args:
        local_path (str): Path to the local file.
        s3_path (str): S3 path to upload the file to.
        s3_client: Boto3 S3 client.
    """
    bucket, key = re.match(r"s3://([^/]+)/(.+)", s3_path).groups()
    s3_client.upload_file(local_path, bucket, key)
    logging.info("Uploaded %s to %s", local_path, s3_path)


def process_s3_files(
    bucket: str,
    prefix: str,
    keys: Sequence[str],
    filters: Dict[str, str],
    output_path: str,
    jq_filter: Optional[jq.jq],
) -> None:
    """Process JSONL.bz2 files in an S3 bucket, apply filters, jq filter, extract specified keys, and write to an output file (local or S3).

    Args:
        bucket (str): S3 bucket name.
        prefix (str): Prefix to filter files.
        keys (Sequence[str]): Keys to extract from each JSON object.
        filters (Dict[str, str]): Filters to apply to each JSON object.
        output_path (str): Path to the output file (local or S3).
        jq_filter (Optional[jq.jq]): A compiled jq filter.
    """
    import os

    s3 = get_s3_client()
    transport_params = {"client": s3}
    total_lines = 0
    processed_count = 0

    suffix = output_path.split(".")[-1]
    tmpfile_path = None

    try:
        with tempfile.NamedTemporaryFile(
            delete=False, mode="w", encoding="utf-8", suffix=f".{suffix}"
        ) as tmpfile:
            tmpfile_path = tmpfile.name

        logging.info("Temporary file created: %s", tmpfile_path)

        with smart_open(tmpfile_path, "w", encoding="utf-8") as tmpfile:
            for file_key in yield_s3_objects(bucket, prefix):
                if not file_key.endswith("jsonl.bz2"):
                    continue
                logging.info("Processing file: %s", file_key)
                with smart_open(
                    f"s3://{bucket}/{file_key}",
                    "rb",
                    transport_params=transport_params,
                ) as infile:
                    for line in infile:
                        total_lines += 1
                        try:
                            data = json.loads(line)
                            processed_data = process_jsonl_file(
                                data, keys, filters, jq_filter
                            )
                            if processed_data:
                                if isinstance(processed_data, list):
                                    # Handle jq filter results (list of strings/values)
                                    for item in processed_data:
                                        if isinstance(item, str):
                                            tmpfile.write(item + "\n")
                                        else:
                                            tmpfile.write(
                                                json.dumps(item, ensure_ascii=False)
                                                + "\n"
                                            )
                                        processed_count += 1
                                else:
                                    # Handle regular JSON objects
                                    tmpfile.write(
                                        json.dumps(processed_data, ensure_ascii=False)
                                        + "\n"
                                    )
                                    processed_count += 1
                        except json.JSONDecodeError:
                            logging.error(
                                "Could not decode JSON from line: %s", line.strip()
                            )
                        except Exception as e:
                            logging.error("An error occurred processing line: %s", e)

        # File processing completed successfully, now handle output
        if output_path.startswith("s3://"):
            upload_to_s3(tmpfile_path, output_path, s3)
            # After successful S3 upload, we can clean up the temp file
            logging.info("Uploaded %s to S3, cleaning up temporary file", tmpfile_path)
        else:
            import shutil

            shutil.move(tmpfile_path, output_path)
            tmpfile_path = None  # File moved, don't delete it in finally block
            logging.info("Moved temporary file to %s", output_path)

        logging.info("Total lines read: %d", total_lines)
        logging.info("Total items processed and written: %d", processed_count)

    except Exception as e:
        logging.error("Error during file processing: %s", e)
        raise  # Re-raise the exception after logging
    finally:
        # Clean up temporary file if it still exists
        if tmpfile_path and os.path.exists(tmpfile_path):
            try:
                os.unlink(tmpfile_path)
                logging.debug("Cleaned up temporary file: %s", tmpfile_path)
            except Exception as e:
                logging.warning(
                    "Failed to clean up temporary file %s: %s", tmpfile_path, e
                )


def parse_arguments(args: Optional[Sequence[str]] = None) -> argparse.Namespace:
    """Parse command-line arguments.

    Args:
        args (Optional[Sequence[str]]): Command-line arguments.

    Returns:
        argparse.Namespace: Parsed argument namespace.
    """
    parser = argparse.ArgumentParser(
        description="Process JSONL.bz2 files from S3 with filtering and key extraction",
        epilog=(
            "Process JSONL.bz2 files stored in S3 buckets with advanced filtering, "
            "key extraction, jq transformations, and automatic temporary file cleanup. "
            "Supports both local and S3 output destinations."
        ),
        formatter_class=argparse.RawTextHelpFormatter,
    )

    parser.add_argument(
        "-o",
        "--output",
        type=str,
        required=False,
        help=(
            "Path to store the output JSONL file (local or S3). Example:"
            " s3://your-bucket/output-prefix/output.jsonl"
        ),
    )

    parser.add_argument(
        "--verify",
        action="store_true",
        help="Verify that all data files are readable (no output file required)",
    )

    parser.add_argument(
        "--verify-and-delete",
        action="store_true",
        help="Delete corrupted files during verification (requires --verify)",
    )

    parser.add_argument(
        "--verify-file-extensions",
        type=str,
        nargs="+",
        help=(
            "File extensions to check during verification "
            "(default: jsonl.bz2). Example: --verify-file-extensions json jsonl json.gz"
        ),
    )

    parser.add_argument(
        "-k",
        "--keys",
        type=str,
        nargs="+",
        help="List of keys to extract from each JSON object",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: INFO)",
    )
    parser.add_argument("--log-file", type=str, help="Log file path")
    parser.add_argument(
        "--s3-prefix",
        type=str,
        required=True,
        help="S3 path prefix (s3://BUCKET/PREFIX) to read JSONL.bz2 files",
    )
    parser.add_argument(
        "--filter",
        type=str,
        nargs="+",
        help="List of filters in the form FEAT=VAL to apply to each JSON object",
    )
    parser.add_argument(
        "--jq-filter",
        type=str,
        help="Path to a jq filter file to apply to each JSON object",
    )
    return parser.parse_args(args)


def main(args: Optional[Sequence[str]] = None) -> None:
    """Main function to run the data extraction process.

    Args:
        args (Optional[Sequence[str]]): Command-line arguments.
    """

    if args is None:
        args = sys.argv[1:]
    options = parse_arguments(args)

    handlers = [logging.StreamHandler()]
    if options.log_file:
        handlers.append(SmartFileHandler(options.log_file, mode="w"))
    logging.basicConfig(
        level=options.log_level,
        format="%(asctime)-15s %(filename)s:%(lineno)d %(levelname)s: %(message)s",
        handlers=handlers,
        force=True,
    )
    logging.info("Arguments: %s", options)
    logging.info("Processing S3 prefix: %s", options.s3_prefix)
    match = re.match(r"s3://([^/]+)/(.+)", options.s3_prefix)
    if not match:
        logging.error("Invalid S3 prefix format. Expected s3://BUCKET/PREFIX")
        sys.exit(1)
    bucket, prefix = match.groups()

    # Handle verification mode
    if options.verify:
        verify_s3_files(
            bucket,
            prefix,
            options.verify_file_extensions,
            options.verify_and_delete,
        )
        return

    # Warn if --verify-and-delete is used without --verify
    if options.verify_and_delete and not options.verify:
        logging.warning(
            "--verify-and-delete requires --verify flag. Ignoring --verify-and-delete."
        )

    # For non-verify mode, output is required
    if not options.output:
        logging.error("--output is required when not in --verify mode")
        sys.exit(1)

    output_match = re.match(r"s3://([^/]+)/(.+)", options.output)
    if not output_match and options.output.startswith("s3://"):
        logging.error("Invalid S3 output format. Expected s3://BUCKET/PREFIX")
        sys.exit(1)

    keys = options.keys
    filters = parse_filter_arguments(options.filter) if options.filter else {}
    logging.info("FILTERS: %s", filters)

    jq_filter = None
    if options.jq_filter:
        try:
            with open(options.jq_filter, "r", encoding="utf-8") as jq_file:
                jq_filter = jq.compile(jq_file.read())
        except Exception as e:
            logging.error("Failed to load jq filter: %s", e)
            sys.exit(1)

    process_s3_files(bucket, prefix, keys, filters, options.output, jq_filter)

    logging.info("Processing complete. Results saved to %s", options.output)


if __name__ == "__main__":
    main()
