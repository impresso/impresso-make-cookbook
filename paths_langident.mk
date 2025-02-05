$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_langident.mk)

###############################################################################
# LANGUAGE IDENTIFICATION PATH DEFINITIONS
# Configuration of input/output paths for language identification processing
###############################################################################


# VARIABLE: S3_BUCKET_LANGINDENT
# S3 bucket name for storing processed language identification data
S3_BUCKET_LANGINDENT := 42-processed-data-final
  $(call log.debug, S3_BUCKET_LANGINDENT)


# USER-VARIABLE: PROCESS_LABEL_LANGINDENT
# Label for the language identification process
PROCESS_LABEL_LANGINDENT ?= langident
  $(call log.debug, PROCESS_LABEL_LANGINDENT)


# USER-VARIABLE: PROCESS_SUBTYPE_LABEL_LANGINDENT
# Optional subtype label for further process categorization
PROCESS_SUBTYPE_LABEL_LANGINDENT ?=
  $(call log.debug, PROCESS_SUBTYPE_LABEL_LANGINDENT)


# USER-VARIABLE: TASK_LANGINDENT
# Task specification for language identification
# @FIX NOT USED: Example of unused configuration:
# s3://42-processed-data-final/langident/langident_v1-4-4/ACI/ACI-1832.jsonl.bz2
TASK_LANGINDENT ?=


# USER-VARIABLE: MODEL_ID_LANGINDENT
# Model identifier for the language identification process
# @FIX Example path: s3://42-processed-data-final/langident/langident_v1-4-4/ACI/ACI-1832.jsonl.bz2
MODEL_ID_LANGINDENT ?=


# USER-VARIABLE: RUN_VERSION_LANGINDENT
# Version identifier for the current language identification run
RUN_VERSION_LANGINDENT ?= v1-4-4
  $(call log.debug, RUN_VERSION_LANGINDENT)


# VARIABLE: RUN_ID_LANGIDENT
# Constructed run identifier combining process label and version
RUN_ID_LANGIDENT ?= $(PROCESS_LABEL_LANGINDENT)_$(RUN_VERSION_LANGINDENT)
  $(call log.debug, RUN_ID_LANGIDENT)


# VARIABLE: S3_PATH_LANGIDENT
# S3 storage path for the processed language identification results
S3_PATH_LANGIDENT := s3://$(S3_BUCKET_LANGINDENT)/$(PROCESS_LABEL_LANGINDENT)/$(RUN_ID_LANGIDENT)/$(NEWSPAPER)
  $(call log.debug, S3_PATH_LANGIDENT)


# VARIABLE: LOCAL_PATH_LANGIDENT
# Local file system path for the processed language identification results
LOCAL_PATH_LANGIDENT := $(BUILD_DIR)/$(S3_BUCKET_LANGINDENT)/$(PROCESS_LABEL_LANGINDENT)/$(RUN_ID_LANGIDENT)/$(NEWSPAPER)
  $(call log.debug, LOCAL_PATH_LANGIDENT)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_langident.mk)
