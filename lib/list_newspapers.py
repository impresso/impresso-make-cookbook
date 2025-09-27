#!/usr/bin/env python3
"""
List newspapers from an S3 bucket with optional size-aware ordering.

This script connects to an S3-compatible endpoint (default: Switch cloud) and lists
top-level newspaper prefixes from a specified bucket. It can optionally group newspapers
by the number of available years and order them from largest to smallest groups.

Features:
- Loads credentials from environment variables (SE_ACCESS_KEY, SE_SECRET_KEY) or .env file
- Lists newspaper identifiers as space-separated output (compatible with Makefile usage)
- Counts years per newspaper by scanning for files matching pattern: NEWSPAPER-YYYY.jsonl.bz2
- Optional size-aware grouping with configurable number of groups
- Randomization within groups for load balancing

Grouping behavior (--large-first):
- Newspapers are grouped by number of available years using quantile-based thresholds
- Groups are ordered from largest to smallest (e.g., newspapers with most years first)
- Within each group, newspapers are randomly shuffled
- Number of groups is configurable via --num-groups (default: 3)

Examples:
  # Simple random shuffle of all newspapers
  python list_newspapers.py --bucket 22-rebuilt-final

  # Group into 3 size categories, largest first
  python list_newspapers.py --bucket 22-rebuilt-final --large-first --seed 42

  # Group into 5 size categories with custom endpoint
  python list_newspapers.py --bucket my-bucket --large-first --num-groups 5 \\
    --endpoint https://my-s3.example.com/

  # Debug mode with detailed grouping information
  python list_newspapers.py --bucket 22-rebuilt-final --large-first \\
    --log-level DEBUG --num-groups 4
"""

import argparse
import logging
import os
import random
import re
import sys
from typing import Dict, Iterable, List, Tuple

import boto3
from botocore.client import BaseClient
from dotenv import load_dotenv

DEFAULT_ENDPOINT = "https://os.zhdk.cloud.switch.ch/"
YEAR_RE = re.compile(r".*-(\d{4})\.jsonl\.bz2$")


def get_s3_client(endpoint_url: str) -> BaseClient:
    load_dotenv()
    secret = os.getenv("SE_SECRET_KEY")
    access = os.getenv("SE_ACCESS_KEY")

    assert (
        secret is not None
    ), "SE_SECRET_KEY environment variable is not set. Please FIX!"
    assert (
        access is not None
    ), "SE_ACCESS_KEY environment variable is not set. Please FIX!"

    return boto3.client(
        "s3",
        aws_secret_access_key=secret,
        aws_access_key_id=access,
        endpoint_url=endpoint_url,
    )


def list_common_prefixes(
    client: BaseClient, bucket: str, prefix: str = "", delimiter: str = "/"
) -> List[str]:
    """List immediate child 'directories' (CommonPrefixes) under the given prefix."""
    prefixes: List[str] = []
    kwargs = {"Bucket": bucket, "Delimiter": delimiter}
    if prefix:
        kwargs["Prefix"] = prefix

    while True:
        resp = client.list_objects_v2(**kwargs)
        prefixes.extend(p["Prefix"] for p in resp.get("CommonPrefixes", []))
        if not resp.get("IsTruncated"):
            break
        kwargs["ContinuationToken"] = resp.get("NextContinuationToken")
    return prefixes


def extract_years_from_objects(objects: Iterable[str]) -> List[int]:
    """Extract 4-digit years from a list of S3 object keys (files)."""
    years: List[int] = []
    for obj_key in objects:
        m = YEAR_RE.search(obj_key)
        if not m:
            continue
        y = int(m.group(1))
        if 1600 <= y <= 2100:
            years.append(y)
    return years


def count_year_files(client: BaseClient, bucket: str, newspaper_prefix: str) -> int:
    """Count files that look like newspaper-year.jsonl.bz2 under a newspaper."""
    objects: List[str] = []
    kwargs = {"Bucket": bucket, "Prefix": newspaper_prefix}

    while True:
        resp = client.list_objects_v2(**kwargs)
        objects.extend(obj["Key"] for obj in resp.get("Contents", []))
        if not resp.get("IsTruncated"):
            break
        kwargs["ContinuationToken"] = resp.get("NextContinuationToken")

    years = extract_years_from_objects(objects)
    logging.debug(
        "Newspaper %s: found %d objects, %d unique years: %s",
        newspaper_prefix,
        len(objects),
        len(set(years)),
        sorted(set(years)),
    )
    return len(set(years))


def compute_group_thresholds(counts: List[int], num_groups: int) -> List[int]:
    """
    Compute thresholds to split counts into num_groups groups.
    Returns num_groups-1 thresholds based on quantiles.
    """
    if not counts or num_groups <= 1:
        return []

    sc = sorted(counts)
    thresholds = []

    for i in range(1, num_groups):
        quantile = i / num_groups
        idx = max(0, int((len(sc) - 1) * quantile))
        thresholds.append(sc[idx])

    return thresholds


def order_newspapers(
    newspapers: List[str],
    years_per_np: Dict[str, int],
    large_first: bool,
    num_groups: int,
    rng: random.Random,
) -> List[str]:
    if not large_first:
        shuffled = newspapers[:]
        rng.shuffle(shuffled)
        return shuffled

    # Group by size using quantiles
    counts = [years_per_np.get(n, 0) for n in newspapers]
    thresholds = compute_group_thresholds(counts, num_groups)

    # Create groups (largest to smallest)
    groups: List[List[str]] = [[] for _ in range(num_groups)]

    for n in newspapers:
        c = years_per_np.get(n, 0)
        group_idx = num_groups - 1  # Default to largest group

        # Find which group this newspaper belongs to
        for i, threshold in enumerate(thresholds):
            if c <= threshold:
                group_idx = i
                break

        groups[group_idx].append(n)

    # Shuffle within each group and concatenate (largest first)
    result = []
    for group in reversed(groups):  # Reverse to get largest first
        rng.shuffle(group)
        result.extend(group)

    return result


def main():
    parser = argparse.ArgumentParser(
        description="List newspapers from S3 with optional size-aware shuffling."
    )
    parser.add_argument(
        "--bucket", required=True, help="S3 bucket name (e.g., 22-rebuilt-final)"
    )
    parser.add_argument(
        "--prefix",
        default="",
        help="Optional root prefix under the bucket (default: empty)",
    )
    parser.add_argument(
        "--endpoint",
        default=DEFAULT_ENDPOINT,
        help=f"S3 endpoint URL (default: {DEFAULT_ENDPOINT})",
    )
    parser.add_argument(
        "--large-first",
        action="store_true",
        help="Shuffle within size groups (large→medium→small)",
    )
    parser.add_argument(
        "--num-groups",
        type=int,
        default=3,
        help="Number of size groups when using --large-first (default: %(default)s)",
    )
    parser.add_argument(
        "--seed", type=int, default=None, help="Random seed for reproducibility"
    )
    parser.add_argument(
        "--log-level", choices=["DEBUG", "INFO", "WARNING", "ERROR"], default="INFO"
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=getattr(logging, args.log_level), format="%(levelname)s: %(message)s"
    )
    rng = random.Random(args.seed)

    try:
        client = get_s3_client(args.endpoint)
        logging.info("Connected to S3 endpoint: %s", args.endpoint)

        # List top-level newspaper prefixes
        root_prefixes = list_common_prefixes(
            client, args.bucket, prefix=args.prefix, delimiter="/"
        )
        logging.info(
            "Found %d top-level prefixes in bucket %s", len(root_prefixes), args.bucket
        )

        # Normalize to leaf newspaper identifiers (strip parent prefix and trailing slash)
        newspapers: List[str] = []
        for p in root_prefixes:
            leaf = (
                p[len(args.prefix) :]
                if args.prefix and p.startswith(args.prefix)
                else p
            )
            leaf = leaf[:-1] if leaf.endswith("/") else leaf
            if leaf:  # avoid empty strings
                newspapers.append(leaf)

        logging.info(
            "Extracted %d newspaper identifiers: %s",
            len(newspapers),
            newspapers[:10] + (["..."] if len(newspapers) > 10 else []),
        )

        if not newspapers:
            logging.warning("No newspapers found")
            print("", end="")
            return

        # Build years-per-newspaper map
        years_per_np: Dict[str, int] = {}
        logging.info("Counting years for each newspaper...")
        for n in newspapers:
            np_prefix = f"{args.prefix}{n}/" if args.prefix else f"{n}/"
            try:
                year_count = count_year_files(client, args.bucket, np_prefix)
                years_per_np[n] = year_count
                logging.info("Newspaper %s: %d years", n, year_count)
            except Exception as e:
                logging.warning("Failed to count years for %s: %s", n, e)
                years_per_np[n] = 0

        if args.large_first:
            counts = [years_per_np.get(n, 0) for n in newspapers]
            thresholds = compute_group_thresholds(counts, args.num_groups)
            logging.info(
                "Year count distribution: min=%d, max=%d, thresholds=%s",
                min(counts),
                max(counts),
                thresholds,
            )

            # Count newspapers in each group for diagnostics
            groups: List[List[str]] = [[] for _ in range(args.num_groups)]
            for n in newspapers:
                c = years_per_np.get(n, 0)
                group_idx = args.num_groups - 1
                for i, threshold in enumerate(thresholds):
                    if c <= threshold:
                        group_idx = i
                        break
                groups[group_idx].append(n)

            for i, group in enumerate(groups):
                group_name = (
                    f"Group {i+1}"
                    if i < args.num_groups - 1
                    else f"Group {i+1} (largest)"
                )
                if thresholds:
                    if i == 0:
                        range_desc = f"≤{thresholds[0]} years"
                    elif i == len(thresholds):
                        range_desc = f">{thresholds[-1]} years"
                    else:
                        range_desc = f"{thresholds[i-1]+1}-{thresholds[i]} years"
                else:
                    range_desc = "all years"
                logging.info(
                    "%s (%s): %d newspapers: %s",
                    group_name,
                    range_desc,
                    len(group),
                    group,
                )

        ordered = order_newspapers(
            newspapers, years_per_np, args.large_first, args.num_groups, rng
        )
        logging.info("Final order: %s", ordered)

        # Print space-separated, matching original Makefile behavior
        print(*ordered)

    except Exception as e:
        logging.error("Error: %s", e)
        sys.exit(1)


if __name__ == "__main__":
    main()
