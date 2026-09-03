$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_topics.mk)
###############################################################################
# SYNC TOPICS TARGETS
# Targets for synchronizing processed topics data between S3 and local storage
###############################################################################


# DOUBLE-COLON-TARGET: sync-output
# Synchronizes topic processing output data from/to S3
sync-output :: sync-topics


# VARIABLE: LOCAL_TOPICS_SYNC_STAMP_FILE
# Local stamp file to track synchronization status
LOCAL_TOPICS_SYNC_STAMP_FILE := $(call newspaper_sync_stamp_targets,$(LOCAL_PATH_TOPICS))
$(call expand_newspaper_year_sync_targets,$(LOCAL_PATH_TOPICS))
  $(call log.debug, LOCAL_TOPICS_SYNC_STAMP_FILE)


# TARGET: sync-topics
#: Synchronizes topics processing data
sync-topics : $(LOCAL_TOPICS_SYNC_STAMP_FILE)

.PHONY: sync-topics

help-sync::
	@echo ""
	@echo "TOPICS SYNC:"
	@echo "  sync-topics    # Synchronize topic processing data from/to S3"
	@echo "  upload-topic-descriptions # Upload gzip-compressed topic descriptions to the topic run root"


# VARIABLE: S3_PATH_TOPICS_RUN_ROOT
# S3 prefix for run-level topic metadata, without newspaper-specific suffixes.
S3_PATH_TOPICS_RUN_ROOT := s3://$(S3_BUCKET_TOPICS)/$(PROCESS_LABEL_TOPICS)/$(RUN_ID_TOPICS)
  $(call log.debug, S3_PATH_TOPICS_RUN_ROOT)


# USER-VARIABLE: TOPICS_DESCRIPTIONS_DRY_RUN_OPTION
# Set to --dry-run to print topic-description uploads without writing to S3.
TOPICS_DESCRIPTIONS_DRY_RUN_OPTION ?=
  $(call log.debug, TOPICS_DESCRIPTIONS_DRY_RUN_OPTION)


# TARGET: upload-topic-descriptions
#: Uploads topic model descriptions as jsonl.gz run metadata files
upload-topic-descriptions:
	python3 lib/upload_topic_descriptions.py \
	  --s3-prefix $(S3_PATH_TOPICS_RUN_ROOT) \
	  $(TOPICS_DESCRIPTIONS_DRY_RUN_OPTION) \
	  $(if $(TOPICS_DE_CONFIG),--language-config de=$(TOPICS_DE_CONFIG),) \
	  $(if $(TOPICS_FR_CONFIG),--language-config fr=$(TOPICS_FR_CONFIG),) \
	  $(if $(TOPICS_EN_CONFIG),--language-config en=$(TOPICS_EN_CONFIG),) \
	  $(if $(TOPICS_LB_CONFIG),--language-config lb=$(TOPICS_LB_CONFIG),)

.PHONY: upload-topic-descriptions


# STAMPED-FILE-RULE: $(LOCAL_PATH_TOPICS).last_synced
#: Synchronizes topics data from S3 to local stamp files
#: Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_TOPICS_SYNC_STAMP_FILE):
	$(call sync_year_aware_per_file_stamps,$(S3_PATH_TOPICS),$@,--file-extensions jsonl.bz2 json log.gz --remove-dangling-stamps --log-level $(LOGGING_LEVEL))


# TARGET: clean-sync-topics
#: Removes local topics sync state for the selected scope
clean-sync:: clean-sync-topics
clean-sync-output:: clean-sync-topics

clean-sync-topics:
	rm -rfv $(call newspaper_sync_clean_files,$(LOCAL_PATH_TOPICS)) $(if $(strip $(NEWSPAPER_YEARS)),,$(LOCAL_PATH_TOPICS)) || true

.PHONY: clean-sync-topics

help-clean::
	@echo "  clean-sync-topics # Remove local topics sync state for the selected scope"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_topics.mk)
