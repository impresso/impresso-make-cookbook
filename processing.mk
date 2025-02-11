$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing.mk)

###############################################################################
# Processing Configuration
# User-configurable settings for processing output behavior.
#
# This file defines options to control processing behavior, particularly when
# interacting with S3 storage.
###############################################################################


# DOUBLE-COLON-TARGET: processing-target
#: Defines the current processing target
#
# This target is used to define the current processing target for the recursive build.
processing-target:: | $(BUILD_DIR)


# USER-VARIABLE: MACHINE_MAX_LOAD
# Maximum load average for the machine to allow processing
#
# This variable sets the maximum load average for the machine in parallelization. No new
# jobs are started if the load average exceeds this value.
MACHINE_MAX_LOAD ?= $(shell expr $$(nproc) + 1)
  $(call log.debug, MACHINE_MAX_LOAD)

# USER-VARIABLE: PARALLEL_NEWSPAPERS
# Maximum number of parallel newspaper processes
PARALLEL_NEWSPAPERS ?= $(shell expr $$(nproc) / 3)

# USER-VARIABLE: MAKE_PARALLEL_PROCESSING_NEWSPAPER_YEAR
# Maximum number of parallel newspaper processes
#
# This variable sets the maximum number of parallel newspaper processes to run in a
# single 
MAKE_PARALLEL_PROCESSING_NEWSPAPER_YEAR ?= $(shell expr $(MACHINE_MAX_LOAD) / 3)
  $(call log.debug, MAKE_PARALLEL_PROCESSING_NEWSPAPER_YEAR)


# USER-VARIABLE: PROCESSING_S3_OUTPUT_DRY_RUN
# Prevents any output to S3 even if an S3 output path is set.
#
# This option ensures that no files are uploaded to S3. It is useful for testing
# and debugging purposes to verify local output without actual S3 writes.
# PROCESSING_S3_OUTPUT_DRY_RUN ?= --s3-output-dry-run
# To disable the dry-run mode, comment the line above and uncomment the line below.
PROCESSING_S3_OUTPUT_DRY_RUN ?=

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
