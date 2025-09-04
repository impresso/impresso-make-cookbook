#!/usr/bin/env python3
"""
S3 Dataset Comparison Tool

This script compares JSONL.bz2 files from two S3 prefixes using a JQ expression
to extract unique identifiers from each JSON object. It finds the identifiers
present in both datasets and writes the common identifiers to an output file.

Features:
- Reads JSONL.bz2 files from two different S3 prefixes
- Uses a JQ expression to extract a comparison key (ID) from each JSON object
- Efficiently finds the intersection of IDs between the two datasets
- Outputs the common IDs to a local file or an S3 path
- Integrates with impresso_cookbook for consistent logging and S3 handling

Usage:
    python s3_comparer.py \\
        --s3-prefix1 s3://bucket/path/to/first/dataset \\
        --s3-prefix2 s3://bucket/path/to/second/dataset \\
        --id-expr '.id' \\
        --output s3://bucket/output/common_ids.txt \\
        --log-level INFO

    # With transformation and comparison:
    python s3_comparer.py \\
        --s3-prefix1 s3://bucket/path/to/first/dataset \\
        --s3-prefix2 s3://bucket/path/to/second/dataset \\
        --id-expr '.id' \\
        --transform-file transform.jq \\
        --comparison-expr '.[0] == .[1]' \\
        --output s3://bucket/output/comparison_results.jsonl \\
        --log-level INFO

This will extract the 'id' field from all items in both prefixes. If only basic
comparison is needed, it writes the IDs that appear in both datasets to the output.
If transform-file and comparison-expr are provided, it applies the transformation
to matching records and evaluates the comparison expression on the tuple.
"""

import argparse
import json
import logging
import re
import sys
from typing import List, Optional

import jq
from dotenv import load_dotenv
from smart_open import open as smart_open

from impresso_cookbook import (
    get_s3_client,
    get_timestamp,
    setup_logging,
    get_transport_params,
    yield_s3_objects,
)

log = logging.getLogger(__name__)

# Load environment variables for S3 credentials
load_dotenv()


def parse_arguments(args: Optional[List[str]] = None) -> argparse.Namespace:
    """
    Parse command-line arguments.

    Args:
        args: Command-line arguments (uses sys.argv if None)

    Returns:
        argparse.Namespace: Parsed arguments
    """
    parser = argparse.ArgumentParser(
        description="Compare items from two S3 prefixes and find common IDs.",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument(
        "--log-file", dest="log_file", help="Write log to FILE", metavar="FILE"
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: %(default)s)",
    )
    parser.add_argument(
        "--s3-prefix1",
        type=str,
        required=True,
        help="First S3 path prefix (e.g., s3://bucket/prefix1)",
    )
    parser.add_argument(
        "--s3-prefix2",
        type=str,
        required=True,
        help="Second S3 path prefix (e.g., s3://bucket/prefix2)",
    )
    parser.add_argument(
        "--id-expr",
        type=str,
        required=True,
        help=(
            "JQ expression to extract the identifier from each JSON object (e.g.,"
            " '.id')"
        ),
    )
    parser.add_argument(
        "--transform-file",
        type=str,
        help="Path to file containing JQ code to transform each JSON record",
    )
    parser.add_argument(
        "--comparison-expr",
        type=str,
        help="JQ expression to apply to the tuple of transformed records",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=str,
        required=True,
        help="Output path for results (local or S3), one result per line.",
    )
    return parser.parse_args(args)


class S3ComparerProcessor:
    """
    A processor class that compares datasets from two S3 prefixes and finds common IDs.
    """

    def __init__(
        self,
        s3_prefix1: str,
        s3_prefix2: str,
        id_expr: str,
        output_file: str,
        transform_file: Optional[str] = None,
        comparison_expr: Optional[str] = None,
        log_level: str = "INFO",
        log_file: Optional[str] = None,
    ) -> None:
        """
        Initializes the S3ComparerProcessor with explicit parameters.

        Args:
            s3_prefix1 (str): First S3 prefix path
            s3_prefix2 (str): Second S3 prefix path
            id_expr (str): JQ expression to extract IDs
            output_file (str): Path to the output file
            transform_file (Optional[str]): Path to file with JQ transformation code
            comparison_expr (Optional[str]): JQ expression for tuple comparison
            log_level (str): Logging level (default: "INFO")
            log_file (Optional[str]): Path to log file (default: None)
        """
        self.s3_prefix1 = s3_prefix1
        self.s3_prefix2 = s3_prefix2
        self.id_expr = id_expr
        self.output_file = output_file
        self.transform_file = transform_file
        self.comparison_expr = comparison_expr
        self.log_level = log_level
        self.log_file = log_file

        # Configure the module-specific logger
        setup_logging(self.log_level, self.log_file, logger=log)

        # Initialize S3 client and timestamp
        self.s3_client = get_s3_client()
        self.timestamp = get_timestamp()

        # Compile JQ expressions
        try:
            self.id_program = jq.compile(self.id_expr)
        except Exception as e:
            log.error(f"Invalid ID JQ expression '{self.id_expr}': {e}")
            sys.exit(1)

        # Load and compile transform JQ code if provided
        self.transform_program = None
        if self.transform_file:
            try:
                with smart_open(
                    self.transform_file,
                    "r",
                    encoding="utf-8",
                    transport_params=get_transport_params(self.transform_file),
                ) as f:
                    transform_code = f.read().strip()
                self.transform_program = jq.compile(transform_code)
                log.info(f"Loaded transform JQ code from {self.transform_file}")
            except Exception as e:
                log.error(f"Failed to load transform file '{self.transform_file}': {e}")
                sys.exit(1)

        # Compile comparison JQ expression if provided
        self.comparison_program = None
        if self.comparison_expr:
            try:
                self.comparison_program = jq.compile(self.comparison_expr)
            except Exception as e:
                log.error(
                    f"Invalid comparison JQ expression '{self.comparison_expr}': {e}"
                )
                sys.exit(1)

    def parse_s3_path(self, s3_path: str) -> tuple[str, str]:
        """Parses an S3 path into bucket and prefix. Exits on invalid format."""
        match = re.match(r"s3://([^/]+)/(.+)", s3_path)
        if not match:
            log.error(f"Invalid S3 path format: {s3_path}. Expected s3://BUCKET/PREFIX")
            sys.exit(1)
        return match.groups()

    def get_records_from_s3_prefix(self, bucket: str, prefix: str) -> dict[str, dict]:
        """
        Scans a given S3 prefix, processes JSONL.bz2 files, and returns a dictionary
        mapping IDs to their full JSON records.

        Args:
            bucket (str): The S3 bucket name.
            prefix (str): The S3 prefix to scan for files.

        Returns:
            A dictionary mapping IDs to their JSON records.
        """
        records = {}
        transport_params = get_transport_params(f"s3://{bucket}/{prefix}")
        log.info(f"Scanning prefix s3://{bucket}/{prefix} to collect records...")

        for file_key in yield_s3_objects(bucket, prefix):
            if not file_key.endswith("jsonl.bz2"):
                continue

            log.debug(f"Processing file: {file_key}")
            try:
                with smart_open(
                    f"s3://{bucket}/{file_key}",
                    "rb",
                    transport_params=transport_params,
                ) as infile:
                    for line in infile:
                        try:
                            data = json.loads(line)
                            item_id = self.id_program.input(data).first()
                            if item_id is not None:
                                records[str(item_id)] = data
                        except (json.JSONDecodeError, StopIteration):
                            log.warning(f"Skipping malformed line in {file_key}")
                        except Exception as e:
                            log.error(f"Error processing line in {file_key}: {e}")
            except Exception as e:
                log.error(f"Failed to open or read file {file_key}: {e}")

        log.info(f"Collected {len(records)} records from s3://{bucket}/{prefix}")
        return records

    def run(self) -> None:
        """
        Runs the S3 comparer processor. If transform and comparison expressions
        are provided, applies transformations to matching records and evaluates
        the comparison. Otherwise, finds and outputs common IDs.
        """
        try:
            log.info(
                f"Starting comparison between {self.s3_prefix1} and {self.s3_prefix2}"
            )

            # Get records from both prefixes
            bucket1, prefix1 = self.parse_s3_path(self.s3_prefix1)
            records1 = self.get_records_from_s3_prefix(bucket1, prefix1)

            bucket2, prefix2 = self.parse_s3_path(self.s3_prefix2)
            records2 = self.get_records_from_s3_prefix(bucket2, prefix2)

            # Find common IDs
            common_ids = set(records1.keys()).intersection(set(records2.keys()))
            log.info(f"Found {len(common_ids)} common IDs.")

            if not common_ids:
                log.warning("No common IDs found. Output file will be empty.")

            # Process based on whether transform/comparison is requested
            log.debug(f"Transform program loaded: {self.transform_program is not None}")
            log.debug(
                f"Comparison program loaded: {self.comparison_program is not None}"
            )

            if self.transform_program and self.comparison_program:
                log.info("Using transformation and comparison mode")
                self._process_with_transformation(records1, records2, common_ids)
            else:
                log.info("Using basic mode - outputting common IDs only")
                self._output_common_ids(common_ids)

        except Exception as e:
            log.error(f"Error during comparison process: {e}", exc_info=True)
            sys.exit(1)

    def _process_with_transformation(
        self, records1: dict, records2: dict, common_ids: set
    ) -> None:
        """
        Apply transformations to matching records and evaluate comparison expression.
        """
        results = []

        for item_id in common_ids:
            try:
                # Get the records for this ID
                record1 = records1.get(item_id)
                record2 = records2.get(item_id)

                # Skip if either record is missing
                if record1 is None or record2 is None:
                    log.debug(f"Skipping ID {item_id}: missing in one or both datasets")
                    continue

                # Apply transformation to each record
                if self.transform_program is not None:
                    try:
                        transformed1 = self.transform_program.input(record1).first()
                    except StopIteration:
                        log.debug(
                            f"Transform returned empty for record1 with ID {item_id}"
                        )
                        continue
                    except Exception as e:
                        log.warning(
                            f"Transform failed for record1 with ID {item_id}: {e}"
                        )
                        continue

                    try:
                        transformed2 = self.transform_program.input(record2).first()
                    except StopIteration:
                        log.debug(
                            f"Transform returned empty for record2 with ID {item_id}"
                        )
                        continue
                    except Exception as e:
                        log.warning(
                            f"Transform failed for record2 with ID {item_id}: {e}"
                        )
                        continue
                else:
                    transformed1 = record1
                    transformed2 = record2

                # Create tuple and apply comparison expression
                tuple_data = [transformed1, transformed2]
                if self.comparison_program is not None:
                    try:
                        result = self.comparison_program.input(tuple_data).first()
                    except StopIteration:
                        # JQ expression returned empty (e.g., condition was false)
                        log.debug(f"Comparison returned empty for ID {item_id}")
                        continue
                    except Exception as e:
                        log.warning(f"Comparison failed for ID {item_id}: {e}")
                        continue
                else:
                    result = tuple_data

                if result is not None:
                    results.append(result)

            except Exception as e:
                log.warning(
                    f"Unexpected error processing ID {item_id}: {e}", exc_info=True
                )
                continue

        # Write results to output
        with smart_open(
            self.output_file,
            "w",
            encoding="utf-8",
            transport_params=get_transport_params(self.output_file),
        ) as f:
            for result in results:
                if isinstance(result, (dict, list)):
                    f.write(json.dumps(result, ensure_ascii=False) + "\n")
                else:
                    f.write(str(result) + "\n")

        log.info(
            f"Successfully wrote {len(results)} transformation results to "
            f"{self.output_file}"
        )

    def _output_common_ids(self, common_ids: set) -> None:
        """
        Output common IDs to the output file.
        """
        with smart_open(
            self.output_file,
            "w",
            encoding="utf-8",
            transport_params=get_transport_params(self.output_file),
        ) as f:
            for item_id in sorted(list(common_ids)):
                f.write(f"{item_id}\n")

        log.info(
            f"Successfully wrote {len(common_ids)} common IDs to {self.output_file}"
        )


def main(args: Optional[List[str]] = None) -> None:
    """
    Main function to run the S3 Comparer Processor.

    Args:
        args: Command-line arguments (uses sys.argv if None)
    """
    options: argparse.Namespace = parse_arguments(args)

    processor: S3ComparerProcessor = S3ComparerProcessor(
        s3_prefix1=options.s3_prefix1,
        s3_prefix2=options.s3_prefix2,
        id_expr=options.id_expr,
        output_file=options.output,
        transform_file=options.transform_file,
        comparison_expr=options.comparison_expr,
        log_level=options.log_level,
        log_file=options.log_file,
    )

    # Log the parsed options after logger is configured
    log.info("%s", options)

    processor.run()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log.error(f"Processing error: {e}", exc_info=True)
        sys.exit(2)
