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
IN_LOCAL_LANGIDENT_SYNC_STAMP_FILE := $(IN_LOCAL_PATH_LANGIDENT).last_synced
  $(call log.debug, IN_LOCAL_LANGIDENT_SYNC_STAMP_FILE)


sync-input-processed: $(IN_LOCAL_LANGIDENT_SYNC_STAMP_FILE)

PHONY_TARGETS += sync-input-processed

# Rule to sync the input data from the S3 bucket to the local directory
$(IN_LOCAL_PATH_LANGIDENT).last_synced:
	# Syncing the processed data $(IN_S3_PATH_LANGIDENT) 
	#   to $(IN_LOCAL_PATH_LANGIDENT)
	mkdir -p $(@D) && \
	python lib/s3_to_local_stamps.py \
	   $(IN_S3_PATH_LANGIDENT) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension '' \
	   --logfile $@.log.gz \
	&& touch $@


# TARGET: sync-output-lingproc
# Synchronizes linguistic processing output data to S3
sync-output: sync-output-lingproc
PHONY_TARGETS += sync-output

# The local per-newspaper synchronization file stamp for the output text embeddings: What is on S3 has been synced?
OUT_LOCAL_LINGPROC_SYNC_STAMP_FILE := $(OUT_LOCAL_PATH_LINGPROC).last_synced
  $(call log.debug, OUT_LOCAL_LINGPROC_SYNC_STAMP_FILE)

# the suffix of for the local stamp files (added to the input paths on s3)
OUT_LOCAL_LINGPROC_STAMP_SUFFIX ?= ''
  $(call log.debug, OUT_LOCAL_LINGPROC_STAMP_SUFFIX)


# Rule to sync the output data from the S3 bucket to the local directory
$(OUT_LOCAL_PATH_LINGPROC).last_synced:
	mkdir -p $(@D) && \
	python lib/s3_to_local_stamps.py \
	   $(OUT_S3_PATH_LINGPROC) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(OUT_LOCAL_LINGPROC_STAMP_SUFFIX) \
	   --logfile $@.log.gz && \
	touch $@



sync-output-lingproc: $(OUT_LOCAL_LINGPROC_SYNC_STAMP_FILE)

PHONY_TARGETS += sync-output-lingproc
 

clean-sync:: clean-sync-lingproc

PHONY_TARGETS += clean-sync

clean-sync-lingproc:
	rm -vf $(OUT_LOCAL_LINGPROC_SYNC_STAMP_FILE)  || true

PHONY_TARGETS += clean-sync-lingproc


$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_lingproc.mk)
