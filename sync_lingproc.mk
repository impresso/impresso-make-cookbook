$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_lingproc.mk)

###############################################################################
# SYNC LINGUISTIC PROCESSING TARGETS
# Targets for synchronizing processed linguistic data between S3 and local storage
###############################################################################

# TARGET: sync-input-processed
# Synchronizes processed input data from S3 to local directory
sync-input:: sync-input-processed
PHONY_TARGETS += sync-input

# The local per-newspaper synchronization file stamp for the processed input data: What is on S3 has been synced?
LOCAL_LANGIDENT_SYNC_STAMP_FILE := $(LOCAL_PATH_LANGIDENT).last_synced
  $(call log.debug, LOCAL_LANGIDENT_SYNC_STAMP_FILE)


sync-input-processed: $(LOCAL_LANGIDENT_SYNC_STAMP_FILE)

PHONY_TARGETS += sync-input-processed

# Rule to sync the input data from the S3 bucket to the local directory
$(LOCAL_PATH_LANGIDENT).last_synced:
	# Syncing the processed data $(S3_PATH_LANGIDENT) 
	#   to $(LOCAL_PATH_LANGIDENT)
	mkdir -p $(@D) && \
	python lib/s3_to_local_stamps.py \
	   $(S3_PATH_LANGIDENT) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension '' \
	   --logfile $@.log.gz \
	&& touch $@


# TARGET: sync-output-lingproc
# Synchronizes linguistic processing output data to S3
sync-output: sync-output-lingproc
PHONY_TARGETS += sync-output

# The local per-newspaper synchronization file stamp for the output text embeddings: What is on S3 has been synced?
LOCAL_LINGPROC_SYNC_STAMP_FILE := $(LOCAL_PATH_LINGPROC).last_synced
  $(call log.debug, LOCAL_LINGPROC_SYNC_STAMP_FILE)

# the suffix of for the local stamp files (added to the input paths on s3)
LOCAL_LINGPROC_STAMP_SUFFIX ?= ''
  $(call log.debug, LOCAL_LINGPROC_STAMP_SUFFIX)


# Rule to sync the output data from the S3 bucket to the local directory
$(LOCAL_PATH_LINGPROC).last_synced:
	mkdir -p $(@D) && \
	python lib/s3_to_local_stamps.py \
	   $(S3_PATH_LINGPROC) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(LOCAL_LINGPROC_STAMP_SUFFIX) \
	   --logfile $@.log.gz && \
	touch $@



sync-output-lingproc: $(LOCAL_LINGPROC_SYNC_STAMP_FILE)

PHONY_TARGETS += sync-output-lingproc
 

clean-sync:: clean-sync-lingproc

PHONY_TARGETS += clean-sync

clean-sync-lingproc:
	rm -vf $(LOCAL_LINGPROC_SYNC_STAMP_FILE)  || true

PHONY_TARGETS += clean-sync-lingproc


$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_lingproc.mk)
