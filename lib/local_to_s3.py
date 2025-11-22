"""
This module, `local_to_s3.py`, is a utility for uploading local files to S3 with 
work-in-progress (WIP) file management and concurrent processing prevention.

It imports functionality from the `impresso_cookbook` library and provides a
comprehensive interface for uploading multiple files to S3 with pairs of local_path
s3_path arguments, including advanced features for parallel processing workflows.

Key Features:
- S3 file existence checking with exit codes for makefile integration
- Work-in-progress (WIP) file management for preventing concurrent processing
- Automatic WIP file creation with hostname, IP address, username, and timestamp tracking
- Stale WIP file detection and cleanup based on configurable age limits
- File pair uploading with dependency management (data files + log files)
- Timestamp metadata extraction and setting for JSONL and other file types
- Local file truncation with timestamp preservation for space management
- Comprehensive logging and error handling for production workflows

WIP Workflow:
1. Check file existence: --s3-file-exists --wip --create-wip creates WIP if needed
2. Process files: Standard processing occurs while WIP file indicates work in progress  
3. Upload and cleanup: --remove-wip removes WIP files after successful upload

Usage Examples:
    # Check existence and create WIP (for makefile integration)
    python3 -m impresso_cookbook.local_to_s3 --s3-file-exists s3://bucket/file.txt.gz \\
        --wip --wip-max-age 2 --create-wip \\
        local1.txt.gz s3://bucket/file1.txt.gz local1.log.gz s3://bucket/file1.log.gz

    # Upload files and remove WIP
    python3 -m impresso_cookbook.local_to_s3 --remove-wip --set-timestamp \\
        --keep-timestamp-only --ts-key __file__ \\
        local1.txt.gz s3://bucket/file1.txt.gz local1.log.gz s3://bucket/file1.log.gz

    # Simple upload without WIP management
    python3 -m impresso_cookbook.local_to_s3 \\
        localpath1 s3path1 localpath2 s3path2 \\
        --force-overwrite --set-timestamp --keep-timestamp-only
"""

__author__ = "simon.clematide@uzh.ch"
__license__ = "GNU GPL 3.0 or later"

import argparse
import logging
import os
import sys
import time
import traceback
import socket
import json
import getpass
from datetime import datetime
from dotenv import load_dotenv

from impresso_cookbook import (
    get_s3_client,
    upload_with_retries,
    keep_timestamp_only,
    parse_s3_path,
    setup_logging,
    S3TimestampProcessor,
    s3_file_exists,
)

log = logging.getLogger(__name__)

load_dotenv()


def main():
    """Main function for uploading local files to S3."""
    parser = argparse.ArgumentParser(
        description=(
            "Upload local files to S3 with WIP management and concurrent processing"
            " prevention"
        ),
        epilog=(
            "Utility for uploading files to S3 with work-in-progress tracking, "
            "timestamp management, and makefile integration support."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "files",
        nargs="*",
        help="Pairs of local_path s3_path. Must be an even number of arguments.",
        metavar="PATH",
    )
    parser.add_argument(
        "--s3-file-exists",
        help="Check if S3 file exists and exit with code 0 if it does, 1 if not.",
        metavar="S3_PATH",
    )
    parser.add_argument(
        "--wip",
        action="store_true",
        help="Enable work-in-progress file checking.",
    )
    parser.add_argument(
        "--wip-max-age",
        type=float,
        default=24,
        help=(
            "Maximum age in hours for WIP files (default: %(default)s). "
            "Can be fractional (e.g., 0.1 for 6 minutes)."
        ),
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
    parser.add_argument(
        "--create-wip",
        action="store_true",
        help="Create a WIP file before processing to prevent concurrent execution.",
    )
    parser.add_argument(
        "--remove-wip",
        action="store_true",
        help="Remove WIP files after successful upload.",
    )
    parser.add_argument(
        "--forbid-extensions",
        nargs="+",
        default=[".stamp", ".last_synced"],
        help=(
            "File extensions that should never be uploaded to S3 "
            "(default: %(default)s). Prevents accidental stamp file uploads."
        ),
    )

    args = parser.parse_args()

    # Set up logging using common.py
    setup_logging(args.log_level, args.log_file, logger=log)

    # Handle --s3-file-exists option
    if args.s3_file_exists:
        try:
            s3_client = get_s3_client()
            # Use s3_file_exists from common.py
            exists = s3_file_exists(s3_client, args.s3_file_exists)
            if exists:
                log.info("S3 file exists: %s", args.s3_file_exists)
                sys.exit(0)
            # WIP file management (still needs direct S3 ops, but use parse_s3_path)
            if args.wip:
                wip_path = args.s3_file_exists + ".wip"
                bucket, key = parse_s3_path(wip_path)
                try:
                    response = s3_client.head_object(Bucket=bucket, Key=key)
                    wip_modified = response["LastModified"]
                    from datetime import timezone

                    now = datetime.now(timezone.utc)
                    age_hours = (now - wip_modified).total_seconds() / 3600
                    if age_hours > args.wip_max_age:
                        log.info(
                            "Stale WIP file found (%.1f hours old), removing: %s",
                            age_hours,
                            wip_path,
                        )
                        s3_client.delete_object(Bucket=bucket, Key=key)
                        log.info("S3 file does not exist: %s", args.s3_file_exists)
                    else:
                        log.info(
                            "WIP file in progress (%.1f hours old): %s",
                            age_hours,
                            wip_path,
                        )
                        try:
                            wip_obj = s3_client.get_object(Bucket=bucket, Key=key)
                            wip_content = wip_obj["Body"].read().decode("utf-8")
                            wip_info = json.loads(wip_content)
                            log.info(
                                "WIP file being processed by user: %s on host: %s (%s)",
                                wip_info.get("username", "unknown"),
                                wip_info.get("hostname", "unknown"),
                                wip_info.get("ip_address", "unknown"),
                            )
                        except Exception as e:
                            log.debug("Could not read WIP file content: %s", e)
                        # Exit 2 to signal WIP exists - Make should skip processing
                        sys.exit(2)
                except s3_client.exceptions.NoSuchKey:
                    # No WIP file exists - this is normal, continue
                    log.debug(
                        "No WIP file found at %s, processing can proceed", wip_path
                    )
                except Exception as e:
                    # Only log warning for unexpected errors (not 404/NoSuchKey)
                    if "404" not in str(e) and "NoSuchKey" not in str(e):
                        log.warning("Error checking WIP file %s: %s", wip_path, e)
                    else:
                        log.debug(
                            "No WIP file found at %s (404), processing can proceed",
                            wip_path,
                        )
            # If --create-wip is used during file existence check, create WIP
            # and exit 1 to proceed
            if args.create_wip and args.files:
                hostname = socket.gethostname()
                try:
                    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    s.connect(("8.8.8.8", 80))
                    ip_address = s.getsockname()[0]
                    s.close()
                except Exception:
                    ip_address = "127.0.0.1"
                wip_info = {
                    "hostname": hostname,
                    "ip_address": ip_address,
                    "username": getpass.getuser(),
                    "start_time": datetime.now().isoformat(),
                    "pid": os.getpid(),
                    "files": args.files,
                }
                file_pairs = [
                    (args.files[i], args.files[i + 1])
                    for i in range(0, len(args.files), 2)
                ]
                for local_path, s3_path in file_pairs:
                    if local_path.endswith((".txt.gz", ".jsonl.bz2")):
                        wip_path = s3_path + ".wip"
                        wip_content = json.dumps(wip_info, indent=2)
                        bucket, key = parse_s3_path(wip_path)
                        try:
                            s3_client.put_object(
                                Bucket=bucket,
                                Key=key,
                                Body=wip_content.encode("utf-8"),
                                ContentType="application/json",
                            )
                            log.info(
                                "Created WIP file during existence check: %s (host: %s,"
                                " IP: %s, user: %s)",
                                wip_path,
                                hostname,
                                ip_address,
                                getpass.getuser(),
                            )
                        except Exception as e:
                            log.error("Failed to create WIP file %s: %s", wip_path, e)
                # When WIP is created successfully, exit 0 to allow make to continue
                log.info(
                    "S3 file does not exist: %s, WIP created, continuing",
                    args.s3_file_exists,
                )
                sys.exit(0)
            # S3 file doesn't exist and no WIP was created
            # Exit to let processing proceed
            log.info("S3 file does not exist: %s", args.s3_file_exists)
            sys.exit(1)
        except Exception as e:
            log.error("Error checking S3 file existence: %s", e)
            sys.exit(1)

    # When --s3-file-exists is not provided, we proceed to upload files
    # Validate that we have pairs of arguments
    if not args.files:
        log.error("No file pairs provided for upload")
        sys.exit(1)

    if len(args.files) % 2 != 0:
        log.error(
            "Arguments must be pairs of local_path s3_path. Got %d arguments.",
            len(args.files),
        )
        sys.exit(1)

    log.info("Arguments: %s", args)

    try:
        s3_client = get_s3_client()
        # Create WIP files if requested (only when NOT doing existence check)
        if args.create_wip and args.files and not args.s3_file_exists:
            hostname = socket.gethostname()
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.connect(("8.8.8.8", 80))
                ip_address = s.getsockname()[0]
                s.close()
            except Exception:
                ip_address = "127.0.0.1"
            wip_info = {
                "hostname": hostname,
                "ip_address": ip_address,
                "username": getpass.getuser(),
                "start_time": datetime.now().isoformat(),
                "pid": os.getpid(),
                "files": args.files,
            }
            file_pairs = [
                (args.files[i], args.files[i + 1]) for i in range(0, len(args.files), 2)
            ]
            for local_path, s3_path in file_pairs:
                if local_path.endswith((".txt.gz", ".jsonl.bz2")):
                    wip_path = s3_path + ".wip"
                    wip_content = json.dumps(wip_info, indent=2)
                    bucket, key = parse_s3_path(wip_path)
                    try:
                        s3_client.put_object(
                            Bucket=bucket,
                            Key=key,
                            Body=wip_content.encode("utf-8"),
                            ContentType="application/json",
                        )
                        log.info(
                            "Created WIP file: %s (host: %s, IP: %s, user: %s)",
                            wip_path,
                            hostname,
                            ip_address,
                            getpass.getuser(),
                        )
                    except Exception as e:
                        log.error("Failed to create WIP file %s: %s", wip_path, e)
        file_pairs = [
            (args.files[i], args.files[i + 1]) for i in range(0, len(args.files), 2)
        ]
        log.info("Uploading %d file pair(s) to S3", len(file_pairs))
        for local_path, s3_path in file_pairs:
            # Check for forbidden file extensions (stamp files, sync markers)
            if any(local_path.endswith(ext) for ext in args.forbid_extensions):
                log.error(
                    "FATAL: Attempted to upload forbidden file type: %s "
                    "(matches forbidden extensions: %s). "
                    "Stamp files and sync markers should never be uploaded to S3.",
                    local_path,
                    args.forbid_extensions,
                )
                sys.exit(1)

            # Check file existence and size before upload
            if not os.path.exists(local_path):
                log.error(
                    "FATAL: File not found: %s. Cannot proceed with upload.",
                    local_path,
                )
                sys.exit(1)
            if os.path.getsize(local_path) == 0:
                log.error(
                    "FATAL: File is empty (0 bytes): %s. "
                    "Empty files indicate a processing failure and should not be "
                    "uploaded.",
                    local_path,
                )
                sys.exit(1)
            log.info("Uploading file: %s to %s", local_path, s3_path)

            # Check if file exists if not force_overwrite
            if not args.force_overwrite:
                bucket, key = parse_s3_path(s3_path)
                if s3_file_exists(s3_client, bucket, key):
                    log.warning(
                        "File %s already exists and --force-overwrite not set."
                        " Skipping.",
                        s3_path,
                    )
                    continue

            # Use upload_with_retries for robust uploads (same as s3_to_local_stamps.py)
            uploaded = upload_with_retries(
                s3_client,
                local_path,
                s3_path,
            )
            if not uploaded:
                log.error(
                    f"Upload failed for {local_path} to {s3_path}. Skipping further"
                    " actions for this file."
                )
                continue
            if args.keep_timestamp_only and local_path.endswith(".jsonl.bz2"):
                log.info(
                    "Truncating %s and keeping only timestamp after successful upload",
                    local_path,
                )
                keep_timestamp_only(local_path)
        log.info("All uploads completed successfully")
        # Clean up WIP files after successful upload
        if args.remove_wip:
            for local_path, s3_path in file_pairs:
                if local_path.endswith((".txt.gz", ".jsonl.bz2")):
                    wip_path = s3_path + ".wip"
                    bucket, key = parse_s3_path(wip_path)
                    try:
                        s3_client.delete_object(Bucket=bucket, Key=key)
                        log.info("Removed WIP file: %s", wip_path)
                    except Exception as e:
                        log.warning("Failed to remove WIP file %s: %s", wip_path, e)
        # Set timestamps on S3 files if requested
        if args.set_timestamp:
            log.info("Setting timestamps on S3 files")
            file_mtimes = {}
            for local_path, s3_path in file_pairs:
                if os.path.exists(local_path):
                    file_mtimes[local_path] = os.path.getmtime(local_path)
            for local_path, s3_path in file_pairs:
                log.info("Processing timestamp for: %s", s3_path)
                try:
                    if (
                        local_path.endswith((".jsonl.bz2", ".json"))
                        and args.ts_key != "__file__"
                    ):
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
                        if local_path in file_mtimes:
                            file_mtime = file_mtimes[local_path]
                        else:
                            file_mtime = time.time()
                        file_timestamp = datetime.fromtimestamp(file_mtime).strftime(
                            "%Y-%m-%dT%H:%M:%SZ"
                        )
                        log.info(
                            "Using file modification date %s for %s",
                            file_timestamp,
                            s3_path,
                        )
                        bucket, key = parse_s3_path(s3_path)
                        try:
                            existing_obj = s3_client.head_object(Bucket=bucket, Key=key)
                            existing_metadata = existing_obj.get("Metadata", {})
                        except Exception:
                            existing_metadata = {}
                        new_metadata = existing_metadata.copy()
                        new_metadata[args.metadata_key] = file_timestamp
                        s3_client.copy_object(
                            Bucket=bucket,
                            Key=key,
                            CopySource={"Bucket": bucket, "Key": key},
                            Metadata=new_metadata,
                            MetadataDirective="REPLACE",
                        )
                        try:
                            updated_obj = s3_client.head_object(Bucket=bucket, Key=key)
                            updated_metadata = updated_obj.get("Metadata", {})
                            if args.metadata_key in updated_metadata:
                                log.info(
                                    "Successfully set file timestamp metadata for %s:"
                                    " %s = %s",
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
            log.info("Timestamp setting completed")
    except Exception as e:
        log.error("An error occurred: %s", e)
        log.error("Traceback: %s", traceback.format_exc())
        sys.exit(1)


if __name__ == "__main__":
    main()
