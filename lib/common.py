"""Common utility functions for S3 and local file operations in the cookbook"""

import smart_open
import logging
from typing import Optional, List


def setup_logging(log_level: str, log_file: Optional[str]) -> None:
    """Configure logging.

    Args:
        log_level: Logging level as a string
        log_file: Path to the log file
    """

    class SmartFileHandler(logging.FileHandler):
        def _open(self):
            return smart_open(self.baseFilename, self.mode, encoding="utf-8")

    handlers: List[logging.Handler] = [logging.StreamHandler()]
    if log_file:
        handlers.append(SmartFileHandler(log_file, mode="w"))

    logging.basicConfig(
        level=log_level,
        format="%(asctime)-15s %(filename)s:%(lineno)d %(levelname)s: %(message)s",
        handlers=handlers,
        force=True,
    )
