#!/usr/bin/env python3
"""
S3 Dataset Compiler Tool

This script compiles a corpus by taking a JSONL file with record IDs and fetching
corresponding entries from S3 files based on ID patterns. It extracts content from
matching lines in S3 JSONL.bz2 files and applies optional JQ transformations.

Features:
- Reads a JSONL file containing record IDs
- Parses IDs to determine corresponding S3 files (e.g., NEWSPAPER-YEAR-CONTENTITEMID)
- Fetches matching records from S3 JSONL.bz2 files
- Supports JQ-based transformation of extracted records
- Memory-efficient processing with caching of frequently accessed files
- Outputs compiled corpus to a local file or S3 path

Usage:
    python s3_compiler.py \
        --input-file sample_ids.jsonl \
        --s3-prefix s3://bucket/path/to/dataset \
        --output compiled_corpus.jsonl \
        --id-field id \
        --log-level INFO

    # With transformation:
    python s3_compiler.py \
        --input-file sample_ids.jsonl \
        --s3-prefix s3://bucket/path/to/dataset \
        --output compiled_corpus.jsonl \
        --id-field id \
        --transform-expr '{id: .id, title: .title, content: .content_text}' \
        --log-level INFO

Examples:
1. Basic compilation:
    python s3_compiler.py --input-file ids.jsonl --s3-prefix s3://bucket/data \
        --output corpus.jsonl --id-field id

2. With transformation:
    python s3_compiler.py --input-file ids.jsonl --s3-prefix s3://bucket/data \
        --output corpus.jsonl --id-field id \
        --transform-expr '{id: .id, text: .content_text, date: .date}'

3. Using transform file:
    python s3_compiler.py --input-file ids.jsonl --s3-prefix s3://bucket/data \
        --output corpus.jsonl --id-field id --transform-file transform.jq

ID Format:
The script expects IDs in the format: NEWSPAPER-YEAR-CONTENTITEMID
It will look for files named: NEWSPAPER-YEAR.jsonl.bz2 in the S3 prefix
"""

import argparse
import json
import logging
import re
import sys
import tempfile
from typing import Dict, Any, Optional, List

import jq
from dotenv import load_dotenv
from smart_open import open as smart_open

try:
    from impresso_cookbook import (
        get_s3_client,
        get_timestamp,
        setup_logging,
        get_transport_params,
        parse_s3_path,
    )
except ImportError:
    # Fallback for when impresso_cookbook is not available
    from common import (
        get_s3_client,
        get_timestamp,
        setup_logging,
        get_transport_params,
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
        description="Compile corpus from S3 by fetching records matching IDs.",
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
        "--input-file",
        type=str,
        required=True,
        help="Input JSONL file containing record IDs (local or S3)",
    )
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
        help="Output path for compiled corpus (local or S3), JSONL format.",
    )

    # ID processing options
    parser.add_argument(
        "--id-field",
        type=str,
        default="id",
        help="Field name containing the ID in input records (default: %(default)s)",
    )
    parser.add_argument(
        "--id-pattern",
        type=str,
        default=r"^([^-]+)-(\d{4})-(.+)$",
        help="Regex pattern to parse ID (default: NEWSPAPER-YEAR-CONTENTID format)",
    )
    parser.add_argument(
        "--file-pattern",
        type=str,
        default="{newspaper}-{year}.jsonl.bz2",
        help="Pattern for S3 file names (default: %(default)s)",
    )

    # Processing options
    parser.add_argument(
        "--transform-expr",
        type=str,
        help="JQ expression to transform extracted records",
    )
    parser.add_argument(
        "--transform-file",
        type=str,
        help="Path to file containing JQ transform expression",
    )
    parser.add_argument(
        "--match-field",
        type=str,
        default="id",
        help="Field name to match against in S3 records (default: %(default)s)",
    )

    # Performance options
    parser.add_argument(
        "--batch-size",
        type=int,
        default=1000,
        help="Number of records to process in each batch (default: %(default)s)",
    )

    return parser.parse_args(args)


class S3CompilerProcessor:
    """
    A processor class that compiles a corpus by fetching records from S3
    based on provided IDs.
    """

    def __init__(
        self,
        input_file: str,
        s3_prefix: str,
        output_file: str,
        id_field: str = "id",
        id_pattern: str = r"^([^-]+)-(\d{4})-(.+)$",
        file_pattern: str = "{newspaper}-{year}.jsonl.bz2",
        transform_expr: Optional[str] = None,
        transform_file: Optional[str] = None,
        match_field: str = "id",
        batch_size: int = 1000,
        log_level: str = "INFO",
        log_file: Optional[str] = None,
    ) -> None:
        """
        Initialize the S3CompilerProcessor.

        Args:
            input_file: Path to input JSONL file with IDs
            s3_prefix: S3 prefix path to read from
            output_file: Path to the output file
            id_field: Field name containing ID in input records
            id_pattern: Regex pattern to parse IDs
            file_pattern: Pattern for S3 file names
            transform_expr: JQ expression for transformation
            transform_file: Path to JQ transform file
            match_field: Field name to match in S3 records
            batch_size: Number of records to process in each batch
            log_level: Logging level
            log_file: Path to log file
        """
        self.input_file = input_file
        self.s3_prefix = s3_prefix
        self.output_file = output_file
        self.id_field = id_field
        self.id_pattern = id_pattern
        self.file_pattern = file_pattern
        self.transform_expr = transform_expr
        self.transform_file = transform_file
        self.match_field = match_field
        self.batch_size = batch_size
        self.log_level = log_level
        self.log_file = log_file

        # Configure logging
        setup_logging(self.log_level, self.log_file, logger=log)

        # Initialize S3 client and timestamp
        self.s3_client = get_s3_client()
        self.timestamp = get_timestamp()

        # Compile regex pattern
        try:
            self.id_regex = re.compile(self.id_pattern)
        except re.error as e:
            log.error(f"Invalid ID pattern '{self.id_pattern}': {e}")
            sys.exit(1)

        # Compile JQ expression
        self._compile_jq_expressions()

        # Initialize file cache and statistics
        self.statistics = {
            "input_records": 0,
            "parsed_ids": 0,
            "found_records": 0,
            "files_loaded": 0,
        }

    def _compile_jq_expressions(self) -> None:
        """Compile JQ transformation expression."""
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

    def _parse_id(self, record_id: str) -> Optional[Dict[str, str]]:
        """
        Parse an ID to extract components for file lookup.

        Args:
            record_id: The record ID to parse

        Returns:
            Optional[Dict[str, str]]: Parsed components or None if parsing fails
        """
        match = self.id_regex.match(record_id)
        if not match:
            log.debug(f"ID '{record_id}' does not match pattern '{self.id_pattern}'")
            return None

        groups = match.groups()
        if len(groups) >= 2:
            return {
                "newspaper": groups[0],
                "year": groups[1],
                "content_id": groups[2] if len(groups) > 2 else "",
                "full_id": record_id,
            }
        return None

    def _get_file_key(self, parsed_id: Dict[str, str]) -> str:
        """
        Generate S3 file key from parsed ID components.

        Args:
            parsed_id: Parsed ID components

        Returns:
            str: S3 file key
        """
        bucket, prefix = parse_s3_path(self.s3_prefix)
        filename = self.file_pattern.format(**parsed_id)
        return f"{prefix.rstrip('/')}/{filename}"

    def _load_s3_file(self, bucket: str, file_key: str) -> Dict[str, Dict[str, Any]]:
        """
        Load an S3 file and return records indexed by match field.

        Args:
            bucket: S3 bucket name
            file_key: S3 file key

        Returns:
            Dict[str, Dict[str, Any]]: Records indexed by match field
        """
        records = {}
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
                        if self.match_field in record:
                            match_value = str(record[self.match_field])
                            records[match_value] = record
                    except json.JSONDecodeError:
                        log.warning(f"Skipping malformed line {line_num} in {file_key}")
                    except Exception as e:
                        log.debug(
                            f"Error processing line {line_num} in {file_key}: {e}"
                        )

            log.info(f"Loaded {len(records)} records from {file_key}")
            self.statistics["files_loaded"] += 1

        except Exception as e:
            log.warning(f"Failed to load file {file_key}: {e}")

        return records

    def _group_ids_by_file(self) -> Dict[str, List[str]]:
        """
        Read input file and group IDs by their target S3 files.

        Returns:
            Dict[str, List[str]]: Mapping from file keys to lists of IDs
        """
        file_to_ids = {}

        with smart_open(
            self.input_file,
            "r",
            encoding="utf-8",
            transport_params=get_transport_params(self.input_file),
        ) as infile:
            for line_num, line in enumerate(infile, 1):
                try:
                    input_record = json.loads(line)
                    self.statistics["input_records"] += 1

                    if self.id_field not in input_record:
                        log.warning(f"Line {line_num}: Missing '{self.id_field}' field")
                        continue

                    record_id = str(input_record[self.id_field])
                    parsed_id = self._parse_id(record_id)

                    if parsed_id is None:
                        continue

                    self.statistics["parsed_ids"] += 1
                    file_key = self._get_file_key(parsed_id)

                    if file_key not in file_to_ids:
                        file_to_ids[file_key] = []
                    file_to_ids[file_key].append(record_id)

                except json.JSONDecodeError:
                    log.warning(f"Skipping malformed line {line_num}")
                except Exception as e:
                    log.error(f"Error processing line {line_num}: {e}")

        log.info(
            f"Grouped {self.statistics['parsed_ids']} IDs into {len(file_to_ids)} files"
        )
        return file_to_ids

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

    def _upload_to_s3(self, local_path: str, s3_path: str) -> None:
        """Upload a local file to S3."""
        bucket, key = parse_s3_path(s3_path)
        self.s3_client.upload_file(local_path, bucket, key)
        log.info(f"Uploaded {local_path} to {s3_path}")

    def run(self) -> None:
        """Run the compilation process."""
        try:
            log.info(f"Starting compilation from {self.input_file}")
            log.info(f"Looking up records in {self.s3_prefix}")

            # Group IDs by their target files for efficient processing
            file_to_ids = self._group_ids_by_file()

            # Create temporary file for output
            suffix = self.output_file.split(".")[-1]
            with tempfile.NamedTemporaryFile(
                delete=False, mode="w", encoding="utf-8", suffix=f".{suffix}"
            ) as tmpfile:
                tmpfile_path = tmpfile.name
                log.info(f"Temporary file created: {tmpfile_path}")

                bucket, _ = parse_s3_path(self.s3_prefix)

                with smart_open(tmpfile_path, "w", encoding="utf-8") as outfile:
                    # Process each file only once
                    for file_key, id_list in file_to_ids.items():
                        log.info(f"Processing {file_key} for {len(id_list)} IDs")

                        # Check if file exists in S3
                        try:
                            self.s3_client.head_object(Bucket=bucket, Key=file_key)
                        except Exception:
                            log.warning(f"File {file_key} not found in S3")
                            continue

                        # Load file records
                        file_records = self._load_s3_file(bucket, file_key)

                        # Find and process matching records
                        for record_id in id_list:
                            if record_id in file_records:
                                found_record = file_records[record_id]
                                self.statistics["found_records"] += 1

                                # Apply transformation
                                transformed_record = self._apply_transform(found_record)
                                if transformed_record is not None:
                                    # Include original ID in output if not already there
                                    if self.id_field not in transformed_record:
                                        transformed_record[self.id_field] = record_id

                                    outfile.write(
                                        json.dumps(
                                            transformed_record, ensure_ascii=False
                                        )
                                        + "\n"
                                    )
                            else:
                                log.debug(
                                    f"Record '{record_id}' not found in {file_key}"
                                )

                # Upload to S3 or move to final location
                if self.output_file.startswith("s3://"):
                    self._upload_to_s3(tmpfile_path, self.output_file)
                else:
                    import shutil

                    shutil.move(tmpfile_path, self.output_file)
                    log.info(f"Moved {tmpfile_path} to {self.output_file}")

            # Log summary statistics
            log.info("Compilation complete:")
            log.info(f"  Input records processed: {self.statistics['input_records']}")
            log.info(f"  IDs successfully parsed: {self.statistics['parsed_ids']}")
            log.info(f"  Records found in S3: {self.statistics['found_records']}")
            log.info(f"  Files loaded from S3: {self.statistics['files_loaded']}")
            log.info(f"  Unique files processed: {len(file_to_ids)}")

            if self.statistics["input_records"] > 0:
                success_rate = (
                    self.statistics["found_records"] / self.statistics["input_records"]
                )
                log.info(f"  Success rate: {success_rate:.4f}")

            log.info(f"Results saved to {self.output_file}")

        except Exception as e:
            log.error(f"Error during compilation process: {e}", exc_info=True)
            sys.exit(1)
        """Run the compilation process."""
        try:
            log.info(f"Starting compilation from {self.input_file}")
            log.info(f"Looking up records in {self.s3_prefix}")

            # Create temporary file for output
            suffix = self.output_file.split(".")[-1]
            with tempfile.NamedTemporaryFile(
                delete=False, mode="w", encoding="utf-8", suffix=f".{suffix}"
            ) as tmpfile:
                tmpfile_path = tmpfile.name
                log.info(f"Temporary file created: {tmpfile_path}")

                with smart_open(tmpfile_path, "w", encoding="utf-8") as outfile:
                    # Read input file and process each ID
                    with smart_open(
                        self.input_file,
                        "r",
                        encoding="utf-8",
                        transport_params=get_transport_params(self.input_file),
                    ) as infile:
                        for line_num, line in enumerate(infile, 1):
                            try:
                                input_record = json.loads(line)
                                self.statistics["input_records"] += 1

                                if self.id_field not in input_record:
                                    log.warning(
                                        f"Line {line_num}: Missing '{self.id_field}'"
                                        " field"
                                    )
                                    continue

                                record_id = str(input_record[self.id_field])

                                # Find corresponding record in S3
                                found_record = self._find_record(record_id)
                                if found_record is None:
                                    log.debug(f"Record '{record_id}' not found")
                                    continue

                                # Apply transformation
                                transformed_record = self._apply_transform(found_record)
                                if transformed_record is not None:
                                    # Include ID in output if not already there
                                    if self.id_field not in transformed_record:
                                        transformed_record[self.id_field] = record_id

                                    outfile.write(
                                        json.dumps(
                                            transformed_record, ensure_ascii=False
                                        )
                                        + "\n"
                                    )

                            except json.JSONDecodeError:
                                log.warning(f"Skipping malformed line {line_num}")
                            except Exception as e:
                                log.error(f"Error processing line {line_num}: {e}")

                # Upload to S3 or move to final location
                if self.output_file.startswith("s3://"):
                    self._upload_to_s3(tmpfile_path, self.output_file)
                else:
                    import shutil

                    shutil.move(tmpfile_path, self.output_file)
                    log.info(f"Moved {tmpfile_path} to {self.output_file}")

            # Log summary statistics
            log.info("Compilation complete:")
            log.info(f"  Input records processed: {self.statistics['input_records']}")
            log.info(f"  IDs successfully parsed: {self.statistics['parsed_ids']}")
            log.info(f"  Records found in S3: {self.statistics['found_records']}")
            log.info(f"  Files loaded from S3: {self.statistics['files_loaded']}")
            log.info(f"  Cache hits: {self.statistics['cache_hits']}")
            log.info(f"  Cache misses: {self.statistics['cache_misses']}")

            if self.statistics["input_records"] > 0:
                success_rate = (
                    self.statistics["found_records"] / self.statistics["input_records"]
                )
                log.info(f"  Success rate: {success_rate:.4f}")

            log.info(f"Results saved to {self.output_file}")

        except Exception as e:
            log.error(f"Error during compilation process: {e}", exc_info=True)
            sys.exit(1)


def main(args: Optional[List[str]] = None) -> None:
    """
    Main function to run the S3 Compiler Processor.

    Args:
        args: Command-line arguments (uses sys.argv if None)
    """
    options: argparse.Namespace = parse_arguments(args)

    processor: S3CompilerProcessor = S3CompilerProcessor(
        input_file=options.input_file,
        s3_prefix=options.s3_prefix,
        output_file=options.output,
        id_field=options.id_field,
        id_pattern=options.id_pattern,
        file_pattern=options.file_pattern,
        transform_expr=options.transform_expr,
        transform_file=options.transform_file,
        match_field=options.match_field,
        batch_size=options.batch_size,
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
