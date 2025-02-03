$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_topics.mk)



# The topics  bucket
S3_BUCKET_TOPICS ?= 41-processed-data-staging
$(call log.debug, S3_BUCKET_TOPICS)


PROCESS_LABEL_TOPICS ?= topics
  $(call log.debug, PROCESS_LABEL_TOPICS)

RUN_VERSION_TOPICS ?= v2-0-1
  $(call log.debug, RUN_VERSION_TOPICS)

TASK_TOPICS ?= tm
  $(call log.debug, TASK_TOPICS)

MALLET_RANDOM_SEED ?= 42
  $(call log.debug, MALLET_RANDOM_SEED)


MODEL_SPECIFICITY_TOPICS ?= mallet_infer_seed$(MALLET_RANDOM_SEED)
  $(call log.debug, MODEL_SPECIFICITY_TOPICS)

MODEL_VERSION_TOPICS ?= v2.0.1
  $(call log.debug, MODEL_VERSION_TOPICS)

LANG_TOPICS ?= multilingual
  $(call log.debug, LANG_TOPICS)

MODEL_ID_TOPICS ?= $(TASK_TOPICS)-$(MODEL_SPECIFICITY_TOPICS)_$(MODEL_VERSION_TOPICS)-$(LANG_TOPICS)
  $(call log.debug, MODEL_ID_TOPICS)

RUN_ID_TOPICS ?= $(PROCESS_LABEL_TOPICS)-$(MODEL_ID_TOPICS)_$(RUN_VERSION_TOPICS)
  $(call log.debug, RUN_ID_TOPICS)

S3_PATH_TOPICS := s3://$(S3_BUCKET_TOPICS)/$(PROCESS_LABEL_TOPICS)/$(RUN_ID_TOPICS)/$(NEWSPAPER)
  $(call log.debug, S3_PATH_TOPICS)

LOCAL_PATH_TOPICS := $(BUILD_DIR)/$(S3_BUCKET_TOPICS)/$(PROCESS_LABEL_TOPICS)/$(RUN_ID_TOPICS)/$(NEWSPAPER)
  $(call log.debug, LOCAL_PATH_TOPICS)



$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_topics.mk)
