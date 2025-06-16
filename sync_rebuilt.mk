$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_rebuilt.mk)

###############################################################################
# SYNC REBUILT DATA TARGETS
# Targets for synchronizing rebuilt data from S3 to local storage
###############################################################################

# TARGET: sync-input-rebuilt
# Synchronizes rebuilt input data from S3 to local directory
sync-input:: sync-input-rebuilt 
.PHONY: sync-input

# Local synchronization stamp file for rebuilt input data
LOCAL_REBUILT_SYNC_STAMP_FILE := $(LOCAL_PATH_REBUILT).last_synced
  $(call log.debug, LOCAL_REBUILT_SYNC_STAMP_FILE)

sync-input-rebuilt: $(LOCAL_REBUILT_SYNC_STAMP_FILE)

.PHONY: sync-input-rebuilt


# the suffix of for the local stamp files (added to the input paths on s3)
LOCAL_REBUILT_STAMP_SUFFIX ?= .stamp
  $(call log.debug, LOCAL_REBUILT_STAMP_SUFFIX)

# Rule to sync the input data from the S3 bucket to the local directory
$(LOCAL_PATH_REBUILT).last_synced:
	mkdir -p $(@D) && \
	python lib/s3_to_local_stamps.py \
	   $(S3_PATH_REBUILT) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(LOCAL_REBUILT_STAMP_SUFFIX) \
	   --logfile $@.log.gz && \
	touch $@



$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_rebuilt.mk)
