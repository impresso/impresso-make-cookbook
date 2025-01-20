$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_langident.mk)

###############################################################################
# LANGUAGE IDENTIFICATION PATH DEFINITIONS
# Configuration of input/output paths for language identification processing
###############################################################################

# S3 bucket configuration for language identification
S3_BUCKET_LANGINDENT := 42-processed-data-final
  $(call log.debug, S3_BUCKET_LANGINDENT)

# Process labels and version information
PROCESS_LABEL_LANGINDENT ?= langident
  $(call log.debug, PROCESS_LABEL_LANGINDENT)

PROCESS_SUBTYPE_LABEL_LANGINDENT ?=
  $(call log.debug, PROCESS_SUBTYPE_LABEL_LANGINDENT)

# @FIX NOT USED  s3://42-processed-data-final/langident/langident_v1-4-4/ACI/ACI-1832.jsonl.bz2
TASK_LANGINDENT ?=


# @FIX s3://42-processed-data-final/langident/langident_v1-4-4/ACI/ACI-1832.jsonl.bz2
MODEL_ID_LANGINDENT ?= 

RUN_VERSION_LANGINDENT ?= v1-4-4
  $(call log.debug, RUN_VERSION_LANGINDENT)

# @FIX 
RUN_ID_LANGIDENT ?= $(PROCESS_LABEL_LANGINDENT)_$(RUN_VERSION_LANGINDENT)
  $(call log.debug, RUN_ID_LANGIDENT)

S3_PATH_LANGIDENT := s3://$(S3_BUCKET_LANGINDENT)/$(PROCESS_LABEL_LANGINDENT)/$(RUN_ID_LANGIDENT)/$(NEWSPAPER)
  $(call log.debug, S3_PATH_LANGIDENT)
  
LOCAL_PATH_LANGIDENT := $(BUILD_DIR)/$(S3_BUCKET_LANGINDENT)/$(PROCESS_LABEL_LANGINDENT)/$(RUN_ID_LANGIDENT)/$(NEWSPAPER)
  $(call log.debug, LOCAL_PATH_LANGIDENT)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_langident.mk)
