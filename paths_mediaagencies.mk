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
MODEL_ID_MEDIAAGENCIES ?= mmbert-impresso-mediaagencies-ner_v2-1-0
  $(call log.debug, MODEL_ID_MEDIAAGENCIES)


# USER-VARIABLE: HF_MODEL_MEDIAAGENCIES
# Hugging Face model ID passed to the impresso-inference runner.
HF_MODEL_MEDIAAGENCIES ?= impresso-project/mmbert-impresso-mediaagencies-ner
  $(call log.debug, HF_MODEL_MEDIAAGENCIES)


# USER-VARIABLE: HF_MODEL_REVISION_MEDIAAGENCIES
# Hugging Face revision passed to the impresso-inference runner.
HF_MODEL_REVISION_MEDIAAGENCIES ?= v2.1.0
  $(call log.debug, HF_MODEL_REVISION_MEDIAAGENCIES)


# Processing defaults; release configs normally set these explicitly.

# USER-VARIABLE: BATCH_SIZE_MEDIAAGENCIES
# GPU batch size in windows (keep equal to the value used for the parity check).
BATCH_SIZE_MEDIAAGENCIES ?= 256
  $(call log.debug, BATCH_SIZE_MEDIAAGENCIES)

# USER-VARIABLE: DTYPE_MEDIAAGENCIES
# bf16 (default) or float32.
DTYPE_MEDIAAGENCIES ?= bf16
  $(call log.debug, DTYPE_MEDIAAGENCIES)

# USER-VARIABLE: DEVICE_MEDIAAGENCIES
# cuda, cpu, or auto (= cuda).
DEVICE_MEDIAAGENCIES ?= cuda
  $(call log.debug, DEVICE_MEDIAAGENCIES)

# USER-VARIABLE: FILTER_ANACHRONISTIC_MEDIAAGENCIES
# --filter-anachronistic (default) drops entities published before the label's
# founding year; set empty to keep them.
FILTER_ANACHRONISTIC_MEDIAAGENCIES ?= --filter-anachronistic
  $(call log.debug, FILTER_ANACHRONISTIC_MEDIAAGENCIES)


# USER-VARIABLE: RUN_VERSION_MEDIAAGENCIES
# Version of the processing run.
RUN_VERSION_MEDIAAGENCIES ?= v1-0-0
  $(call log.debug, RUN_VERSION_MEDIAAGENCIES)


# VARIABLE: RUN_ID_MEDIAAGENCIES
# Unique identifier for the processing run.
RUN_ID_MEDIAAGENCIES := $(PROCESS_LABEL_MEDIAAGENCIES)-$(TASK_MEDIAAGENCIES)-$(MODEL_ID_MEDIAAGENCIES)_$(RUN_VERSION_MEDIAAGENCIES)
  $(call log.debug, RUN_ID_MEDIAAGENCIES)


# USER-VARIABLE: STAGE_RUN_VERSION_MEDIAAGENCIES
# Run version of the stage-1/stage-2 buffers. Defaults to RUN_VERSION_MEDIAAGENCIES.
# Set it to an earlier run version to re-decode that run's stage-2 logits into a
# new run folder without new inference.
STAGE_RUN_VERSION_MEDIAAGENCIES ?= $(RUN_VERSION_MEDIAAGENCIES)
  $(call log.debug, STAGE_RUN_VERSION_MEDIAAGENCIES)

# VARIABLE: STAGE_RUN_ID_MEDIAAGENCIES_STAGE1 / _STAGE2
# Run identifiers of the stage-1/stage-2 folders: the run ID with the stage after
# the task, e.g. mediaagencies-ner_stage2-<model>_v1-0-0 (same scheme as langident).
STAGE_RUN_ID_MEDIAAGENCIES_STAGE1 := $(PROCESS_LABEL_MEDIAAGENCIES)-$(TASK_MEDIAAGENCIES)_stage1-$(MODEL_ID_MEDIAAGENCIES)_$(STAGE_RUN_VERSION_MEDIAAGENCIES)
  $(call log.debug, STAGE_RUN_ID_MEDIAAGENCIES_STAGE1)
STAGE_RUN_ID_MEDIAAGENCIES_STAGE2 := $(PROCESS_LABEL_MEDIAAGENCIES)-$(TASK_MEDIAAGENCIES)_stage2-$(MODEL_ID_MEDIAAGENCIES)_$(STAGE_RUN_VERSION_MEDIAAGENCIES)
  $(call log.debug, STAGE_RUN_ID_MEDIAAGENCIES_STAGE2)


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

# VARIABLE: PATH_MEDIAAGENCIES_STAGE1
# Path for stage-1 (pre-tokenized) parquet buffers of the staged pipeline.
PATH_MEDIAAGENCIES_STAGE1 := $(S3_BUCKET_MEDIAAGENCIES)/$(PROCESS_LABEL_MEDIAAGENCIES)$(PROCESS_SUBTYPE_LABEL_MEDIAAGENCIES)/$(STAGE_RUN_ID_MEDIAAGENCIES_STAGE1)/$(NEWSPAPER)
  $(call log.debug, PATH_MEDIAAGENCIES_STAGE1)

S3_PATH_MEDIAAGENCIES_STAGE1 := s3://$(PATH_MEDIAAGENCIES_STAGE1)
  $(call log.debug, S3_PATH_MEDIAAGENCIES_STAGE1)

LOCAL_PATH_MEDIAAGENCIES_STAGE1 := $(BUILD_DIR)/$(PATH_MEDIAAGENCIES_STAGE1)
  $(call log.debug, LOCAL_PATH_MEDIAAGENCIES_STAGE1)


# VARIABLE: PATH_MEDIAAGENCIES_STAGE2
# Path for stage-2 (GPU emission logits) parquet buffers of the staged pipeline.
PATH_MEDIAAGENCIES_STAGE2 := $(S3_BUCKET_MEDIAAGENCIES)/$(PROCESS_LABEL_MEDIAAGENCIES)$(PROCESS_SUBTYPE_LABEL_MEDIAAGENCIES)/$(STAGE_RUN_ID_MEDIAAGENCIES_STAGE2)/$(NEWSPAPER)
  $(call log.debug, PATH_MEDIAAGENCIES_STAGE2)

S3_PATH_MEDIAAGENCIES_STAGE2 := s3://$(PATH_MEDIAAGENCIES_STAGE2)
  $(call log.debug, S3_PATH_MEDIAAGENCIES_STAGE2)

LOCAL_PATH_MEDIAAGENCIES_STAGE2 := $(BUILD_DIR)/$(PATH_MEDIAAGENCIES_STAGE2)
  $(call log.debug, LOCAL_PATH_MEDIAAGENCIES_STAGE2)

help-path-variables::
	@echo ""
	@echo "MEDIA-AGENCIES PATH VALUES:"
	@echo "  S3_BUCKET_MEDIAAGENCIES=$(S3_BUCKET_MEDIAAGENCIES)"
	@echo "  RUN_ID_MEDIAAGENCIES=$(RUN_ID_MEDIAAGENCIES)"
	@echo "  S3_PATH_MEDIAAGENCIES=$(S3_PATH_MEDIAAGENCIES)"
	@echo "  LOCAL_PATH_MEDIAAGENCIES=$(LOCAL_PATH_MEDIAAGENCIES)"
	@echo "  S3_PATH_MEDIAAGENCIES_STAGE1=$(S3_PATH_MEDIAAGENCIES_STAGE1)"
	@echo "  S3_PATH_MEDIAAGENCIES_STAGE2=$(S3_PATH_MEDIAAGENCIES_STAGE2)"


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_mediaagencies.mk)
