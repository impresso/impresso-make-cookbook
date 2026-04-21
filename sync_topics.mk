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
LOCAL_TOPICS_SYNC_STAMP_FILE := $(LOCAL_PATH_TOPICS).last_synced
  $(call log.debug, LOCAL_TOPICS_SYNC_STAMP_FILE)


# TARGET: sync-topics
#: Synchronizes topics processing data
sync-topics : $(LOCAL_TOPICS_SYNC_STAMP_FILE)

.PHONY: sync-topics


# STAMPED-FILE-RULE: $(LOCAL_PATH_TOPICS).last_synced
#: Synchronizes topics data from S3 to local stamp files
#: Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_TOPICS_SYNC_STAMP_FILE):
	mkdir -p $(@D) && \
	python -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_TOPICS) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --file-extensions jsonl.bz2 json log.gz \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& \
	touch $@


# TARGET: clean-sync-topics
#: Removes synchronized topic data from local storage
clean-sync:: clean-sync-topics
clean-sync-output:: clean-sync-topics

clean-sync-topics:
	rm -rfv $(LOCAL_PATH_TOPICS) $(LOCAL_TOPICS_SYNC_STAMP_FILE) || true

.PHONY: clean-sync-topics

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_topics.mk)
