$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_langident.mk)

###############################################################################
# SYNC LANGUAGE IDENTIFICATION TARGETS
#
# Targets for synchronizing processed language identification data
# between S3 and local storage.
###############################################################################


# VARIABLE: LOCAL_LANGIDENT_SYNC_STAMP_FILE
# Local synchronization stamp file for processed input data.
#
# This file serves as a marker indicating whether the processed data
# on S3 has been successfully synced to the local storage.
LOCAL_LANGIDENT_SYNC_STAMP_FILE := $(LOCAL_PATH_LANGIDENT).last_synced
  $(call log.debug, LOCAL_LANGIDENT_SYNC_STAMP_FILE)


# STAMPED-FILE-RULE: $(LOCAL_PATH_LANGIDENT).last_synced
# Rule to sync input data from the S3 bucket to the local directory.
#
# The script `s3_to_local_stamps.py` is used to transfer data
# from the specified S3 path to the local directory.
$(LOCAL_PATH_LANGIDENT).last_synced:
	# Syncing the processed data from $(S3_PATH_LANGIDENT)
	#
	# to $(LOCAL_PATH_LANGIDENT)
	mkdir -p $(@D) && \
	python -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_LANGIDENT) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(LOCAL_STAMP_SUFFIX) \
	   --logfile $@.log.gz \
	&& touch $@

# VARIABLE: LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE
# Local synchronization stamp file for processed input data.
#
# This file serves as a marker indicating whether the processed data
# on S3 has been successfully synced to the local storage.
LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE := $(LOCAL_PATH_LANGIDENT_STAGE1).last_synced
  $(call log.debug, LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE)



# STAMPED-FILE-RULE: $(LOCAL_PATH_LANGIDENT).last_synced
# Rule to sync input data from the S3 bucket to the local directory.
#
# The script `s3_to_local_stamps.py` is used to transfer data
# from the specified S3 path to the local directory.
$(LOCAL_PATH_LANGIDENT_STAGE1).last_synced:
	# Syncing the processed data from $(S3_PATH_LANGIDENT_STAGE1)
	#
	# to $(LOCAL_PATH_LANGIDENT_STAGE1)
	mkdir -p $(@D) && \
	python -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_LANGIDENT_STAGE1) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(LOCAL_STAMP_SUFFIX) \
	   --logfile $@.log.gz \
	&& touch $@


# TARGET: sync-input-langident
# Synchronizes processed input data from S3 to local directory.
#
# This target ensures that the latest processed language identification
# data from S3 is made available in the local environment.
sync-input-langident: $(LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE) $(LOCAL_LANGIDENT_SYNC_STAMP_FILE)
.PHONY: sync-input-langident


# TARGET: sync-output-langident
# Synchronizes processed output data from S3 to local directory.
#
# This target ensures that the latest processed language identification
# output data from S3 is made available in the local environment.
sync-output-langident: $(LOCAL_LANGIDENT_SYNC_STAMP_FILE)
.PHONY: sync-output-langident


$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_langident.mk)
