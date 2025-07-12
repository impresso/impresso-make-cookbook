$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_canonical.mk)
###############################################################################
# Sync Canonical Pages Data
# Targets for synchronizing canonical pages data from S3 to local storage
#
# This module provides functionality to sync canonical pages data from S3
# storage to local directories using stamp files to track synchronization
# status. Subsumes all sync-input targets from the necessary inputs.
###############################################################################

# USER-VARIABLE: LOCAL_CANONICAL_STAMP_SUFFIX
# The suffix for the local stamp files (added to the input paths on S3)
#
# This suffix is appended to local stamp files to track synchronization
# status and avoid unnecessary re-downloads of unchanged data.
LOCAL_CANONICAL_STAMP_SUFFIX ?= .stamp
  $(call log.debug, LOCAL_CANONICAL_STAMP_SUFFIX)


# VARIABLE: LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE
# Local synchronization stamp file for canonical pages input data
#
# This file serves as a timestamp marker indicating when the canonical
# pages data was last successfully synchronized from S3 storage.
LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE := $(LOCAL_PATH_CANONICAL_PAGES).last_synced
  $(call log.debug, LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE)


# TARGET: sync-canonical
#: Synchronize canonical pages input data from S3 to local storage
#
# This target ensures that the canonical pages data is available locally
# by triggering the synchronization process if needed. It depends on the
# stamp file to determine if synchronization is required.
sync-canonical: $(LOCAL_CANONICAL_PAGES_SYNC_STAMP_FILE)

.PHONY: sync-canonical

# STAMPED-FILE-RULE: $(LOCAL_PATH_CANONICAL_PAGES).last_synced
#: Sync canonical pages data from S3 and create synchronization stamp
#
# Downloads canonical pages data from the S3 bucket to the local directory
# using the impresso_cookbook.s3_to_local_stamps module. Creates stamp files
# to track individual file synchronization and a master stamp file upon completion.
$(LOCAL_PATH_CANONICAL_PAGES).last_synced:
	mkdir -p $(@D) \
	&& \
	python -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_CANONICAL_PAGES)/$(NEWSPAPER) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-extension $(LOCAL_CANONICAL_STAMP_SUFFIX) \
	   --stamp-api v2 \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& \
	touch $@



$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_canonical.mk)
