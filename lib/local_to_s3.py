"""
This module, `local_to_s3.py`, is a utility for uploading local files to S3.

It imports functionality from the `impresso_cookbook` library and provides a
simple interface for uploading multiple files to S3 with pairs of local_path
s3_path arguments.

Usage:
    python local_to_s3.py localpath1 s3path1 [localpath2 s3path2 ...] \\
        [--force-overwrite] [--set-timestamp] [--keep-timestamp-only]
"""

__author__ = "simon.clematide@uzh.ch"
__license__ = "GNU GPL 3.0 or later"

import argparse
import logging
import os
import sys
import time
import traceback
from datetime import datetime
from dotenv import load_dotenv

from impresso_cookbook import (
    get_s3_client,
    upload_file_to_s3,
    keep_timestamp_only,
    parse_s3_path,
    setup_logging,
    S3TimestampProcessor,
)

log = logging.getLogger(__name__)

load_dotenv()


def main():
    """Main function for uploading local files to S3."""
    parser = argparse.ArgumentParser(
        description="Upload local files to S3",
        epilog="Utility to upload multiple local files to S3 destinations.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "files",
        nargs="+",
        help="Pairs of local_path s3_path. Must be an even number of arguments.",
        metavar="PATH",
    )
    parser.add_argument(
        "--force-overwrite",
        action="store_true",
        help="Overwrite files on S3 even if they already exist.",
    )
    parser.add_argument(
        "--keep-timestamp-only",
        action="store_true",
        help=(
            "Truncate local *.jsonl.bz2 files to zero length and keep only timestamp"
            " after successful upload."
        ),
    )
    parser.add_argument(
        "--set-timestamp",
        action="store_true",
        help=(
            "Automatically set impresso timestamp metadata after successful upload "
            "of *.jsonl.bz2 files."
        ),
    )
    parser.add_argument(
        "--ts-key",
        default="ts",
        choices=["ts", "cdt", "__file__"],
        help=(
            "Timestamp key to extract from JSONL records or '__file__' to use file"
            " modification date (default: %(default)s)."
        ),
    )
    parser.add_argument(
        "--metadata-key",
        default="impresso-last-ts",
        help="S3 metadata key for timestamp (default: %(default)s).",
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

    args = parser.parse_args()

    # Set up logging using impresso_cookbook
    setup_logging(args.log_level, args.log_file, logger=log)

    # Validate that we have pairs of arguments
    if len(args.files) % 2 != 0:
        log.error(
            "Arguments must be pairs of local_path s3_path. Got %d arguments.",
            len(args.files),
        )
        sys.exit(1)

    log.info("Arguments: %s", args)

    try:
        # Get S3 client
        s3_client = get_s3_client()

        # Process pairs of local_path s3_path
        file_pairs = [
            (args.files[i], args.files[i + 1]) for i in range(0, len(args.files), 2)
        ]

        log.info("Uploading %d file pair(s) to S3", len(file_pairs))

        for local_path, s3_path in file_pairs:
            # Check if this is actually a pair of files (e.g., data file + log file)
            # If we have more than one pair, treat as pairs where second depends on first
            if len(file_pairs) > 1 and file_pairs.index((local_path, s3_path)) % 2 == 0:
                # This is the first file of a pair
                log.info("Uploading first file of pair: %s to %s", local_path, s3_path)
                first_file_uploaded = upload_file_to_s3(
                    s3_client,
                    local_path,
                    s3_path,
                    args.force_overwrite,
                )

                # Only upload the second file if the first was successful
                if first_file_uploaded and file_pairs.index(
                    (local_path, s3_path)
                ) + 1 < len(file_pairs):
                    next_local, next_s3 = file_pairs[
                        file_pairs.index((local_path, s3_path)) + 1
                    ]
                    log.info(
                        "First file uploaded successfully, now uploading second file:"
                        " %s to %s",
                        next_local,
                        next_s3,
                    )
                    upload_file_to_s3(
                        s3_client,
                        next_local,
                        next_s3,
                        True,  # Force overwrite the second file (log file)
                    )
                elif not first_file_uploaded and file_pairs.index(
                    (local_path, s3_path)
                ) + 1 < len(file_pairs):
                    next_local, next_s3 = file_pairs[
                        file_pairs.index((local_path, s3_path)) + 1
                    ]
                    log.info(
                        "First file was not uploaded, skipping second file: %s",
                        next_local,
                    )
            elif (
                len(file_pairs) > 1 and file_pairs.index((local_path, s3_path)) % 2 == 1
            ):
                # This is the second file of a pair, already handled above
                continue
            else:
                # Single file or odd number of files
                log.info("Uploading single file: %s to %s", local_path, s3_path)
                first_file_uploaded = upload_file_to_s3(
                    s3_client,
                    local_path,
                    s3_path,
                    args.force_overwrite,
                )

            # Handle --keep-timestamp-only option for *.jsonl.bz2 files
            if (
                first_file_uploaded
                and args.keep_timestamp_only
                and local_path.endswith(".jsonl.bz2")
            ):
                log.info(
                    "Truncating %s and keeping only timestamp after successful upload",
                    local_path,
                )
                keep_timestamp_only(local_path)

        log.info("All uploads completed successfully")

        # Set timestamps on S3 files if requested
        if args.set_timestamp:
            log.info("Setting timestamps on S3 files")

            # Collect file modification times BEFORE any potential truncation
            file_mtimes = {}
            for local_path, s3_path in file_pairs:
                if os.path.exists(local_path):
                    file_mtimes[local_path] = os.path.getmtime(local_path)
                    log.debug(
                        "Collected mtime for %s: %f",
                        local_path,
                        file_mtimes[local_path],
                    )

            for local_path, s3_path in file_pairs:
                log.info("Processing timestamp for: %s", s3_path)
                try:
                    # For JSON(L) files, we can extract timestamp from content
                    if (
                        local_path.endswith((".jsonl.bz2", ".json"))
                        and args.ts_key != "__file__"
                    ):
                        # Use existing JSONL timestamp extraction logic
                        timestamp_processor = S3TimestampProcessor(
                            s3_file=s3_path,
                            metadata_key=args.metadata_key,
                            ts_key=args.ts_key,
                            all_lines=False,
                            force=True,
                            log_level=args.log_level,
                            log_file=args.log_file,
                        )
                        timestamp_processor.update_metadata_for_file()
                        log.info("Successfully set timestamp for %s", s3_path)
                    else:
                        # For all other files, or if __file__ is specified, use mtime
                        # Use pre-collected file modification time
                        if local_path in file_mtimes:
                            file_mtime = file_mtimes[local_path]
                            log.debug(
                                "Using collected mtime for %s: %f",
                                local_path,
                                file_mtime,
                            )
                        else:
                            # Fallback to current time if file doesn't exist
                            file_mtime = time.time()
                            log.warning(
                                "File %s not found, using current time: %f",
                                local_path,
                                file_mtime,
                            )

                        file_timestamp = datetime.fromtimestamp(file_mtime).strftime(
                            "%Y-%m-%dT%H:%M:%SZ"
                        )

                        log.info(
                            "Using file modification date %s for %s",
                            file_timestamp,
                            s3_path,
                        )

                        bucket, key = parse_s3_path(s3_path)

                        # Get existing metadata first
                        try:
                            existing_obj = s3_client.head_object(Bucket=bucket, Key=key)
                            existing_metadata = existing_obj.get("Metadata", {})
                            log.debug(
                                "Existing metadata for %s: %s",
                                s3_path,
                                existing_metadata,
                            )
                        except Exception as e:
                            log.warning(
                                "Could not get existing metadata for %s: %s",
                                s3_path,
                                e,
                            )
                            existing_metadata = {}

                        # Add our timestamp to existing metadata
                        new_metadata = existing_metadata.copy()
                        new_metadata[args.metadata_key] = file_timestamp

                        log.info(
                            "Setting metadata: %s = %s",
                            args.metadata_key,
                            file_timestamp,
                        )
                        log.debug("Complete metadata to set: %s", new_metadata)

                        # Copy object to itself with new metadata
                        s3_client.copy_object(
                            Bucket=bucket,
                            Key=key,
                            CopySource={"Bucket": bucket, "Key": key},
                            Metadata=new_metadata,
                            MetadataDirective="REPLACE",
                        )

                        # Verify the metadata was set
                        try:
                            updated_obj = s3_client.head_object(Bucket=bucket, Key=key)
                            updated_metadata = updated_obj.get("Metadata", {})
                            if args.metadata_key in updated_metadata:
                                log.info(
                                    "Successfully set file timestamp metadata for"
                                    " %s: %s = %s",
                                    s3_path,
                                    args.metadata_key,
                                    updated_metadata[args.metadata_key],
                                )
                            else:
                                log.error(
                                    "Metadata key %s not found after setting for %s",
                                    args.metadata_key,
                                    s3_path,
                                )
                        except Exception as e:
                            log.error(
                                "Could not verify metadata for %s: %s", s3_path, e
                            )

                except Exception as e:
                    log.error("Failed to set timestamp for %s: %s", s3_path, e)
                    log.debug("Full exception traceback:", exc_info=True)
            log.info("Timestamp setting completed")

    except Exception as e:
        log.error("An error occurred: %s", e)
        log.error("Traceback: %s", traceback.format_exc())
        sys.exit(1)


if __name__ == "__main__":
    main()
