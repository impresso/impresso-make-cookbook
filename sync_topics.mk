$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_topics.mk)

###############################################################################
# SYNC TOPICS TARGETS
# Targets for synchronizing processed topics data between S3 and local storage
###############################################################################



# The local per-newspaper synchronization file stamp for the output topics: What is on S3 has been synced?
LOCAL_TOPICS_SYNC_STAMP_FILE := $(LOCAL_PATH_TOPICS).last_synced
  $(call log.debug, LOCAL_TOPICS_SYNC_STAMP_FILE)


# The suffix for the local stamp files (added to the local paths of s3 input paths)
LOCAL_TOPICS_STAMP_SUFFIX ?= $(LOCAL_STAMP_SUFFIX)
  $(call log.debug, LOCAL_TOPICS_STAMP_SUFFIX)

# Rule to sync the output data from the S3 bucket to the local directory
$(LOCAL_TOPICS_SYNC_STAMP_FILE):
	mkdir -p $(@D) && \
	python lib/s3_to_local_stamps.py \
	   $(S3_PATH_TOPICS) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(LOCAL_TOPICS_STAMP_SUFFIX) \
	   --logfile $@.log.gz && \
	touch $@


sync-topics: $(LOCAL_TOPICS_SYNC_STAMP_FILE)

PHONY_TARGETS += sync-topics

#### SYNCING THE OUTPUT DATA FROM S3 TO LOCAL DIRECTORY

# MULTITARGET: sync-output
# Synchronizes topics output data from/to S3
sync-output:: sync-topics

# MULTITARGET: sync-input
sync-input:: sync-topics


### CLEANING THE SYNC OUTPUT

# Target: clean-sync
# Cleans the local synchronization files and directories
clean-sync:: clean-sync-topics

clean-sync-topics:
	rm -vf $(LOCAL_TOPICS_SYNC_STAMP_FILE) || true
	rm -rfv $(LOCAL_PATH_TOPICS) || true

PHONY_TARGETS += clean-sync-topics



$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_topics.mk)
