$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_s3aggregation.mk)
###############################################################################
# s3aggregation Configuration
# Defines S3 and local paths for s3aggregation processing
###############################################################################


# USER-VARIABLE: S3_BUCKET_s3aggregation
# The input bucket for s3aggregation processing
#
# Defines the S3 bucket where the processed data is stored.
S3_BUCKET_s3aggregation ?= 140-processed-data-sandbox
  $(call log.debug, S3_BUCKET_s3aggregation)


# USER-VARIABLE: PROCESS_LABEL_s3aggregation
# Label for the processing task
#
# A general label for identifying s3aggregation processing tasks.
PROCESS_LABEL_s3aggregation ?= template
  $(call log.debug, PROCESS_LABEL_s3aggregation)


# USER-VARIABLE: PROCESS_SUBTYPE_LABEL_s3aggregation
# Subtype label for processing
#
# Optional additional label for subtypes of processing.
PROCESS_SUBTYPE_LABEL_s3aggregation ?=
  $(call log.debug, PROCESS_SUBTYPE_LABEL_s3aggregation)


# USER-VARIABLE: TASK_s3aggregation
# The specific s3aggregation processing task
#
# Defines the specific s3aggregation processing task.
TASK_s3aggregation ?= template
  $(call log.debug, TASK_s3aggregation)


# USER-VARIABLE: MODEL_ID_s3aggregation
# The model identifier
#
# Specifies the model used for s3aggregation processing.
MODEL_ID_s3aggregation ?= template_v0.0.0
  $(call log.debug, MODEL_ID_s3aggregation)


# USER-VARIABLE: RUN_VERSION_s3aggregation
# The version of the processing run
#
# Indicates the version of the current processing run.
RUN_VERSION_s3aggregation ?= v1-0-0
  $(call log.debug, RUN_VERSION_s3aggregation)


# VARIABLE: RUN_ID_s3aggregation
# Unique identifier for the processing run
#
# Constructs a unique identifier based on the process label, task, model, and version.
RUN_ID_s3aggregation := $(PROCESS_LABEL_s3aggregation)-$(TASK_s3aggregation)-$(MODEL_ID_s3aggregation)_$(RUN_VERSION_s3aggregation)
  $(call log.debug, RUN_ID_s3aggregation)


# VARIABLE: PATH_s3aggregation
# Path for s3aggregation processing data
#
# Defines the full path for s3aggregation processing data.
PATH_s3aggregation := $(S3_BUCKET_s3aggregation)/$(PROCESS_LABEL_s3aggregation)$(PROCESS_SUBTYPE_LABEL_s3aggregation)/$(RUN_ID_s3aggregation)/$(NEWSPAPER)
  $(call log.debug, PATH_s3aggregation)


# VARIABLE: S3_PATH_s3aggregation
# S3 path for input data
#
# Defines the full S3 path where processed s3aggregation processing data is stored.
S3_PATH_s3aggregation := s3://$(PATH_s3aggregation)
  $(call log.debug, S3_PATH_s3aggregation)


# VARIABLE: LOCAL_PATH_s3aggregation
# Local path for storing S3 data
#
# Defines the local storage path for s3aggregation processing data within BUILD_DIR.
LOCAL_PATH_s3aggregation := $(BUILD_DIR)/$(PATH_s3aggregation)
  $(call log.debug, LOCAL_PATH_s3aggregation)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_s3aggregation.mk)
