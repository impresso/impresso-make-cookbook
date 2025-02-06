$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing.mk)

###############################################################################
# Processing Configuration
# User-configurable settings for processing output behavior.
#
# This file defines options to control processing behavior, particularly when
# interacting with S3 storage.
###############################################################################


# USER-VARIABLE: PROCESSING_S3_OUTPUT_DRY_RUN
# Prevents any output to S3 even if an S3 output path is set.
#
# This option ensures that no files are uploaded to S3. It is useful for testing
# and debugging purposes to verify local output without actual S3 writes.
PROCESSING_S3_OUTPUT_DRY_RUN ?= --s3-output-dry-run
# To disable the dry-run mode, comment the line above and uncomment the line below.
# PROCESSING_S3_OUTPUT_DRY_RUN ?=

  $(call log.debug, PROCESSING_S3_OUTPUT_DRY_RUN)


# USER-VARIABLE: PROCESSING_KEEP_TIMESTAMP_ONLY_OPTION
# Keeps only the local timestamp output files after uploading to S3.
#
# This option helps in cleaning up the local filesystem by retaining only files
# with timestamps while removing other temporary output files post-upload.
PROCESSING_KEEP_TIMESTAMP_ONLY_OPTION ?= --keep-timestamp-only
# To disable this mode, comment the line above and uncomment the line below.
# PROCESSING_KEEP_TIMESTAMP_ONLY_OPTION ?=

  $(call log.debug, PROCESSING_KEEP_TIMESTAMP_ONLY_OPTION)


# USER-VARIABLE: PROCESSING_QUIT_IF_S3_OUTPUT_EXISTS_OPTION
# Prevents processing if the output file already exists in S3.
#
# If enabled, this option ensures that processing halts if the expected output
# file is already present in S3, preventing unnecessary re-processing.
PROCESSING_QUIT_IF_S3_OUTPUT_EXISTS_OPTION ?= --quit-if-s3-output-exists
# To disable this mode, comment the line above and uncomment the line below.
# PROCESSING_QUIT_IF_S3_OUTPUT_EXISTS_OPTION ?=

  $(call log.debug, PROCESSING_QUIT_IF_S3_OUTPUT_EXISTS_OPTION)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing.mk)
