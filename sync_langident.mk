$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_langident.mk)

###############################################################################
# SYNC LANGUAGE IDENTIFICATION TARGETS
# Targets for synchronizing processed language identification data between S3 and local storage
###############################################################################


sync-input:: sync-input-langident

sync-output:: sync-output-langident


# The local per-newspaper synchronization file stamp for the processed input data: What is on S3 has been synced?
LOCAL_LANGIDENT_SYNC_STAMP_FILE := $(LOCAL_PATH_LANGIDENT).last_synced
  $(call log.debug, LOCAL_LANGIDENT_SYNC_STAMP_FILE)

# Rule to sync the input data from the S3 bucket to the local directory
$(LOCAL_PATH_LANGIDENT).last_synced:
	# Syncing the processed data $(S3_PATH_LANGIDENT) 
	#   to $(LOCAL_PATH_LANGIDENT)
	mkdir -p $(@D) && \
	python lib/s3_to_local_stamps.py \
	   $(S3_PATH_LANGIDENT) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(LOCAL_STAMP_SUFFIX) \
	   --logfile $@.log.gz \
	&& touch $@

# TARGET: sync-input-langident
# Synchronizes processed input data from S3 to local directory
sync-input-langident: $(LOCAL_LANGIDENT_SYNC_STAMP_FILE)
PHONY_TARGETS += sync-input-langident

# TARGET: sync-output-langident
# Synchronizes processed output data from S3 to local directory
sync-output-langident: $(LOCAL_LANGIDENT_SYNC_STAMP_FILE)
PHONY_TARGETS += sync-output-langident


$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_langident.mk)
