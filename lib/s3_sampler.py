#!/usr/bin/env python3
"""
S3 Dataset Sampling Tool

This script samples jsonl.bz2 files from an S3 prefix using various sampling strategies.
It supports random sampling, stratified sampling by groups, and optional JQ
transformations
and filters.

Features:
- Reads JSONL.bz2 files from an S3 bucket using a specified prefix
- Supports random sampling with configurable sampling rate
- Supports stratified sampling with max samples per group (e.g., newspaper)
- Allows JQ-based filtering and transformation of records
- Memory-efficient streaming processing
- Outputs sampled data to a local file or S3 path
- Reproducible sampling with configurable random seed

Usage:
    python s3_sampler.py \
        --s3-prefix s3://bucket/path/to/dataset \
        --output s3://bucket/output/sampled_data.jsonl \
        --sampling-rate 0.1 \
        --log-level INFO

    # Stratified sampling by newspaper with max 100 samples per newspaper:
    python s3_sampler.py \
        --s3-prefix s3://bucket/path/to/dataset \
        --output sampled_data.jsonl \
        --group-by-expr '.newspaper_id' \
        --max-samples-per-group 100 \
        --filter-file filter.jq \
        --transform-file transform.jq \
        --random-seed 42

Examples:
1. Simple random sampling (10%):
    python s3_sampler.py --s3-prefix s3://bucket/data \\
        --output sample.jsonl --sampling-rate 0.1

2. Stratified sampling with filtering:
    python s3_sampler.py --s3-prefix s3://bucket/data --output sample.jsonl \
        --group-by-expr '.newspaper_id' --max-samples-per-group 50 \
        --filter-expr 'select(.type == "article")'

3. Transform and sample:
    python s3_sampler.py --s3-prefix s3://bucket/data --output sample.jsonl \
        --transform-expr '{id: .id, text: .content_text, date: .date}' \
        --sampling-rate 0.05
"""

import argparse
import json
import logging
import random
import sys
import tempfile
from collections import defaultdict
from typing import Dict, Any, Optional, List, Generator

import jq
from dotenv import load_dotenv
from smart_open import open as smart_open

try:
    from impresso_cookbook import (
        get_s3_client,
        get_timestamp,
        setup_logging,
        get_transport_params,
        yield_s3_objects,
        parse_s3_path,
    )
except ImportError:
    # Fallback for when impresso_cookbook is not available
    from common import (
        get_s3_client,
        get_timestamp,
        setup_logging,
        get_transport_params,
        yield_s3_objects,
        parse_s3_path,
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
        description="Sample JSONL.bz2 files from S3 using various sampling strategies.",
        formatter_class=argparse.RawTextHelpFormatter,
    )

    # Logging options
    parser.add_argument(
        "--log-file", dest="log_file", help="Write log to FILE", metavar="FILE"
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: %(default)s)",
    )

    # Input/Output options
    parser.add_argument(
        "--s3-prefix",
        type=str,
        required=True,
        help="S3 path prefix (e.g., s3://bucket/prefix) to read JSONL.bz2 files",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=str,
        required=True,
        help="Output path for sampled data (local or S3), JSONL format.",
    )

    # Sampling options
    parser.add_argument(
        "--sampling-rate",
        type=float,
        help=(
            "Random sampling rate (0.0 to 1.0). "
            "Mutually exclusive with max-samples-per-group."
        ),
    )
    parser.add_argument(
        "--max-samples-per-group",
        type=int,
        help=(
            "Maximum samples per group (requires --group-by-expr). "
            "Mutually exclusive with sampling-rate."
        ),
    )
    parser.add_argument(
        "--group-by-expr",
        type=str,
        help="JQ expression to extract group identifier (e.g., '.newspaper_id')",
    )
    parser.add_argument(
        "--random-seed",
        type=int,
        default=42,
        help="Random seed for reproducible sampling (default: %(default)s)",
    )

    # Processing options
    parser.add_argument(
        "--filter-expr",
        type=str,
        help="JQ expression to filter records (e.g., 'select(.type == \"article\")')",
    )
    parser.add_argument(
        "--filter-file",
        type=str,
        help="Path to file containing JQ filter expression",
    )
    parser.add_argument(
        "--transform-expr",
        type=str,
        help="JQ expression to transform records (e.g., '{id: .id, text: .content}')",
    )
    parser.add_argument(
        "--transform-file",
        type=str,
        help="Path to file containing JQ transform expression",
    )

    return parser.parse_args(args)


class S3SamplerProcessor:
    """
    A processor class that samples datasets from S3 using various sampling strategies.
    Supports both random sampling and stratified sampling by groups.
    """

    def __init__(
        self,
        s3_prefix: str,
        output_file: str,
        sampling_rate: Optional[float] = None,
        max_samples_per_group: Optional[int] = None,
        group_by_expr: Optional[str] = None,
        random_seed: int = 42,
        filter_expr: Optional[str] = None,
        filter_file: Optional[str] = None,
        transform_expr: Optional[str] = None,
        transform_file: Optional[str] = None,
        log_level: str = "INFO",
        log_file: Optional[str] = None,
    ) -> None:
        """
        Initialize the S3SamplerProcessor.

        Args:
            s3_prefix: S3 prefix path to read from
            output_file: Path to the output file
            sampling_rate: Random sampling rate (0.0 to 1.0)
            max_samples_per_group: Maximum samples per group
            group_by_expr: JQ expression to extract group identifier
            random_seed: Random seed for reproducible sampling
            filter_expr: JQ expression for filtering
            filter_file: Path to JQ filter file
            transform_expr: JQ expression for transformation
            transform_file: Path to JQ transform file
            log_level: Logging level
            log_file: Path to log file
        """
        self.s3_prefix = s3_prefix
        self.output_file = output_file
        self.sampling_rate = sampling_rate
        self.max_samples_per_group = max_samples_per_group
        self.group_by_expr = group_by_expr
        self.random_seed = random_seed
        self.filter_expr = filter_expr
        self.filter_file = filter_file
        self.transform_expr = transform_expr
        self.transform_file = transform_file
        self.log_level = log_level
        self.log_file = log_file

        # Configure logging
        setup_logging(self.log_level, self.log_file, logger=log)

        # Initialize S3 client and timestamp
        self.s3_client = get_s3_client()
        self.timestamp = get_timestamp()

        # Set random seed for reproducible sampling
        random.seed(self.random_seed)

        # Validate sampling configuration
        self._validate_sampling_config()

        # Compile JQ expressions
        self._compile_jq_expressions()

        # Initialize sampling state
        self.group_sample_counts: Dict[str, int] = defaultdict(int)
        self.total_processed = 0
        self.total_sampled = 0

    def _validate_sampling_config(self) -> None:
        """Validate sampling configuration parameters."""
        if self.sampling_rate is not None and self.max_samples_per_group is not None:
            log.error("Cannot specify both sampling-rate and max-samples-per-group")
            sys.exit(1)

        if self.sampling_rate is None and self.max_samples_per_group is None:
            log.error("Must specify either sampling-rate or max-samples-per-group")
            sys.exit(1)

        if self.sampling_rate is not None:
            if not 0.0 <= self.sampling_rate <= 1.0:
                log.error("Sampling rate must be between 0.0 and 1.0")
                sys.exit(1)

        if self.max_samples_per_group is not None:
            if self.max_samples_per_group <= 0:
                log.error("Max samples per group must be positive")
                sys.exit(1)
            if self.group_by_expr is None:
                log.error("max-samples-per-group requires group-by-expr")
                sys.exit(1)

    def _compile_jq_expressions(self) -> None:
        """Compile all JQ expressions."""
        # Group-by expression
        self.group_by_program = None
        if self.group_by_expr:
            try:
                self.group_by_program = jq.compile(self.group_by_expr)
            except Exception as e:
                log.error(f"Invalid group-by JQ expression '{self.group_by_expr}': {e}")
                sys.exit(1)

        # Filter expression
        self.filter_program = None
        if self.filter_expr or self.filter_file:
            filter_code = self.filter_expr
            if self.filter_file:
                try:
                    with smart_open(
                        self.filter_file,
                        "r",
                        encoding="utf-8",
                        transport_params=get_transport_params(self.filter_file),
                    ) as f:
                        filter_code = f.read().strip()
                except Exception as e:
                    log.error(f"Failed to load filter file '{self.filter_file}': {e}")
                    sys.exit(1)

            try:
                self.filter_program = jq.compile(filter_code)
                log.info("Compiled filter JQ expression")
            except Exception as e:
                log.error(f"Invalid filter JQ expression: {e}")
                sys.exit(1)

        # Transform expression
        self.transform_program = None
        if self.transform_expr or self.transform_file:
            transform_code = self.transform_expr
            if self.transform_file:
                try:
                    with smart_open(
                        self.transform_file,
                        "r",
                        encoding="utf-8",
                        transport_params=get_transport_params(self.transform_file),
                    ) as f:
                        transform_code = f.read().strip()
                except Exception as e:
                    log.error(
                        f"Failed to load transform file '{self.transform_file}': {e}"
                    )
                    sys.exit(1)

            try:
                self.transform_program = jq.compile(transform_code)
                log.info("Compiled transform JQ expression")
            except Exception as e:
                log.error(f"Invalid transform JQ expression: {e}")
                sys.exit(1)

    def _apply_filter(self, record: Dict[str, Any]) -> bool:
        """
        Apply filter to a record.

        Args:
            record: JSON record to filter

        Returns:
            bool: True if record passes filter, False otherwise
        """
        if self.filter_program is None:
            return True

        try:
            result = list(self.filter_program.input(record).iter())
            return len(result) > 0 and result[0] is not False
        except Exception as e:
            log.debug(f"Filter error for record: {e}")
            return False

    def _apply_transform(self, record: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Apply transformation to a record.

        Args:
            record: JSON record to transform

        Returns:
            Optional[Dict[str, Any]]: Transformed record or None if transformation fails
        """
        if self.transform_program is None:
            return record

        try:
            return self.transform_program.input(record).first()
        except StopIteration:
            log.debug("Transform returned empty result")
            return None
        except Exception as e:
            log.debug(f"Transform error for record: {e}")
            return None

    def _get_group_id(self, record: Dict[str, Any]) -> Optional[str]:
        """
        Extract group identifier from a record.

        Args:
            record: JSON record

        Returns:
            Optional[str]: Group identifier or None if extraction fails
        """
        if self.group_by_program is None:
            return "default"

        try:
            result = self.group_by_program.input(record).first()
            return str(result) if result is not None else None
        except Exception as e:
            log.debug(f"Group-by error for record: {e}")
            return None

    def _should_sample(self, record: Dict[str, Any]) -> bool:
        """
        Determine if a record should be sampled based on the sampling strategy.

        Args:
            record: JSON record

        Returns:
            bool: True if record should be sampled, False otherwise
        """
        if self.sampling_rate is not None:
            # Random sampling
            return random.random() < self.sampling_rate

        elif self.max_samples_per_group is not None:
            # Stratified sampling by group
            group_id = self._get_group_id(record)
            if group_id is None:
                return False

            if self.group_sample_counts[group_id] < self.max_samples_per_group:
                self.group_sample_counts[group_id] += 1
                return True
            return False

        return False

    def _read_and_process_file(
        self, bucket: str, file_key: str
    ) -> Generator[Dict[str, Any], None, None]:
        """
        Read and process a single JSONL.bz2 file, yielding sampled records.

        Args:
            bucket: S3 bucket name
            file_key: S3 file key

        Yields:
            Dict[str, Any]: Processed and sampled records
        """
        transport_params = get_transport_params(f"s3://{bucket}/{file_key}")

        try:
            with smart_open(
                f"s3://{bucket}/{file_key}",
                "rb",
                transport_params=transport_params,
            ) as infile:
                for line_num, line in enumerate(infile, 1):
                    try:
                        record = json.loads(line)
                        self.total_processed += 1

                        # Apply filter
                        if not self._apply_filter(record):
                            continue

                        # Check sampling decision
                        if not self._should_sample(record):
                            continue

                        # Apply transformation
                        transformed_record = self._apply_transform(record)
                        if transformed_record is not None:
                            self.total_sampled += 1
                            yield transformed_record

                    except json.JSONDecodeError:
                        log.warning(f"Skipping malformed line {line_num} in {file_key}")
                    except Exception as e:
                        log.error(
                            f"Error processing line {line_num} in {file_key}: {e}"
                        )

        except Exception as e:
            log.error(f"Failed to open or read file {file_key}: {e}")

    def _upload_to_s3(self, local_path: str, s3_path: str) -> None:
        """Upload a local file to S3."""
        bucket, key = parse_s3_path(s3_path)
        self.s3_client.upload_file(local_path, bucket, key)
        log.info(f"Uploaded {local_path} to {s3_path}")

    def run(self) -> None:
        """Run the sampling process."""
        try:
            log.info(f"Starting sampling from {self.s3_prefix}")

            bucket, prefix = parse_s3_path(self.s3_prefix)

            # Create temporary file for output
            suffix = self.output_file.split(".")[-1]
            with tempfile.NamedTemporaryFile(
                delete=False, mode="w", encoding="utf-8", suffix=f".{suffix}"
            ) as tmpfile:
                tmpfile_path = tmpfile.name
                log.info(f"Temporary file created: {tmpfile_path}")

                with smart_open(tmpfile_path, "w", encoding="utf-8") as outfile:
                    processed_files = 0

                    # Process each file
                    for file_key in yield_s3_objects(bucket, prefix):
                        if not file_key.endswith("jsonl.bz2"):
                            continue

                        log.info(f"Processing file: {file_key}")
                        file_sample_count = 0

                        for record in self._read_and_process_file(bucket, file_key):
                            outfile.write(json.dumps(record, ensure_ascii=False) + "\n")
                            file_sample_count += 1

                        processed_files += 1
                        log.info(
                            f"File {file_key}: sampled {file_sample_count} records"
                        )

                # Upload to S3 or move to final location
                if self.output_file.startswith("s3://"):
                    self._upload_to_s3(tmpfile_path, self.output_file)
                else:
                    import shutil

                    shutil.move(tmpfile_path, self.output_file)
                    log.info(f"Moved {tmpfile_path} to {self.output_file}")

            # Log summary statistics
            log.info("Processing complete:")
            log.info(f"  Files processed: {processed_files}")
            log.info(f"  Total records processed: {self.total_processed}")
            log.info(f"  Total records sampled: {self.total_sampled}")

            if self.max_samples_per_group is not None:
                log.info(f"  Groups sampled: {len(self.group_sample_counts)}")
                for group_id, count in sorted(self.group_sample_counts.items()):
                    log.info(f"    {group_id}: {count} samples")

            if self.total_processed > 0:
                sampling_ratio = self.total_sampled / self.total_processed
                log.info(f"  Effective sampling ratio: {sampling_ratio:.4f}")

            log.info(f"Results saved to {self.output_file}")

        except Exception as e:
            log.error(f"Error during sampling process: {e}", exc_info=True)
            sys.exit(1)


def main(args: Optional[List[str]] = None) -> None:
    """
    Main function to run the S3 Sampler Processor.

    Args:
        args: Command-line arguments (uses sys.argv if None)
    """
    options: argparse.Namespace = parse_arguments(args)

    processor: S3SamplerProcessor = S3SamplerProcessor(
        s3_prefix=options.s3_prefix,
        output_file=options.output,
        sampling_rate=options.sampling_rate,
        max_samples_per_group=options.max_samples_per_group,
        group_by_expr=options.group_by_expr,
        random_seed=options.random_seed,
        filter_expr=options.filter_expr,
        filter_file=options.filter_file,
        transform_expr=options.transform_expr,
        transform_file=options.transform_file,
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
