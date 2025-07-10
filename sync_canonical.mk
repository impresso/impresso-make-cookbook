$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_canonical.mk)

###############################################################################
# SYNC CANONICAL PAGES DATA TARGETS
# Targets for synchronizing canonical pages data from S3 to local storage
###############################################################################

# TARGET: sync-input-canonical
# Synchronizes canonical pages input data from S3 to local directory
sync-input:: sync-input-canonical
.PHONY: sync-input

# Local synchronization stamp file for canonical pages input data
LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE := $(LOCAL_PATH_CANONICAL_PAGES).last_synced
  $(call log.debug, LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE)

sync-input-canonical: $(LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE)

.PHONY: sync-input-canonical


# The suffix for the local stamp files (added to the input paths on S3)
LOCAL_CANONICAL_STAMP_SUFFIX ?= .stamp
  $(call log.debug, LOCAL_CANONICAL_STAMP_SUFFIX)

# Rule to sync the input data from the S3 bucket to the local directory
$(LOCAL_PATH_CANONICAL_PAGES).last_synced:
	mkdir -p $(@D) && \
	python -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_CANONICAL_PAGES)/$(NEWSPAPER) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(LOCAL_CANONICAL_STAMP_SUFFIX) \
	   --stamp-api v2 \
	   --logfile $@.log.gz && \
	touch $@



$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_canonical.mk)
