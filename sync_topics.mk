$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_topics.mk)
###############################################################################
# SYNC TOPICS TARGETS
# Targets for synchronizing processed topics data between S3 and local storage
###############################################################################


# DOUBLE-COLON-TARGET: sync-output
# Synchronizes topic processing output data from/to S3
sync-output :: sync-topics


# DOUBLE-COLON-TARGET: sync-input
# Synchronizes linguistic processing input data from S3
sync-input :: sync-topics


# VARIABLE: LOCAL_TOPICS_SYNC_STAMP_FILE
# Local stamp file to track synchronization status
LOCAL_TOPICS_SYNC_STAMP_FILE := $(LOCAL_PATH_TOPICS).last_synced
  $(call log.debug, LOCAL_TOPICS_SYNC_STAMP_FILE)


# TARGET: sync-topics
#: Synchronizes topics processing data
sync-topics : $(LOCAL_TOPICS_SYNC_STAMP_FILE)

.PHONY: sync-topics


# USER-VARIABLE: LOCAL_TOPICS_STAMP_SUFFIX
# The suffix for local stamp files (added to the input paths on S3)
LOCAL_TOPICS_STAMP_SUFFIX ?= ''
  $(call log.debug, LOCAL_TOPICS_STAMP_SUFFIX)


# FILE-RULE: LOCAL_TOPICS_SYNC_STAMP_FILE
#: Rule to sync the output data from the S3 bucket to the local directory
$(LOCAL_TOPICS_SYNC_STAMP_FILE):
	mkdir -p $(@D) && \
	python lib/s3_to_local_stamps.py \
	   $(S3_PATH_TOPICS) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(LOCAL_TOPICS_STAMP_SUFFIX) \
	   2> >(tee $@.log >&2) && \
	touch $@


# TARGET: clean-sync-topics
#: Removes synchronized topic data from local storage
clean-sync-topics:
	rm -rfv $(LOCAL_PATH_TOPICS) $(LOCAL_TOPICS_SYNC_STAMP_FILE) || true

.PHONY: clean-sync-topics

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_topics.mk)
