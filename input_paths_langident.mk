$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/input_paths_langident.mk)

###############################################################################
# LANGUAGE IDENTIFICATION PATH DEFINITIONS
# Configuration of input/output paths for language identification processing
###############################################################################

# S3 bucket configuration for language identification
IN_S3_BUCKET_LANGINDENT := 42-processed-data-final
  $(call log.debug, IN_S3_BUCKET_LANGINDENT)

# Process labels and version information
IN_PROCESS_LABEL_LANGINDENT ?= langident
  $(call log.debug, IN_PROCESS_LABEL_LANGINDENT)

IN_PROCESS_SUBTYPE_LABEL_LANGINDENT ?=
  $(call log.debug, IN_PROCESS_SUBTYPE_LABEL_LANGINDENT)

# @FIX NOT USED  s3://42-processed-data-final/langident/langident_v1-4-4/ACI/ACI-1832.jsonl.bz2
IN_TASK ?=


# @FIX s3://42-processed-data-final/langident/langident_v1-4-4/ACI/ACI-1832.jsonl.bz2
IN_MODEL_ID ?= 

IN_RUN_VERSION_LANGINDENT ?= v1-4-4
  $(call log.debug, IN_RUN_VERSION_LANGINDENT)

# @FIX 
IN_RUN_ID_LANGIDENT ?= $(IN_PROCESS_LABEL_LANGINDENT)_$(IN_RUN_VERSION_LANGINDENT)
  $(call log.debug, IN_RUN_ID_LANGIDENT)

IN_S3_PATH_LANGIDENT := s3://$(IN_S3_BUCKET_LANGINDENT)/$(IN_PROCESS_LABEL_LANGINDENT)/$(IN_RUN_ID_LANGIDENT)/$(NEWSPAPER)
  $(call log.debug, IN_S3_PATH_LANGIDENT)
  
IN_LOCAL_PATH_LANGIDENT := $(BUILD_DIR)/$(IN_S3_BUCKET_LANGINDENT)/$(IN_PROCESS_LABEL_LANGINDENT)/$(IN_RUN_ID_LANGIDENT)/$(NEWSPAPER)
  $(call log.debug, IN_LOCAL_PATH_LANGIDENT)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/input_paths_langident.mk)
