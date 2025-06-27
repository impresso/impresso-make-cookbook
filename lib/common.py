"""Common utility functions for S3 and local file operations in the cookbook.

This module provides shared utilities for handling logging configuration and file
operations that work seamlessly with both local files and S3 objects using smart_open.
"""

import smart_open
import logging
from typing import Optional, List


def setup_logging(log_level: str, log_file: Optional[str], force: bool = False) -> None:
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

    Returns:
        None

    Example:
        >>> setup_logging('INFO', 'logs/app.log')
        >>> setup_logging('DEBUG', 's3://bucket/logs/debug.log', force=True)
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

    logging.basicConfig(
        level=log_level,
        format="%(asctime)-15s %(filename)s:%(lineno)d %(levelname)s: %(message)s",
        handlers=handlers,
        force=force,
    )
