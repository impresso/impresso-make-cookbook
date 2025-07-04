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

from impresso_cookbook import get_s3_client, upload_file_to_s3

log = logging.getLogger(__name__)


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
        "--level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        help="Set the logging level. Default: %(default)s",
    )
    parser.add_argument("--logfile", help="Write log to FILE", metavar="FILE")

    args = parser.parse_args()

    # Validate that we have pairs of arguments
    if len(args.files) % 2 != 0:
        log.error(
            "Arguments must be pairs of local_path s3_path. Got %d arguments.",
            len(args.files),
        )
        sys.exit(1)

    # Set up logging
    to_logging_level = {
        "CRITICAL": logging.CRITICAL,
        "ERROR": logging.ERROR,
        "WARNING": logging.WARNING,
        "INFO": logging.INFO,
        "DEBUG": logging.DEBUG,
    }

    logging_config = {
        "level": to_logging_level[args.level],
        "format": "%(asctime)-15s %(filename)s:%(lineno)d %(levelname)s: %(message)s",
        "force": True,
    }

    if args.logfile:
        logging_config["filename"] = args.logfile

    logging.basicConfig(**logging_config)

    log.info("Arguments: %s", args)

    try:
        # Get S3 client
        s3_client = get_s3_client()

        # Process pairs of local_path s3_path
        file_pairs = [
            (args.files[i], args.files[i + 1]) for i in range(0, len(args.files), 2)
        ]

        log.info("Uploading %d file(s) to S3", len(file_pairs))

        for local_path, s3_path in file_pairs:
            log.info("Uploading %s to %s", local_path, s3_path)
            upload_file_to_s3(
                s3_client,
                local_path,
                s3_path,
                args.force_overwrite,
            )

        log.info("All uploads completed successfully")

    except Exception as e:
        print(f"An error occurred: {e}", file=sys.stderr)
        log.error("Traceback: %s", traceback.format_exc())
        sys.exit(1)


if __name__ == "__main__":
    main()
