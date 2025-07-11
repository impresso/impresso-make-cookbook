"""
This module, `local_to_s3.py`, is a utility for uploading local files to S3.

It imports functionality from s3_to_local_stamps.py and provides a simple interface
for uploading multiple files to S3 with pairs of local_path s3_path arguments.

Usage:
    python local_to_s3.py localpath1 s3path1 localpath2 s3path2 ... [--force-overwrite]
"""

__author__ = "simon.clematide@uzh.ch"
__license__ = "GNU GPL 3.0 or later"

import argparse
import logging

import sys
import traceback
from dotenv import load_dotenv

from impresso_cookbook import get_s3_client, upload_file_to_s3, keep_timestamp_only, setup_logging  # type: ignore

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
            # If we have an even number of arguments, treat as pairs where second depends on first
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

    except Exception as e:
        log.error("An error occurred: %s", e)
        log.error("Traceback: %s", traceback.format_exc())
        sys.exit(1)


if __name__ == "__main__":
    main()
