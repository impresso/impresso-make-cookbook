$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_mediaagencies.mk)
###############################################################################
# mediaagencies Configuration
# Defines S3 and local paths for media-agency NER processing
###############################################################################


# USER-VARIABLE: S3_BUCKET_MEDIAAGENCIES
# S3 bucket where processed media-agency output is stored.
S3_BUCKET_MEDIAAGENCIES ?= 141-processed-data-staging
  $(call log.debug, S3_BUCKET_MEDIAAGENCIES)


# USER-VARIABLE: PROCESS_LABEL_MEDIAAGENCIES
# Label for the processing task.
PROCESS_LABEL_MEDIAAGENCIES ?= mediaagencies
  $(call log.debug, PROCESS_LABEL_MEDIAAGENCIES)


# USER-VARIABLE: PROCESS_SUBTYPE_LABEL_MEDIAAGENCIES
# Optional additional label for processing subtypes.
PROCESS_SUBTYPE_LABEL_MEDIAAGENCIES ?= $(EMPTY)
  $(call log.debug, PROCESS_SUBTYPE_LABEL_MEDIAAGENCIES)


# USER-VARIABLE: TASK_MEDIAAGENCIES
# The specific media-agency processing task.
TASK_MEDIAAGENCIES ?= ner
  $(call log.debug, TASK_MEDIAAGENCIES)


# USER-VARIABLE: MODEL_ID_MEDIAAGENCIES
# Path-safe model identifier used in S3 paths.
MODEL_ID_MEDIAAGENCIES ?= mmbert-impresso-mediaagencies-ner_v2-0-0
  $(call log.debug, MODEL_ID_MEDIAAGENCIES)


# USER-VARIABLE: HF_MODEL_MEDIAAGENCIES
# Hugging Face model ID passed to the impresso-inference runner.
HF_MODEL_MEDIAAGENCIES ?= impresso-project/mmbert-impresso-mediaagencies-ner
  $(call log.debug, HF_MODEL_MEDIAAGENCIES)


# USER-VARIABLE: HF_MODEL_REVISION_MEDIAAGENCIES
# Hugging Face revision passed to the impresso-inference runner.
HF_MODEL_REVISION_MEDIAAGENCIES ?= v2.0.0
  $(call log.debug, HF_MODEL_REVISION_MEDIAAGENCIES)


# USER-VARIABLE: RUN_VERSION_MEDIAAGENCIES
# Version of the processing run.
RUN_VERSION_MEDIAAGENCIES ?= v1-0-0
  $(call log.debug, RUN_VERSION_MEDIAAGENCIES)


# VARIABLE: RUN_ID_MEDIAAGENCIES
# Unique identifier for the processing run.
RUN_ID_MEDIAAGENCIES := $(PROCESS_LABEL_MEDIAAGENCIES)-$(TASK_MEDIAAGENCIES)-$(MODEL_ID_MEDIAAGENCIES)_$(RUN_VERSION_MEDIAAGENCIES)
  $(call log.debug, RUN_ID_MEDIAAGENCIES)


# VARIABLE: PATH_MEDIAAGENCIES
# Path for media-agency processing data.
PATH_MEDIAAGENCIES := $(S3_BUCKET_MEDIAAGENCIES)/$(PROCESS_LABEL_MEDIAAGENCIES)$(PROCESS_SUBTYPE_LABEL_MEDIAAGENCIES)/$(RUN_ID_MEDIAAGENCIES)/$(NEWSPAPER)
  $(call log.debug, PATH_MEDIAAGENCIES)


# VARIABLE: S3_PATH_MEDIAAGENCIES
# S3 path where processed media-agency data is stored.
S3_PATH_MEDIAAGENCIES := s3://$(PATH_MEDIAAGENCIES)
  $(call log.debug, S3_PATH_MEDIAAGENCIES)


# VARIABLE: LOCAL_PATH_MEDIAAGENCIES
# Local path for media-agency processing data within BUILD_DIR.
LOCAL_PATH_MEDIAAGENCIES := $(BUILD_DIR)/$(PATH_MEDIAAGENCIES)
  $(call log.debug, LOCAL_PATH_MEDIAAGENCIES)

help-path-variables::
	@echo ""
	@echo "MEDIA-AGENCIES PATH VALUES:"
	@echo "  S3_BUCKET_MEDIAAGENCIES=$(S3_BUCKET_MEDIAAGENCIES)"
	@echo "  RUN_ID_MEDIAAGENCIES=$(RUN_ID_MEDIAAGENCIES)"
	@echo "  S3_PATH_MEDIAAGENCIES=$(S3_PATH_MEDIAAGENCIES)"
	@echo "  LOCAL_PATH_MEDIAAGENCIES=$(LOCAL_PATH_MEDIAAGENCIES)"


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_mediaagencies.mk)
